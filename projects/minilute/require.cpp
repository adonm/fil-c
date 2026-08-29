// minilute - require-by-string machinery. Reuses Luau's own Require runtime
// library (libluaurequire.a) via its luarequire_Configuration C vtable, with a
// VFS layer modeled on lute's require implementation (lute/require/src/:
// modulepath.cpp, filevfs.cpp, lutevfs.cpp, requirevfs.cpp), stripped down to:
//
//   - Disk navigation relative to the requirer, with lute's suffix resolution
//     order (<path>.luau, <path>.lua, <path>/init.luau, <path>/init.lua),
//     ambiguity detection, and module caching by absolute path.
//   - The "lute" alias: require("@lute/fs") / require("@lute/process") load
//     minilute's builtin C modules. Any other alias is rejected.
//   - No .luaurc/.config.luau support (get_config_status reports absent).
//
// Copyright (c) 2026 Filip Pizlo. All Rights Reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY FILIP PIZLO ``AS IS AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL FILIP PIZLO OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include "minilute.h"

#include "modulepath.h"

#include "Luau/Require.h"

#include <cstring>
#include <new>
#include <optional>
#include <string>

using namespace minilute;

namespace
{

// ---------------------------------------------------------------------------
// Builtin @lute modules (mirrors lute's lutevfs.cpp kLuteModules, fs/process
// only).
// ---------------------------------------------------------------------------

struct BuiltinModule
{
    const char* path;
    lua_CFunction openFunction;
};

const BuiltinModule kBuiltinModules[] = {
    {"@lute/fs.luau", miniluteopen_fs},
    {"@lute/process.luau", miniluteopen_process},
};

static const BuiltinModule* findBuiltinModule(const std::string& path)
{
    for (const BuiltinModule& module : kBuiltinModules)
    {
        if (path == module.path)
            return &module;
    }
    return nullptr;
}

static bool isLuteModule(const std::string& path)
{
    return findBuiltinModule(path) != nullptr;
}

static bool isLuteDirectory(const std::string& path)
{
    return path == "@lute";
}

// ---------------------------------------------------------------------------
// RequireCtx: minilute's combined VFS (disk or @lute), mirroring lute's
// RequireVfs/FileVfs/LuteVfs split.
// ---------------------------------------------------------------------------

struct RequireCtx
{
    enum class Kind
    {
        Disk,
        Lute,
    };

    Kind kind = Kind::Disk;
    std::optional<ModulePath> modulePath;

