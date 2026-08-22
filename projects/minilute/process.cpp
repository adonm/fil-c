// minilute - @lute/process module: synchronous POSIX (fork/execve/poll/waitpid)
// reimplementation of lute's libuv-backed process module
// (lute/process/src/process.cpp). Mirrors lute's function set, result table
// shape, options, and error messages.
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

#include <cerrno>
#include <climits>
#include <cstdlib>
#include <cstring>
#include <map>
#include <new>
#include <string>
#include <utility>
#include <vector>

#include <fcntl.h>
#include <poll.h>
#include <pwd.h>
#include <signal.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

extern char** environ;

namespace minilute_process
{

static void convertCRLFtoLF(std::string& str)
{
    size_t writePos = 0;
    for (size_t readPos = 0; readPos < str.size(); ++readPos)
    {
        if (str[readPos] == '\r' && readPos + 1 < str.size() && str[readPos + 1] == '\n')
            continue; // Skip the '\r' in CRLF
        str[writePos++] = str[readPos];
    }
    str.resize(writePos);
}

struct ProcessOptions
{
    std::string cwd;
    std::string stdioKind;
    std::map<std::string, std::string> env;
    std::string customShell; // only used by system()
};

const std::string kStdioKindDefault = "default";
const std::string kStdioKindInherit = "inherit";
const std::string kStdioKindNone = "none";

static ProcessOptions parseOptions(lua_State* L, int index)
{
    ProcessOptions opts;

    if (lua_isnoneornil(L, index))
        return opts; // use defaults

    if (!lua_istable(L, index))
        luaL_error(L, "process options must be a table");

    lua_getfield(L, index, "system");
    if (!lua_isnil(L, -1))
        opts.customShell = luaL_checkstring(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, index, "cwd");
    if (!lua_isnil(L, -1))
        opts.cwd = luaL_checkstring(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, index, "stdio");
    if (!lua_isnil(L, -1))
        opts.stdioKind = luaL_checkstring(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, index, "env");
    if (!lua_isnil(L, -1))
    {
        if (lua_istable(L, -1))
        {
            lua_pushnil(L);
            while (lua_next(L, -2))
            {
                opts.env[luaL_checkstring(L, -2)] = luaL_checkstring(L, -1);
                lua_pop(L, 1);
            }
        }
        else
        {
            luaL_error(L, "process option 'env' must be a table");
        }
    }
    lua_pop(L, 1);

    return opts;
}

// RAII wrapper for a pipe fd pair.
struct Pipe
{
    int fds[2] = {-1, -1};

    bool create()
    {
        return pipe2(fds, O_CLOEXEC) == 0;
    }

    void closeEnd(int i)
    {
        if (fds[i] >= 0)
        {
            close(fds[i]);
            fds[i] = -1;
        }
    }

    void closeAll()
    {
        closeEnd(0);
        closeEnd(1);
    }

