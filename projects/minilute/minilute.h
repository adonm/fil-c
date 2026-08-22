// minilute - a minimal lute-compatible Luau runtime for running sarcasm.
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

#pragma once

#include "lua.h"
#include "lualib.h"

#include "Luau/Compiler.h"

#include <optional>
#include <string>
#include <vector>

#include <cstring>

// libuv's uv_strerror() returns lower-case messages (e.g. "no such file or
// directory") while strerror() capitalizes the first letter. Lute's error
// messages embed uv_strerror output, so mirror its casing.
inline std::string miniluteUvStrerror(int err)
{
    std::string message = strerror(err);
    if (!message.empty() && message[0] >= 'A' && message[0] <= 'Z')
        message[0] += 'a' - 'A';
    return message;
}

// Program arguments, exactly as passed on the command line: g_args[0] is the
// script path as typed, the rest are user arguments. Set by main() before the
// script runs; consumed by the @lute/process module (process.args) and by the
// script runner (varargs).
extern std::vector<std::string> g_args;

// Lute's compile options (lute/require/src/options.cpp): no codegen.
Luau::CompileOptions miniluteCompileOptions();

// Opens the @lute/fs module: pushes the fs library table. Synchronous POSIX
// reimplementation of lute's libuv-backed fs module.
int miniluteopen_fs(lua_State* L);

// Opens the @lute/process module: pushes the process library table. Synchronous
// POSIX (fork/execve/poll/waitpid) reimplementation of lute's libuv-backed
// process module.
int miniluteopen_process(lua_State* L);

// Registers Luau's require-by-string `require` global, backed by minilute's
// VFS (disk navigation + the @lute alias for builtin modules). Must be called
// before luaL_sandbox.
void minilute_openrequire(lua_State* L);

// ---- path/file utilities (ported from Luau's CLI/src/FileUtils.cpp, POSIX only) ----

bool miniluteIsAbsolutePath(std::string_view path);
std::string miniluteNormalizePath(std::string_view path);
std::string miniluteJoinPaths(std::string_view lhs, std::string_view rhs);
std::vector<std::string_view> miniluteSplitPath(std::string_view path);
std::optional<std::string> miniluteGetCurrentWorkingDirectory();
bool miniluteIsFile(const std::string& path);
bool miniluteIsDirectory(const std::string& path);
// Reads a whole file; strips a shebang line if present (like Luau's readFile).
std::optional<std::string> miniluteReadFile(const std::string& name);
