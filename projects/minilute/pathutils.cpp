// minilute - path/file utilities, ported from Luau's CLI/src/FileUtils.cpp
// (POSIX-only subset) so that minilute's path handling matches lute exactly.
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
#include <cstdio>
#include <cstring>

#include <unistd.h>
#include <sys/stat.h>

bool miniluteIsAbsolutePath(std::string_view path)
{
    // Must begin with '/'
    return path.size() >= 1 && path[0] == '/';
}

std::vector<std::string_view> miniluteSplitPath(std::string_view path)
{
    std::vector<std::string_view> components;

    size_t pos = 0;
    size_t nextPos = path.find_first_of("\\/", pos);

    while (nextPos != std::string::npos)
    {
        components.push_back(path.substr(pos, nextPos - pos));
        pos = nextPos + 1;
        nextPos = path.find_first_of("\\/", pos);
    }
    components.push_back(path.substr(pos));

    return components;
}

std::string miniluteNormalizePath(std::string_view path)
{
    const std::vector<std::string_view> components = miniluteSplitPath(path);
    std::vector<std::string_view> normalizedComponents;

    const bool isAbsolute = miniluteIsAbsolutePath(path);

    // 1. Normalize path components
    const size_t startIndex = isAbsolute ? 1 : 0;
    for (size_t i = startIndex; i < components.size(); i++)
    {
        std::string_view component = components[i];
        if (component == "..")
        {
            if (normalizedComponents.empty())
            {
                if (!isAbsolute)
                {
                    normalizedComponents.emplace_back("..");
                }
            }
            else if (normalizedComponents.back() == "..")
            {
                normalizedComponents.emplace_back("..");
            }
            else
            {
                normalizedComponents.pop_back();
            }
        }
        else if (!component.empty() && component != ".")
        {
            normalizedComponents.emplace_back(component);
        }
    }

    std::string normalizedPath;

    // 2. Add correct prefix to formatted path
    if (isAbsolute)
    {
        normalizedPath += components[0];
        normalizedPath += "/";
    }
    else if (normalizedComponents.empty() || normalizedComponents[0] != "..")
    {
        normalizedPath += "./";
    }

    // 3. Join path components to form the normalized path
    for (auto iter = normalizedComponents.begin(); iter != normalizedComponents.end(); ++iter)
    {
        if (iter != normalizedComponents.begin())
            normalizedPath += "/";

        normalizedPath += *iter;
    }
    if (normalizedPath.size() >= 2 && normalizedPath[normalizedPath.size() - 1] == '.' && normalizedPath[normalizedPath.size() - 2] == '.')
        normalizedPath += "/";

    return normalizedPath;
}

std::string miniluteJoinPaths(std::string_view lhs, std::string_view rhs)
{
    std::string result = std::string(lhs);
    if (!result.empty() && result.back() != '/' && result.back() != '\\')
        result += '/';
    result += rhs;
    return result;
}

std::optional<std::string> miniluteGetCurrentWorkingDirectory()
{
    constexpr size_t maxPathLength = 131072;
    constexpr size_t initialPathLength = 260;

    std::string directory(initialPathLength, '\0');
    char* cstr = nullptr;

    while (!cstr && directory.size() <= maxPathLength)
    {
        cstr = getcwd(directory.data(), directory.size());
        if (cstr)
        {
            directory.resize(strlen(cstr));
            return directory;
        }
        else if (errno != ERANGE || directory.size() * 2 > maxPathLength)
        {
            return std::nullopt;
        }
        else
        {
            directory.resize(directory.size() * 2);
        }
    }
    return std::nullopt;
}

bool miniluteIsFile(const std::string& path)
{
    struct stat st = {};
    lstat(path.c_str(), &st);
    return (st.st_mode & S_IFMT) == S_IFREG;
}

bool miniluteIsDirectory(const std::string& path)
{
    struct stat st = {};
    lstat(path.c_str(), &st);
    return (st.st_mode & S_IFMT) == S_IFDIR;
}

std::optional<std::string> miniluteReadFile(const std::string& name)
{
    FILE* file = fopen(name.c_str(), "rb");
    if (!file)
        return std::nullopt;

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    if (length < 0)
    {
        fclose(file);
        return std::nullopt;
    }
    fseek(file, 0, SEEK_SET);

    std::string result(length, 0);

    size_t read = fread(result.data(), 1, length, file);
    fclose(file);

    if (read != size_t(length))
        return std::nullopt;

    // Skip first line if it's a shebang
    if (length > 2 && result[0] == '#' && result[1] == '!')
        result.erase(0, result.find('\n'));

    return result;
}