    NavigationStatus resetToLutePath(const std::string& path)
    {
        kind = Kind::Lute;

        if (path == "@lute")
        {
            modulePath = ModulePath::create("@lute", "", isLuteModule, isLuteDirectory);
            return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
        }

        std::string lutePrefix = "@lute/";

        if (path.rfind(lutePrefix, 0) != 0)
            return NavigationStatus::NotFound;

        modulePath = ModulePath::create("@lute", path.substr(lutePrefix.size()), isLuteModule, isLuteDirectory);
        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    NavigationStatus resetToDiskPath(const std::string& path)
    {
        kind = Kind::Disk;

        std::string normalizedPath = miniluteNormalizePath(path);

        // Fallback for requirer files that suffix probing cannot resolve: a
        // shebang-style entry script (e.g. pizfix/bin/sarcasm) has no .luau/.lua
        // suffix, so ModulePath::create fails even though the file exists. In
        // that case navigate from the literal path (createUnprobed allows the
        // ModulePath to start in the NotFound state; only to_parent/to_child are
        // meaningful for it). This mirrors the entry-script fallback in
        // minilute.cpp's getValidPath. Paths that name no existing file keep the
        // create() failure (NavigationStatus::NotFound) behavior.
        auto createOrUnprobed = [&](std::string rootDirectory, std::string filePath, const std::string& literalPath, std::optional<std::string> relativePathToTrack) -> std::optional<ModulePath>
        {
            // Note: create() gets a copy of relativePathToTrack so it is still
            // intact for createUnprobed() below.
            if (std::optional<ModulePath> mp = ModulePath::create(rootDirectory, filePath, miniluteIsFile, miniluteIsDirectory, relativePathToTrack))
                return mp;
            if (!miniluteIsFile(literalPath))
                return std::nullopt;
            return ModulePath::createUnprobed(std::move(rootDirectory), std::move(filePath), miniluteIsFile, miniluteIsDirectory, std::move(relativePathToTrack));
        };

        if (miniluteIsAbsolutePath(normalizedPath))
        {
            size_t firstSlash = normalizedPath.find_first_of('/');
            modulePath = createOrUnprobed(normalizedPath.substr(0, firstSlash), normalizedPath.substr(firstSlash + 1), normalizedPath, std::nullopt);
        }
        else
        {
            std::optional<std::string> cwd = miniluteGetCurrentWorkingDirectory();
            if (!cwd)
                return NavigationStatus::NotFound;

            std::string joinedPath = miniluteNormalizePath(*cwd + "/" + normalizedPath);

            size_t firstSlash = joinedPath.find_first_of('/');
            modulePath = createOrUnprobed(joinedPath.substr(0, firstSlash), joinedPath.substr(firstSlash + 1), joinedPath, normalizedPath);
        }

        return modulePath ? NavigationStatus::Success : NavigationStatus::NotFound;
    }

    // Identifier including the resolved suffix; relative when the requirer was
    // reached via a relative path (lute's chunkname convention), else absolute.
    std::string getFilePath() const
    {
        ResolvedRealPath result = modulePath->getRealPath();
        return result.relativePath ? *result.relativePath : result.realPath;
    }

    std::string getAbsoluteFilePath() const
    {
        ResolvedRealPath result = modulePath->getRealPath();
        return result.realPath;
    }
};

// ---------------------------------------------------------------------------
// luarequire_Configuration vtable implementation
// ---------------------------------------------------------------------------

static luarequire_NavigateResult convert(NavigationStatus status)
{
    switch (status)
    {
    case NavigationStatus::Success:
        return NAVIGATE_SUCCESS;
    case NavigationStatus::Ambiguous:
        return NAVIGATE_AMBIGUOUS;
    case NavigationStatus::NotFound:
        return NAVIGATE_NOT_FOUND;
    }
    return NAVIGATE_NOT_FOUND;
}

static luarequire_WriteResult write(std::optional<std::string> contents, char* buffer, size_t bufferSize, size_t* sizeOut)
{
    if (!contents)
        return WRITE_FAILURE;

    size_t nullTerminatedSize = contents->size() + 1;

    if (bufferSize < nullTerminatedSize)
    {
        *sizeOut = nullTerminatedSize;
        return WRITE_BUFFER_TOO_SMALL;
    }

    *sizeOut = nullTerminatedSize;
    memcpy(buffer, contents->c_str(), nullTerminatedSize);
    return WRITE_SUCCESS;
}

static RequireCtx* getCtx(void* ctx)
{
    return static_cast<RequireCtx*>(ctx);
}

static bool is_require_allowed(lua_State* L, void* ctx, const char* requirer_chunkname)
{
    // Disk chunknames start with '@'; builtin module chunknames are '@@lute/...'.
    return requirer_chunkname && requirer_chunkname[0] == '@';
}

static luarequire_NavigateResult reset(lua_State* L, void* ctx, const char* requirer_chunkname)
{
    RequireCtx* reqCtx = getCtx(ctx);

    if (strncmp(requirer_chunkname, "@@lute/", 7) == 0)
        return convert(reqCtx->resetToLutePath(requirer_chunkname + 1));

    if (requirer_chunkname[0] == '@')
        return convert(reqCtx->resetToDiskPath(requirer_chunkname + 1));

    return NAVIGATE_NOT_FOUND;
}

static luarequire_NavigateResult jump_to_alias(lua_State* L, void* ctx, const char* path)
{
    // Only reachable via configuration-file aliases, which minilute does not support.
    return NAVIGATE_NOT_FOUND;
}

static luarequire_NavigateResult to_alias_override(lua_State* L, void* ctx, const char* alias_unprefixed)
{
    RequireCtx* reqCtx = getCtx(ctx);

    if (strcmp(alias_unprefixed, "lute") == 0)
        return convert(reqCtx->resetToLutePath("@lute"));

    return NAVIGATE_NOT_FOUND;
}

static luarequire_NavigateResult to_alias_fallback(lua_State* L, void* ctx, const char* alias_unprefixed)
{
    return NAVIGATE_NOT_FOUND;
}

static luarequire_NavigateResult to_parent(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = getCtx(ctx);
    return convert(reqCtx->modulePath->toParent());
}

static luarequire_NavigateResult to_child(lua_State* L, void* ctx, const char* name)
{
    RequireCtx* reqCtx = getCtx(ctx);
    return convert(reqCtx->modulePath->toChild(name));
}

static bool is_module_present(lua_State* L, void* ctx)
{
    RequireCtx* reqCtx = getCtx(ctx);

    if (reqCtx->kind == RequireCtx::Kind::Lute)
    {
        ResolvedRealPath result = reqCtx->modulePath->getRealPath();
        return result.status == NavigationStatus::Success && result.type == ResolvedRealPath::PathType::File;
    }

    return miniluteIsFile(reqCtx->getAbsoluteFilePath());
}

static luarequire_WriteResult get_chunkname(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = getCtx(ctx);

    if (reqCtx->kind == RequireCtx::Kind::Lute)
        return write(std::string("@") + reqCtx->getAbsoluteFilePath(), buffer, buffer_size, size_out);

    return write(std::string("@") + reqCtx->getFilePath(), buffer, buffer_size, size_out);
}

static luarequire_WriteResult get_loadname(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = getCtx(ctx);
    return write(reqCtx->getAbsoluteFilePath(), buffer, buffer_size, size_out);
}

static luarequire_WriteResult get_cache_key(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    RequireCtx* reqCtx = getCtx(ctx);
    return write(reqCtx->getAbsoluteFilePath(), buffer, buffer_size, size_out);
}

static luarequire_ConfigStatus get_config_status(lua_State* L, void* ctx)
{
    // minilute does not support .luaurc/.config.luau files.
    return CONFIG_ABSENT;
}

static luarequire_WriteResult get_config(lua_State* L, void* ctx, char* buffer, size_t buffer_size, size_t* size_out)
{
    // Never called: get_config_status always reports CONFIG_ABSENT. The Require
    // library still requires one of get_config/get_alias to be set.
    return WRITE_FAILURE;
}

static int load(lua_State* L, void* ctx, const char* path, const char* chunkname, const char* loadname)
{
    // Builtin modules are C functions and don't need to be compiled or executed.
    if (strncmp(loadname, "@lute/", 6) == 0)
    {
        const BuiltinModule* module = findBuiltinModule(loadname);
        if (!module)
            luaL_error(L, "could not read file '%s'", loadname);

        lua_pushcfunction(L, module->openFunction, nullptr);
        lua_call(L, 0, 1);
        return 1;
    }

    // module needs to run in a new thread, isolated from the rest
    // note: we create ML on main thread so that it doesn't inherit environment of L
    lua_State* GL = lua_mainthread(L);
    lua_State* ML = lua_newthread(GL);
    lua_xmove(GL, L, 1);

    // new thread needs to have the globals sandboxed
    luaL_sandboxthread(ML);

    std::optional<std::string> contents = miniluteReadFile(loadname);
    if (!contents)
        luaL_error(L, "could not read file '%s'", loadname);

    // now we can compile & run module on the new thread
    std::string bytecode = Luau::compile(*contents, miniluteCompileOptions());
    bool errored = true;
    if (luau_load(ML, chunkname, bytecode.data(), bytecode.size(), 0) == 0)
    {
        int status = lua_resume(ML, L, 0);

        if (status == 0)
        {
            if (lua_gettop(ML) == 1)
                errored = false;
            else
                lua_pushfstring(ML, "module %s must return a single value, if it has no return value, you should explicitly return `nil`\n", path);
        }
        else if (status == LUA_YIELD)
        {
            lua_pushstring(ML, "module can not yield\n");
        }
        else if (!lua_isstring(ML, -1))
        {
            lua_pushstring(ML, "unknown error while running module\n");
        }
    }

    // add ML result to L stack
    lua_xmove(ML, L, 1);
    if (errored && lua_isstring(L, -1))
    {
        lua_pushstring(L, lua_debugtrace(ML));
        lua_concat(L, 2);
        lua_error(L);
    }

    // remove ML thread from L stack
    lua_remove(L, -2);

    // added one value to L stack: module result
    return 1;
}

static void requireConfigInit(luarequire_Configuration* config)
{
    if (config == nullptr)
        return;

    config->is_require_allowed = is_require_allowed;
    config->reset = reset;
    config->jump_to_alias = jump_to_alias;
    config->to_alias_override = to_alias_override;
    config->to_alias_fallback = to_alias_fallback;
    config->to_parent = to_parent;
    config->to_child = to_child;
    config->is_module_present = is_module_present;
    config->get_config_status = get_config_status;
    config->get_config = get_config;
    config->get_chunkname = get_chunkname;
    config->get_loadname = get_loadname;
    config->get_cache_key = get_cache_key;
    config->load = load;
}

} // namespace

void minilute_openrequire(lua_State* L)
{
    // Allocate the RequireCtx as a userdata so it lives as long as the
    // lua_State; store it in the registry keyed by its own address (mirrors
    // lute's createRunRequireContext).
    void* storage = lua_newuserdatadtor(
        L,
        sizeof(RequireCtx),
        [](void* ptr)
        {
            std::destroy_at(static_cast<RequireCtx*>(ptr));
        });

    if (!storage)
        luaL_error(L, "unable to allocate RequireCtx");

    RequireCtx* ctx = new (storage) RequireCtx();

    lua_pushlightuserdata(L, ctx);
    lua_insert(L, -2);
    lua_settable(L, LUA_REGISTRYINDEX);

    luaopen_require(L, requireConfigInit, ctx);
}
