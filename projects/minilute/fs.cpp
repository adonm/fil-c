// minilute - @lute/fs module: synchronous POSIX reimplementation of lute's
// libuv-backed fs module (lute/fs/src/fs.cpp + fs_impl.cpp). Mirrors lute's
// function set (minus `watch`, which needs libuv) and error message shapes.
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
#include <cstring>
#include <optional>
#include <string>

#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>

namespace minilute_fs
{

constexpr size_t kChunkIOSize = 4096;

// File type names, matching lute's fs_impl.h UV_TYPENAME_* constants.
static const char* kTypeUnknown = "unknown";
static const char* kTypeFile = "file";
static const char* kTypeDir = "dir";
static const char* kTypeLink = "link";
static const char* kTypeFifo = "fifo";
static const char* kTypeSocket = "socket";
static const char* kTypeChar = "char";
static const char* kTypeBlock = "block";

// A file handle is a lightuserdata pointing at a heap FileHandle. Lute deletes
// the handle struct on close; minilute deliberately keeps the struct alive
// (just clearing the fd) so that use-after-close produces the same clean Lua
// errors as lute ("File handle is closed") rather than dangling-pointer
// dereferences. The structs are tiny and few; they are reclaimed at process
// exit.
struct FileHandle
{
    std::optional<int> fd;
};

static FileHandle* getFileHandle(lua_State* L, int index)
{
    if (!lua_islightuserdata(L, index))
        luaL_errorL(L, "Error: expected file handle");

    auto* handle = static_cast<FileHandle*>(lua_tolightuserdata(L, index));
    if (!handle)
        luaL_errorL(L, "Error: invalid file handle");

    return handle;
}

// Mode-string parsing, ported exactly from lute's fs.cpp setFlags().
static std::optional<int> setFlags(const char* c, int* openFlags)
{
    int modeFlags = 0x0000;

    for (const char* it = c; *it != '\0'; it++)
    {
        char c = *it;
        switch (c)
        {
        case 'r':
            *openFlags |= O_RDONLY;
            break;
        case 'w':
            *openFlags |= O_WRONLY | O_TRUNC | O_CREAT;
            modeFlags = 0666;
            break;
        case 'x':
            *openFlags |= O_CREAT | O_EXCL;
            modeFlags = 0700;
            break;
        case 'a':
            *openFlags |= O_WRONLY | O_APPEND;
            break;
        case '+':
            // If we have not set the truncate bit in 'w' mode,
            *openFlags &= ~O_RDONLY;
            *openFlags &= ~O_WRONLY;
            *openFlags |= O_RDWR;

            if ((*openFlags & O_TRUNC))
            {
                *openFlags |= O_CREAT;
                modeFlags = 0000700 | 0000070 | 0000007;
            }
            break;
        default:
            return std::nullopt;
        }
    }

    return modeFlags;
}

static int fs_open(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs < 1)
        luaL_errorL(L, "Error: no file supplied\n");

    const char* path = luaL_checkstring(L, 1);

    int openFlags = 0x0000;
    const char* mode = "r";
    // Default to read mode if no mode is supplied (i.e., mode is nil in Luau)
    if (nArgs < 2 || lua_isnil(L, 2))
    {
        openFlags = O_RDONLY;
    }
    else
    {
        mode = luaL_checkstring(L, 2);
    }

    std::optional<int> modeFlags = setFlags(mode, &openFlags);
    if (!modeFlags)
        luaL_errorL(L, "Error decoding mode: %s\n", mode);

    int fd = ::open(path, openFlags, *modeFlags);
    if (fd < 0)
        luaL_errorL(L, "Error opening file %s: %s", path, miniluteUvStrerror(errno).c_str());

    auto* handle = new FileHandle();
    handle->fd = fd;
    lua_pushlightuserdata(L, handle);
    return 1;
}

