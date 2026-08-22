// minilute - a minimal lute-compatible Luau runtime for running sarcasm.
//
// This is the main driver: Luau FFlag setup (like lute's luauflags.cpp), VM
// setup (like lute's runtime.cpp setupState), CLI script path resolution and
// script execution (like lute's climain.cpp handleRunCommand/runFile), and
// error reporting (like lute's Runtime::reportError).
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

#include "Luau/Common.h"
#include "Luau/Compiler.h"
#include "Luau/ExperimentalFlags.h"

#include <cstdio>
#include <cstring>
#include <optional>
#include <string>
#include <utility>
#include <vector>

std::vector<std::string> g_args;

Luau::CompileOptions miniluteCompileOptions()
{
    Luau::CompileOptions result = {};
    result.optimizationLevel = 2;
    result.debugLevel = 2;
    result.typeInfoLevel = 1;
    result.coverageLevel = 0;

    return result;
}

static const char* USAGE_STRING =
    R"(Usage: minilute <script.luau> [args...]

minilute is a minimal lute-compatible Luau runtime: it runs Luau scripts with
require-by-string plus the @lute/fs and @lute/process builtin modules. It exists
to run the sarcasm assembler (projects/sarcasm) without building all of lute.

Options:
    -h, --help      Display this usage message and exit.
    --version       Display the minilute version and exit.
)";

// Like lute's enableAllLuauFlags (lute/cli/src/luauflags.cpp): turn on every
// non-experimental Luau bool FFlag so the language surface matches lute's.
static void enableAllLuauFlags()
{
    for (Luau::FValue<bool>* flag = Luau::FValue<bool>::list; flag; flag = flag->next)
    {
        if (strncmp(flag->name, "Luau", 4) == 0 && !Luau::isAnalysisFlagExperimental(flag->name))
            flag->value = true;
    }
}

static int assertionHandler(const char* expr, const char* file, int line, const char* function)
{
    printf("%s(%d): ASSERTION FAILED: %s\n", file, line, expr);
    return 1;
}

// Like lute's Runtime::reportError: message, then a stack trace, to stderr.
static void reportError(lua_State* L)
{
    std::string error;

    if (const char* str = lua_tostring(L, -1))
        error = str;

    error += "\nstacktrace:\n";
    error += lua_debugtrace(L);

    fprintf(stderr, "%s\n", error.c_str());
}

// Resolves a script path using lute's require-by-string semantics
// (climain.cpp getWithRequireByStringSemantics): extensionless paths get the
// .luau/.lua (and /init.luau//init.lua) treatment. Returns {ok, path-or-error}.
static std::pair<bool, std::string> getValidPath(std::string filePath)
{
    std::string normalized = miniluteNormalizePath(std::move(filePath));

    std::string rootOfPath;
    std::string restOfPath = normalized;
    if (size_t firstSlash = normalized.find_first_of("\\/"); firstSlash != std::string::npos)
    {
        rootOfPath = normalized.substr(0, firstSlash);
        restOfPath = normalized.substr(firstSlash + 1);
    }

    std::optional<minilute::ModulePath> mp = minilute::ModulePath::create(std::move(rootOfPath), std::move(restOfPath), miniluteIsFile, miniluteIsDirectory);
    if (!mp)
        return {false, "Could not initialize ModulePath instance."};

    minilute::ResolvedRealPath resolved = mp->getRealPath();

    std::pair<bool, std::string> result;
    switch (resolved.status)
    {
    case minilute::NavigationStatus::Success:
        if (resolved.type == minilute::ResolvedRealPath::PathType::File)
            result = {true, resolved.realPath};
        else
            result = {false, "Path is a directory, not a file."};
        break;
    case minilute::NavigationStatus::Ambiguous:
        result = {false, "Unable to tell whether path is a file or directory. Is there a same-named file or directory?"};
        break;
    case minilute::NavigationStatus::NotFound:
        result = {false, "File or directory not found."};
        break;
    }

    return result;
}

// Like lute's runFile + Runtime::runBytecode, minus the event loop: compile the
// script, load it on a fresh sandboxed thread, pass the program arguments as
// varargs, and resume it to completion.
static bool runFile(lua_State* GL, const std::string& name)
{
    if (miniluteIsDirectory(name))
    {
        fprintf(stderr, "Error: %s is a directory\n", name.c_str());
        return false;
    }

    std::optional<std::string> source = miniluteReadFile(name);
    if (!source)
    {
        fprintf(stderr, "Error opening %s\n", name.c_str());
        return false;
    }

    std::string chunkname = "@" + miniluteNormalizePath(name);

    std::string bytecode = Luau::compile(*source, miniluteCompileOptions());

    // Keep the thread anchored on the main state stack for the duration of the
    // run so it cannot be garbage collected.
    lua_State* T = lua_newthread(GL);
    luaL_sandboxthread(T);

    if (luau_load(T, chunkname.c_str(), bytecode.data(), bytecode.size(), 0) != 0)
    {
        reportError(T);
        return false;
    }

    int nargs = static_cast<int>(g_args.size());
    if (nargs > 0)
    {
        if (!lua_checkstack(T, nargs))
        {
            fprintf(stderr, "Failed to pass arguments to Luau\n");
            return false;
        }

        for (const std::string& arg : g_args)
            lua_pushlstring(T, arg.c_str(), arg.size());
    }

    int status = lua_resume(T, GL, nargs);
    if (status == LUA_YIELD)
    {
        fprintf(stderr, "Error: script yielded; minilute has no event loop to resume it\n");
        return false;
    }
    if (status != 0)
    {
        reportError(T);
        return false;
    }

    return true;
}

int main(int argc, char** argv)
{
    Luau::assertHandler() = assertionHandler;
    enableAllLuauFlags();

    if (argc < 2)
    {
        printf("%s", USAGE_STRING);
        return 0;
    }

    const char* filePath = argv[1];
    if (strcmp(filePath, "-h") == 0 || strcmp(filePath, "--help") == 0)
    {
        printf("%s", USAGE_STRING);
        return 0;
    }
    if (strcmp(filePath, "--version") == 0)
    {
        printf("minilute 0.1.0 (Luau 0.716, lute-compatible subset)\n");
        return 0;
    }

    // The program arguments visible to the script: args[1] (index 0 here) is
    // the script path as typed, the rest are user arguments.
    for (int i = 1; i < argc; ++i)
        g_args.emplace_back(argv[i]);

    auto [ok, validPath] = getValidPath(filePath);
    if (!ok)
    {
        fprintf(stderr, "Error while resolving filepath '%s': %s\n", filePath, validPath.c_str());
        return 1;
    }

    lua_State* L = luaL_newstate();

    // register the builtin tables
    luaL_openlibs(L);

    lua_pushnil(L);
    lua_setglobal(L, "setfenv");

    lua_pushnil(L);
    lua_setglobal(L, "getfenv");

    // register require-by-string (disk + @lute builtins) before sandboxing
    minilute_openrequire(L);

    luaL_sandbox(L);

    bool success = runFile(L, validPath);

    lua_close(L);
    return success ? 0 : 1;
}
