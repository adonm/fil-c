// minilute - ModulePath: ported from lute/require/src/modulepath.cpp (and
// modulepath.h) so that require-by-string navigation and CLI script path
// resolution behave exactly like lute's. Header-only.
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

#include "minilute.h"

#include <array>
#include <functional>
#include <optional>
#include <string>
#include <string_view>

namespace minilute
{

enum class NavigationStatus
{
    Success,
    Ambiguous,
    NotFound,
};

struct ResolvedRealPath
{
    struct PathType
    {
        enum Value
        {
            File,
            Directory,
        };
    };

    NavigationStatus status = NavigationStatus::NotFound;
    std::string realPath;
    std::optional<std::string> relativePath;
    PathType::Value type = PathType::File;
};

inline const std::array<std::string_view, 2> kSuffixes = {".luau", ".lua"};
inline const std::array<std::string_view, 2> kInitSuffixes = {"/init.luau", "/init.lua"};

inline bool hasSuffix(std::string_view str, std::string_view suffix)
{
    return str.size() >= suffix.size() && str.substr(str.size() - suffix.size()) == suffix;
}

inline std::string_view removeExtension(std::string_view path)
{
    for (std::string_view suffix : kInitSuffixes)
    {
        if (hasSuffix(path, suffix))
        {
            path.remove_suffix(suffix.size());
            return path;
        }
    }
    for (std::string_view suffix : kSuffixes)
    {
        if (hasSuffix(path, suffix))
        {
            path.remove_suffix(suffix.size());
            return path;
        }
    }
    return path;
}

class ModulePath
{
public:
    static std::optional<ModulePath> create(
        std::string rootDirectory,
        std::string filePath,
        std::function<bool(const std::string&)> isAFile,
        std::function<bool(const std::string&)> isADirectory,
        std::optional<std::string> relativePathToTrack = std::nullopt)
    {
        for (char& c : rootDirectory)
        {
            if (c == '\\')
                c = '/';
        }

        for (char& c : filePath)
        {
            if (c == '\\')
                c = '/';
        }

        std::string_view modulePath = removeExtension(filePath);

        if (relativePathToTrack)
            relativePathToTrack = removeExtension(*relativePathToTrack);

        ModulePath mp = ModulePath(std::move(rootDirectory), std::string{modulePath}, isAFile, isADirectory, std::move(relativePathToTrack));

        // The ModulePath must start in a valid state.
        if (mp.getRealPath().status == NavigationStatus::NotFound)
            return std::nullopt;

        return mp;
    }

    // Like create(), but for a literal file path that suffix probing cannot
    // resolve: an entry-point or requirer file with no .luau/.lua suffix, such
    // as a shebang script (e.g. pizfix/bin/sarcasm). The path is used as-is and
    // the ModulePath is allowed to start in the NotFound state, since for such
    // paths only navigation relative to the file (to_parent/to_child) is
    // meaningful. Callers must check that the literal path is an existing
    // regular file before using this.
    static ModulePath createUnprobed(
        std::string rootDirectory,
        std::string filePath,
        std::function<bool(const std::string&)> isAFile,
        std::function<bool(const std::string&)> isADirectory,
        std::optional<std::string> relativePathToTrack = std::nullopt)
    {
        for (char& c : rootDirectory)
        {
            if (c == '\\')
                c = '/';
        }

        for (char& c : filePath)
        {
            if (c == '\\')
                c = '/';
        }

        return ModulePath(std::move(rootDirectory), std::move(filePath), isAFile, isADirectory, std::move(relativePathToTrack));
    }

    ResolvedRealPath getRealPath() const
    {
        std::optional<ResolvedRealPath::PathType::Value> resolvedType;
        std::string suffix;

        std::string lastComponent;
        if (size_t lastSlash = modulePath.find_last_of('/'); lastSlash != std::string::npos)
            lastComponent = modulePath.substr(lastSlash + 1);

        std::string partialRealPath = realPathPrefix;
        if (!modulePath.empty())
        {
            partialRealPath += '/';
            partialRealPath += modulePath;
        }

        if (lastComponent != "init")
        {
            for (std::string_view potentialSuffix : kSuffixes)
            {
                if (isAFile(partialRealPath + std::string(potentialSuffix)))
                {
                    if (resolvedType)
                        return {NavigationStatus::Ambiguous};

                    resolvedType = ResolvedRealPath::PathType::File;
                    suffix = potentialSuffix;
                }
            }
        }

        if (isADirectory(partialRealPath))
        {
            if (resolvedType)
                return {NavigationStatus::Ambiguous};

            for (std::string_view potentialSuffix : kInitSuffixes)
            {
                if (isAFile(partialRealPath + std::string(potentialSuffix)))
                {
                    if (resolvedType)
                        return {NavigationStatus::Ambiguous};

                    resolvedType = ResolvedRealPath::PathType::File;
                    suffix = potentialSuffix;
                }
            }

            if (!resolvedType)
                resolvedType = ResolvedRealPath::PathType::Directory;
        }

        if (!resolvedType)
            return {NavigationStatus::NotFound};

        std::optional<std::string> relativePathWithSuffix;
        if (relativePathToTrack)
            relativePathWithSuffix = *relativePathToTrack + suffix;

        return {NavigationStatus::Success, partialRealPath + suffix, relativePathWithSuffix, *resolvedType};
    }

    NavigationStatus toParent()
    {
        if (modulePath.empty())
            return NavigationStatus::NotFound;

        if (size_t lastSlash = modulePath.find_last_of('/'); lastSlash == std::string::npos)
            modulePath.clear();
        else
            modulePath = modulePath.substr(0, lastSlash);

        if (relativePathToTrack)
            relativePathToTrack = miniluteNormalizePath(miniluteJoinPaths(*relativePathToTrack, ".."));

        // There is no ambiguity when navigating up in a tree.
        NavigationStatus status = getRealPath().status;
        return status == NavigationStatus::Ambiguous ? NavigationStatus::Success : status;
    }

    NavigationStatus toChild(const std::string& name)
    {
        if (name == ".config")
            return NavigationStatus::NotFound;

        if (modulePath.empty())
            modulePath = name;
        else
            modulePath += "/" + name;

        if (relativePathToTrack)
            relativePathToTrack = miniluteNormalizePath(miniluteJoinPaths(*relativePathToTrack, name));

        return getRealPath().status;
    }

private:
    ModulePath(
        std::string realPathPrefix,
        std::string modulePath,
        std::function<bool(const std::string&)> isAFile,
        std::function<bool(const std::string&)> isADirectory,
        std::optional<std::string> relativePathToTrack)
        : isAFile(std::move(isAFile))
        , isADirectory(std::move(isADirectory))
        , realPathPrefix(std::move(realPathPrefix))
        , modulePath(std::move(modulePath))
        , relativePathToTrack(std::move(relativePathToTrack))
    {
    }

    std::function<bool(const std::string&)> isAFile;
    std::function<bool(const std::string&)> isADirectory;
    std::string realPathPrefix;
    std::string modulePath;
    std::optional<std::string> relativePathToTrack;
};

} // namespace minilute