static int fs_read(lua_State* L)
{
    auto* handle = getFileHandle(L, 1);

    if (!handle->fd.has_value())
        luaL_errorL(L, "File handle is closed");

    std::string buffer;
    char chunk[kChunkIOSize];
    for (;;)
    {
        ssize_t bytesRead = ::read(*handle->fd, chunk, sizeof(chunk));
        if (bytesRead < 0)
        {
            if (errno == EINTR)
                continue;
            luaL_errorL(L, "Error reading file: %s", miniluteUvStrerror(errno).c_str());
        }
        if (bytesRead == 0)
            break;
        buffer.append(chunk, bytesRead);
    }

    lua_pushlstring(L, buffer.data(), buffer.size());
    return 1;
}

static int fs_write(lua_State* L)
{
    auto* handle = getFileHandle(L, 1);

    size_t len;
    const char* data = luaL_checklstring(L, 2, &len);

    if (!handle->fd.has_value())
        luaL_errorL(L, "File handle is closed");

    size_t offset = 0;
    while (offset < len)
    {
        ssize_t bytesWritten = ::write(*handle->fd, data + offset, len - offset);
        if (bytesWritten < 0)
        {
            if (errno == EINTR)
                continue;
            luaL_errorL(L, "Error writing file: %s", miniluteUvStrerror(errno).c_str());
        }
        offset += bytesWritten;
    }

    return 0;
}

static int fs_close(lua_State* L)
{
    auto* handle = getFileHandle(L, 1);

    if (!handle->fd.has_value())
        luaL_errorL(L, "File handle is already closed");

    if (::close(*handle->fd) < 0)
        luaL_errorL(L, "Error closing file: %s", miniluteUvStrerror(errno).c_str());

    handle->fd.reset();
    return 0;
}

static int fs_remove(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs < 1)
        luaL_errorL(L, "Error: no file supplied\n");

    if (nArgs > 1)
        luaL_errorL(L, "Error: too many arguments supplied\n");

    const char* path = luaL_checkstring(L, 1);

    if (::unlink(path) < 0)
        luaL_errorL(L, "Error removing file %s: %s", path, miniluteUvStrerror(errno).c_str());

    return 0;
}

static const char* fileModeToType(mode_t mode)
{
    if (S_ISDIR(mode))
        return kTypeDir;
    if (S_ISREG(mode))
        return kTypeFile;
    if (S_ISCHR(mode))
        return kTypeChar;
    if (S_ISLNK(mode))
        return kTypeLink;
#ifdef S_ISBLK
    if (S_ISBLK(mode))
        return kTypeBlock;
#endif
#ifdef S_ISFIFO
    if (S_ISFIFO(mode))
        return kTypeFifo;
#endif
#ifdef S_ISSOCK
    if (S_ISSOCK(mode))
        return kTypeSocket;
#endif
    return kTypeUnknown;
}

static void pushTimespecTable(lua_State* L, int64_t sec, int64_t nsec)
{
    // Lute represents timestamps as a @lute/time duration userdata. minilute has
    // no time module, so timestamps are plain tables { seconds =, nanoseconds = }.
    lua_createtable(L, 0, 2);
    lua_pushnumber(L, static_cast<double>(sec));
    lua_setfield(L, -2, "seconds");
    lua_pushnumber(L, static_cast<double>(nsec));
    lua_setfield(L, -2, "nanoseconds");
}

static int fs_stat(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    struct stat st;
    if (::lstat(path, &st) < 0)
        luaL_errorL(L, "Error getting metadata of file %s: %s", path, miniluteUvStrerror(errno).c_str());

    lua_createtable(L, 0, 6);

    lua_pushstring(L, fileModeToType(st.st_mode));
    lua_setfield(L, -2, "type");

    // this is fine unless the file is 9 petabytes
    lua_pushnumber(L, static_cast<double>(st.st_size));
    lua_setfield(L, -2, "size");

#ifdef __APPLE__
    pushTimespecTable(L, st.st_birthtimespec.tv_sec, st.st_birthtimespec.tv_nsec);
#else
    pushTimespecTable(L, 0, 0); // no portable birth time via lstat; ctime is not creation time
#endif
    lua_setfield(L, -2, "created");

    pushTimespecTable(L, st.st_atim.tv_sec, st.st_atim.tv_nsec);
    lua_setfield(L, -2, "accessed");

    pushTimespecTable(L, st.st_mtim.tv_sec, st.st_mtim.tv_nsec);
    lua_setfield(L, -2, "modified");

    // permissions
    lua_createtable(L, 0, 2);

    bool canAnyWrite = st.st_mode & 0222;
    lua_pushboolean(L, !canAnyWrite);
    lua_setfield(L, -2, "readonly");

    lua_setfield(L, -2, "permissions");

    return 1;
}

