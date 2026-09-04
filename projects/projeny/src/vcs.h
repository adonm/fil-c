/*
 * Copyright (c) 2026 Filip Pizlo. All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY FILIP PIZLO ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL FILIP PIZLO OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
// Internal git-compatible diff/patch/merge (no git binary invocation).
//
// diff output is unified with `diff --git a/<wid>/... b/<wid>/...` labels,
// `---`/`+++`, `@@` hunks, new/deleted file entries and rename entries, so
// `git apply` and `patch -p1` accept it. The applier accepts git-style diffs
// (a/b prefixes, /dev/null sides, new/deleted/old/new mode lines, rename
// from/to, `\ No newline at end of file`) with fuzz and -p1 semantics.
// Binary content is refused with a clear error.
#pragma once

#include <cstddef>
#include <string>
#include <vector>

// Compute the user diff between two on-disk trees. Labels are
// a/<wid>/... and b/<wid>/... where wid is the workdir basename.
// Includes rename detection. Dies on binary files.
std::string vcs_diff_trees(const std::string& base_tree, const std::string& workdir,
                           const std::string& wid);

// Apply `patch` (wid-label form, wid == `wid`) inside `treedir`.
// Returns true on full success; the tree may be partially patched on failure.
// Blocks already applied are skipped. Dies on binary patches.
bool vcs_apply_whole(const std::string& treedir, const std::string& patch,
                     const std::string& wid);

// Apply each file block of `patch` individually. Returns per-block failures
// with workdir-relative paths (no indices into any other parser's output).
// Blocks already applied are skipped. Each entry carries a display name for
// error messages plus the list of workdir-relative files it touches for
// three-way merging (empty when the block has no parseable path, e.g. an
// unsupported combined-diff block).
struct VcsFailure {
    std::string display;
    std::vector<std::string> paths;
};

std::vector<VcsFailure> vcs_apply_per_file(const std::string& workdir,
                                            const std::string& patch,
                                            const std::string& wid);

// Three-way merge one file: base (may be missing), ours (fresh setup file,
// may be missing), theirs (user file, may be missing) -> write merged result
// with conflict markers into dst_path. Returns true if clean.
// Dies on binary files.
bool vcs_merge_one_file(const std::string& base_file, const std::string& ours_file,
                        const std::string& theirs_file, const std::string& dst_path);