    ~Pipe()
    {
        closeAll();
    }
};

// Resolve `file` against `pathEnv` (PATH value) the way execvp would: if the
// file contains a slash, use it as-is; otherwise probe each PATH entry with
// access(X_OK). Returns the resolved path, or nullopt (errno set to ENOENT or
// the access() error) if no candidate works. Done in the parent, before fork,
// so the child only needs async-signal-safe execve.
static std::optional<std::string> resolveExecutable(const std::string& file, const char* pathEnv, int* errorOut)
{
    if (file.find('/') != std::string::npos)
    {
        if (access(file.c_str(), X_OK) == 0)
            return file;
        *errorOut = errno;
        return std::nullopt;
    }

    std::string path = pathEnv ? pathEnv : "";
    // execvp falls back to a default path when PATH is unset.
    if (path.empty())
        path = "/bin:/usr/bin";

    size_t pos = 0;
    while (true)
    {
        size_t colon = path.find(':', pos);
        std::string dir = path.substr(pos, colon == std::string::npos ? colon : colon - pos);
        if (dir.empty())
            dir = ".";

        std::string candidate = dir + "/" + file;
        if (access(candidate.c_str(), X_OK) == 0)
        {
            struct stat st;
            if (stat(candidate.c_str(), &st) == 0 && !S_ISDIR(st.st_mode))
                return candidate;
            *errorOut = EACCES;
        }
        else if (errno != ENOENT && errno != ENOTDIR)
        {
            *errorOut = errno;
        }

        if (colon == std::string::npos)
            break;
        pos = colon + 1;
    }

    if (!*errorOut)
        *errorOut = ENOENT;
    return std::nullopt;
}

// Look up a variable in a "KEY=VALUE"-style envp array.
static const char* envpLookup(char* const envp[], const char* key)
{
    size_t keyLen = strlen(key);
    for (char* const* it = envp; *it; ++it)
    {
        if (strncmp(*it, key, keyLen) == 0 && (*it)[keyLen] == '=')
            return *it + keyLen + 1;
    }
    return nullptr;
}

// helper function for run() and system()
static int executionHelper(lua_State* L, std::vector<std::string> args, ProcessOptions opts)
{
    if (opts.stdioKind.empty())
        opts.stdioKind = kStdioKindDefault;

    if (opts.stdioKind != kStdioKindDefault && opts.stdioKind != kStdioKindInherit && opts.stdioKind != kStdioKindNone)
        luaL_error(L, "Invalid stdio kind: %s", opts.stdioKind.c_str());

    // Merge the requested environment over a copy of the current one (lute
    // semantics); the result is sorted by key since opts.env is a std::map.
    std::vector<std::string> envStrings;
    std::vector<char*> envPtr;
    if (!opts.env.empty())
    {
        for (char* const* it = environ; *it; ++it)
        {
            const char* eq = strchr(*it, '=');
            if (!eq)
                continue;
            std::string name(*it, eq - *it);
            if (opts.env.find(name) == opts.env.end())
                opts.env[name] = eq + 1;
        }

        envStrings.reserve(opts.env.size());
        envPtr.reserve(opts.env.size() + 1);
        for (const auto& pair : opts.env)
            envStrings.push_back(pair.first + "=" + pair.second);
        for (auto& str : envStrings)
            envPtr.push_back(&str[0]);
        envPtr.push_back(nullptr);
    }

    // All allocations and string fiddling happen here, before fork(). The child
    // only calls async-signal-safe functions (dup2/chdir/execve/write/_exit).
    std::vector<char*> argvPtr;
    argvPtr.reserve(args.size() + 1);
    for (auto& arg : args)
        argvPtr.push_back(arg.data());
    argvPtr.push_back(nullptr);

    char* const* effectiveEnvp = envPtr.empty() ? environ : envPtr.data();

    int resolveError = 0;
    std::optional<std::string> executable = resolveExecutable(args[0], envpLookup(effectiveEnvp, "PATH"), &resolveError);

    Pipe stdinPipe;  // parent writes, child reads (minilute never writes, like lute)
    Pipe stdoutPipe; // child writes, parent reads
    Pipe stderrPipe; // child writes, parent reads
    Pipe execPipe;   // child reports execve failure errno; closes on exec (O_CLOEXEC)

    bool capture = opts.stdioKind == kStdioKindDefault;

    if (capture)
    {
        if (!stdinPipe.create() || !stdoutPipe.create() || !stderrPipe.create() || !execPipe.create())
            luaL_error(L, "Failed to spawn process: %s", miniluteUvStrerror(errno).c_str());
    }
    else
    {
        if (!execPipe.create())
            luaL_error(L, "Failed to spawn process: %s", miniluteUvStrerror(errno).c_str());
    }

    // For stdio "none", hand the child /dev/null on all three fds (UV_IGNORE).
    // Opened in the parent to keep the child async-signal-safe.
    int devNull = -1;
    if (opts.stdioKind == kStdioKindNone)
    {
        devNull = open("/dev/null", O_RDWR);
        if (devNull < 0)
            luaL_error(L, "Failed to spawn process: %s", miniluteUvStrerror(errno).c_str());
    }

    if (!executable)
    {
        // lute raises a Lua error when the process cannot be spawned.
        if (devNull >= 0)
            close(devNull);
        luaL_error(L, "Failed to spawn process: %s", miniluteUvStrerror(resolveError).c_str());
    }

    pid_t pid = fork();
    if (pid < 0)
    {
        if (devNull >= 0)
            close(devNull);
        luaL_error(L, "Failed to spawn process: %s", miniluteUvStrerror(errno).c_str());
    }

    if (pid == 0)
    {
        // ---- child: async-signal-safe calls only ----
        if (opts.stdioKind == kStdioKindNone)
        {
            dup2(devNull, 0);
            dup2(devNull, 1);
            dup2(devNull, 2);
        }
        else if (opts.stdioKind == kStdioKindDefault)
        {
            dup2(stdinPipe.fds[0], 0);
            dup2(stdoutPipe.fds[1], 1);
            dup2(stderrPipe.fds[1], 2);
        }
        // "inherit": leave fds 0/1/2 alone.

        if (!opts.cwd.empty() && chdir(opts.cwd.c_str()) != 0)
        {
            int err = errno;
            (void)!write(execPipe.fds[1], &err, sizeof(err));
            _exit(127);
        }

        execve(executable->c_str(), argvPtr.data(), effectiveEnvp);

        int err = errno;
        (void)!write(execPipe.fds[1], &err, sizeof(err));
        _exit(127);
    }

    // ---- parent ----
    if (devNull >= 0)
        close(devNull);

    struct pollfd pollfds[3];
    int npoll = 0;
    int stdoutIdx = -1, stderrIdx = -1, execIdx = -1;

    if (capture)
    {
        // Keep our end of the child's stdin open (but never written) until the
        // child exits, like lute keeps stdinPipe. Close the child-side ends.
        stdinPipe.closeEnd(0);
        stdoutPipe.closeEnd(1);
        stderrPipe.closeEnd(1);

        stdoutIdx = npoll;
        pollfds[npoll++] = {stdoutPipe.fds[0], POLLIN, 0};
        stderrIdx = npoll;
        pollfds[npoll++] = {stderrPipe.fds[0], POLLIN, 0};
    }
    execIdx = npoll;
    pollfds[npoll++] = {execPipe.fds[0], POLLIN, 0};
    execPipe.closeEnd(1);

    std::string stdoutData;
    std::string stderrData;
    int execError = 0;

    char buffer[4096];
    int openFds = npoll;
    while (openFds > 0)
    {
        int ready = poll(pollfds, npoll, -1);
        if (ready < 0)
        {
            if (errno == EINTR)
                continue;
            break;
        }

        for (int i = 0; i < npoll; ++i)
        {
            if (pollfds[i].fd < 0)
                continue;
            if (pollfds[i].revents == 0)
                continue;

            if (pollfds[i].revents & POLLIN)
            {
                ssize_t bytesRead = read(pollfds[i].fd, buffer, sizeof(buffer));
                if (bytesRead > 0)
                {
                    if (i == execIdx)
                    {
                        // Expect a single int; a short read can't happen for a
                        // 4-byte pipe write, but be defensive.
                        if (bytesRead >= (ssize_t)sizeof(int))
                            memcpy(&execError, buffer, sizeof(int));
                    }
                    else if (i == stdoutIdx)
                        stdoutData.append(buffer, bytesRead);
                    else
                        stderrData.append(buffer, bytesRead);
                    continue;
                }
            }

            // EOF or error: stop polling this fd.
            close(pollfds[i].fd);
            if (i == execIdx)
                execPipe.fds[0] = -1;
            else if (i == stdoutIdx)
                stdoutPipe.fds[0] = -1;
            else if (i == stderrIdx)
                stderrPipe.fds[0] = -1;
            pollfds[i].fd = -1;
            openFds--;
        }
    }

    int status = 0;
    while (waitpid(pid, &status, 0) < 0)
    {
        if (errno != EINTR)
            break;
    }

    // Now that the child is reaped we can drop our end of its stdin.
    if (capture)
        stdinPipe.closeEnd(1);

    if (execError)
        luaL_error(L, "Failed to spawn process: %s", miniluteUvStrerror(execError).c_str());

    int64_t exitCode = 0;
    int termSignal = 0;
    if (WIFEXITED(status))
        exitCode = WEXITSTATUS(status);
    else if (WIFSIGNALED(status))
        termSignal = WTERMSIG(status);

    convertCRLFtoLF(stdoutData);
    convertCRLFtoLF(stderrData);

    lua_createtable(L, 0, 5); // ok, exitCode, stdout, stderr, signal

    bool ok = (exitCode == 0 && termSignal == 0);

    lua_pushboolean(L, ok);
    lua_setfield(L, -2, "ok");

    lua_pushinteger(L, exitCode);
    lua_setfield(L, -2, "exitcode");

    lua_pushlstring(L, stdoutData.c_str(), stdoutData.length());
    lua_setfield(L, -2, "stdout");

    lua_pushlstring(L, stderrData.c_str(), stderrData.length());
    lua_setfield(L, -2, "stderr");

    if (termSignal)
    {
        std::string signalStr = std::to_string(termSignal);
        lua_pushlstring(L, signalStr.c_str(), signalStr.size());
    }
    else
    {
        lua_pushnil(L);
    }
    lua_setfield(L, -2, "signal");

    return 1;
}

static int process_run(lua_State* L)
{
    if (!lua_istable(L, 1))
        luaL_error(L, "process.run expects a table of arguments as the first parameter");

    std::vector<std::string> args;
    int len = lua_objlen(L, 1);
    for (int i = 1; i <= len; i++)
    {
        lua_rawgeti(L, 1, i);
        args.push_back(luaL_checkstring(L, -1));
        lua_pop(L, 1);
    }

    if (args.empty())
        luaL_error(L, "process.run requires a non-empty table of arguments");
    if (args[0].empty())
        luaL_error(L, "process.run requires a non-empty command as the first argument");

    ProcessOptions opts = parseOptions(L, 2);
    return executionHelper(L, args, opts);
}

static int process_system(lua_State* L)
{
    std::string command = luaL_checkstring(L, 1);
    if (command.empty())
        luaL_error(L, "process.system requires a non-empty string as the command");

    ProcessOptions opts = parseOptions(L, 2);

    std::string resolvedShell;
    if (opts.customShell.empty())
    {
        const char* shell = getenv("SHELL");
        resolvedShell = shell ? shell : "/bin/sh";
    }
    else
    {
        resolvedShell = opts.customShell;
    }

    return executionHelper(L, {resolvedShell, "-c", command}, opts);
}

static int process_homedir(lua_State* L)
{
    // Treat an empty HOME the same as an unset HOME: fall back to the passwd
    // database. Returning an empty string would violate the smoke test's
    // contract (and matches how tools like Python's expanduser and lute's own
    // test harness treat "unset or empty" HOME identically).
    const char* home = getenv("HOME");
    if (!home || !*home)
    {
        home = nullptr;
        struct passwd* pw = getpwuid(getuid());
        if (pw)
            home = pw->pw_dir;
    }

    if (!home)
        luaL_error(L, "failed to get home directory: %s", "no home directory found");

    lua_pushstring(L, home);
    return 1;
}

static int process_exit(lua_State* L)
{
    int exitCode = luaL_optinteger(L, 1, 0);

    // Exit with the provided code
    std::exit(exitCode);
}

static int process_cwd(lua_State* L)
{
    std::optional<std::string> cwd = miniluteGetCurrentWorkingDirectory();
    if (!cwd)
        luaL_error(L, "failed to get current working directory: %s", miniluteUvStrerror(errno).c_str());

    lua_pushlstring(L, cwd->c_str(), cwd->size());
    return 1;
}

static int process_execPath(lua_State* L)
{
    std::string buffer(PATH_MAX, '\0');
    ssize_t len = readlink("/proc/self/exe", buffer.data(), buffer.size());
    if (len < 0)
        luaL_error(L, "Failed to get executable path: %s", miniluteUvStrerror(errno).c_str());

    buffer.resize(len);
    lua_pushlstring(L, buffer.c_str(), buffer.size());
    return 1;
}

static int envIndex(lua_State* L)
{
    const char* key = luaL_checkstring(L, 2);
    const char* value = getenv(key);

    if (!value)
    {
        lua_pushnil(L);
        return 1;
    }

    lua_pushstring(L, value);
    return 1;
}

static int envNewindex(lua_State* L)
{
    const char* key = luaL_checkstring(L, 2);

    int err;
    if (lua_isnil(L, 3))
    {
        err = unsetenv(key);
    }
    else
    {
        const char* value = luaL_checkstring(L, 3);
        err = setenv(key, value, 1);
    }

    if (err != 0)
        luaL_error(L, "Failed to set environment variable: %s", miniluteUvStrerror(errno).c_str());

    return 0;
}

struct EnvIter
{
    std::vector<std::pair<std::string, std::string>> items;
    size_t index = 0;
};

static int envIterNext(lua_State* L)
{
    EnvIter* iter = (EnvIter*)lua_touserdata(L, lua_upvalueindex(1));

    if (iter->index >= iter->items.size())
        return 0;

    const auto& item = iter->items[iter->index++];
    lua_pushlstring(L, item.first.c_str(), item.first.size());
    lua_pushlstring(L, item.second.c_str(), item.second.size());
    return 2;
}

static int envIter(lua_State* L)
{
    void* storage = lua_newuserdatadtor(
        L,
        sizeof(EnvIter),
        [](void* ptr)
        {
            std::destroy_at(static_cast<EnvIter*>(ptr));
        });

    EnvIter* iter = new (storage) EnvIter();

    for (char* const* it = environ; *it; ++it)
    {
        const char* eq = strchr(*it, '=');
        if (!eq)
            continue;
        iter->items.emplace_back(std::string(*it, eq - *it), eq + 1);
    }

    lua_pushvalue(L, -1);
    lua_pushcclosure(L, envIterNext, "envIterNext", 1);

    return 1;
}

} // namespace minilute_process