static int fs_exists(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs > 1)
        luaL_errorL(L, "exists: too many arguments supplied\n");

    const char* path = luaL_checkstring(L, 1);

    if (::access(path, F_OK) == 0)
    {
        lua_pushboolean(L, true);
        return 1;
    }

    if (errno != ENOENT)
        luaL_errorL(L, "exists: Error checking existence of %s: %s", path, miniluteUvStrerror(errno).c_str());

    lua_pushboolean(L, false);
    return 1;
}

static int fs_type(lua_State* L)
{
    const char* path = luaL_checkstring(L, 1);

    struct stat st;
    if (::lstat(path, &st) < 0)
        luaL_errorL(L, "Error getting type of file %s: %s", path, miniluteUvStrerror(errno).c_str());

    lua_pushstring(L, fileModeToType(st.st_mode));
    return 1;
}

static int fs_link(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs > 2)
        luaL_errorL(L, "link: too many arguments supplied\n");

    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    if (::link(path, dest) < 0)
        luaL_errorL(L, "link: Error creating link from %s to %s: %s", path, dest, miniluteUvStrerror(errno).c_str());

    return 0;
}

static int fs_symlink(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs > 2)
        luaL_errorL(L, "symlink: too many arguments supplied\n");

    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    if (::symlink(path, dest) < 0)
        luaL_errorL(L, "symlink: Error creating symlink from %s to %s: %s", path, dest, miniluteUvStrerror(errno).c_str());

    return 0;
}

static int fs_copy(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs > 2)
        luaL_errorL(L, "copy: too many arguments supplied\n");

    const char* path = luaL_checkstring(L, 1);
    const char* dest = luaL_checkstring(L, 2);

    struct stat st;
    if (::stat(path, &st) < 0)
        luaL_errorL(L, "copy: Error copying file from %s to %s: %s", path, dest, miniluteUvStrerror(errno).c_str());

    int srcFd = ::open(path, O_RDONLY);
    if (srcFd < 0)
        luaL_errorL(L, "copy: Error copying file from %s to %s: %s", path, dest, miniluteUvStrerror(errno).c_str());

    int dstFd = ::open(dest, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode & 0777);
    if (dstFd < 0)
    {
        int err = errno;
        ::close(srcFd);
        luaL_errorL(L, "copy: Error copying file from %s to %s: %s", path, dest, miniluteUvStrerror(err).c_str());
    }

    char chunk[kChunkIOSize];
    for (;;)
    {
        ssize_t bytesRead = ::read(srcFd, chunk, sizeof(chunk));
        if (bytesRead < 0)
        {
            if (errno == EINTR)
                continue;
            int err = errno;
            ::close(srcFd);
            ::close(dstFd);
            luaL_errorL(L, "copy: Error copying file from %s to %s: %s", path, dest, miniluteUvStrerror(err).c_str());
        }
        if (bytesRead == 0)
            break;

        ssize_t written = 0;
        while (written < bytesRead)
        {
            ssize_t w = ::write(dstFd, chunk + written, bytesRead - written);
            if (w < 0)
            {
                if (errno == EINTR)
                    continue;
                int err = errno;
                ::close(srcFd);
                ::close(dstFd);
                luaL_errorL(L, "copy: Error copying file from %s to %s: %s", path, dest, miniluteUvStrerror(err).c_str());
            }
            written += w;
        }
    }

    ::close(srcFd);
    ::close(dstFd);
    return 0;
}

static int fs_mkdir(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs != 1)
        luaL_errorL(L, "Error: expected 1 argument\n");

    const char* path = luaL_checkstring(L, 1);

    if (::mkdir(path, 0777) < 0)
        luaL_errorL(L, "Error creating directory %s: %s", path, miniluteUvStrerror(errno).c_str());

    return 0;
}

static int fs_rmdir(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs < 1)
        luaL_errorL(L, "rmdir: no path supplied\n");

    if (nArgs > 1)
        luaL_errorL(L, "rmdir: too many arguments supplied\n");

    const char* path = luaL_checkstring(L, 1);

    if (::rmdir(path) < 0)
        luaL_errorL(L, "Error removing directory %s: %s", path, miniluteUvStrerror(errno).c_str());

    return 0;
}

static const char* direntTypeToName(unsigned char dType)
{
    switch (dType)
    {
    case DT_REG:
        return kTypeFile;
    case DT_DIR:
        return kTypeDir;
    case DT_LNK:
        return kTypeLink;
    case DT_FIFO:
        return kTypeFifo;
    case DT_SOCK:
        return kTypeSocket;
    case DT_CHR:
        return kTypeChar;
    case DT_BLK:
        return kTypeBlock;
    default:
        return kTypeUnknown;
    }
}

static int fs_listdir(lua_State* L)
{
    int nArgs = lua_gettop(L);
    if (nArgs > 1)
        luaL_errorL(L, "listdir: too many arguments supplied\n");

    const char* path = luaL_checkstring(L, 1);

    DIR* dir = ::opendir(path);
    if (!dir)
        luaL_errorL(L, "listdir: Error listing directory %s (%s)", path, miniluteUvStrerror(errno).c_str());

    lua_createtable(L, 0, 0);
    int index = 1;

    errno = 0;
    while (struct dirent* entry = ::readdir(dir))
    {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        lua_createtable(L, 0, 2);

        lua_pushstring(L, entry->d_name);
        lua_setfield(L, -2, "name");

        lua_pushstring(L, direntTypeToName(entry->d_type));
        lua_setfield(L, -2, "type");

        lua_rawseti(L, -2, index++);
    }

    if (errno != 0)
    {
        int err = errno;
        ::closedir(dir);
        luaL_errorL(L, "listdir: Error reading directory entry (%s)", miniluteUvStrerror(err).c_str());
    }

    ::closedir(dir);
    return 1;
}

} // namespace minilute_fs

int miniluteopen_fs(lua_State* L)
{
    using namespace minilute_fs;

    lua_createtable(L, 0, 14);

    lua_pushcfunction(L, fs_open, "open");
    lua_setfield(L, -2, "open");
    lua_pushcfunction(L, fs_read, "read");
    lua_setfield(L, -2, "read");
    lua_pushcfunction(L, fs_write, "write");
    lua_setfield(L, -2, "write");
    lua_pushcfunction(L, fs_close, "close");
    lua_setfield(L, -2, "close");
    lua_pushcfunction(L, fs_remove, "remove");
    lua_setfield(L, -2, "remove");
    lua_pushcfunction(L, fs_stat, "stat");
    lua_setfield(L, -2, "stat");
    lua_pushcfunction(L, fs_exists, "exists");
    lua_setfield(L, -2, "exists");
    lua_pushcfunction(L, fs_type, "type");
    lua_setfield(L, -2, "type");
    lua_pushcfunction(L, fs_link, "link");
    lua_setfield(L, -2, "link");
    lua_pushcfunction(L, fs_symlink, "symlink");
    lua_setfield(L, -2, "symlink");
    lua_pushcfunction(L, fs_copy, "copy");
    lua_setfield(L, -2, "copy");
    lua_pushcfunction(L, fs_mkdir, "mkdir");
    lua_setfield(L, -2, "mkdir");
    lua_pushcfunction(L, fs_listdir, "listdir");
    lua_setfield(L, -2, "listdir");
    lua_pushcfunction(L, fs_rmdir, "rmdir");
    lua_setfield(L, -2, "rmdir");

    lua_setreadonly(L, -1, 1);

    return 1;
}