int miniluteopen_process(lua_State* L)
{
    using namespace minilute_process;

    lua_createtable(L, 0, 8);

    lua_pushcfunction(L, process_run, "run");
    lua_setfield(L, -2, "run");
    lua_pushcfunction(L, process_system, "system");
    lua_setfield(L, -2, "system");
    lua_pushcfunction(L, process_homedir, "homedir");
    lua_setfield(L, -2, "homedir");
    lua_pushcfunction(L, process_cwd, "cwd");
    lua_setfield(L, -2, "cwd");
    lua_pushcfunction(L, process_exit, "exit");
    lua_setfield(L, -2, "exit");
    lua_pushcfunction(L, process_execPath, "execPath");
    lua_setfield(L, -2, "execPath");

    // process.env: a table whose metatable hooks reads/writes/iteration.
    lua_newtable(L);
    luaL_newmetatable(L, "process.env");
    lua_pushcfunction(L, envIndex, "env.__index");
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, envNewindex, "env.__newindex");
    lua_setfield(L, -2, "__newindex");
    lua_pushcfunction(L, envIter, "env.__iter");
    lua_setfield(L, -2, "__iter");
    lua_setmetatable(L, -2);
    lua_setfield(L, -2, "env");

    // process.args: readonly 1-based array; args[1] is the script path as typed.
    lua_createtable(L, static_cast<int>(g_args.size()), 0);
    for (int i = 0; i < static_cast<int>(g_args.size()); ++i)
    {
        lua_pushlstring(L, g_args[i].c_str(), g_args[i].size());
        lua_rawseti(L, -2, i + 1);
    }
    lua_setreadonly(L, -1, 1); // args table
    lua_setfield(L, -2, "args");

    lua_setreadonly(L, -1, 1); // process table

    return 1;
}
