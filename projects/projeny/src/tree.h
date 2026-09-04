// projeny - original work, MIT-licensed. See tree.cc.
// Tree unpack/diff/apply helpers shared by the ops.
#pragma once

#include <string>
#include <utility>
#include <vector>

// Unpack `archive` (any tar format tar auto-detects) into `destdir` and
// require that it produce exactly one top-level entry named `expect_top`.
// Hard error otherwise. Dies with a clear message if tar is missing.
void unpack_single_top(const std::string& archive, const std::string& destdir,
                       const std::string& expect_top);

// Return names (no . / ..) of the single top-level entry of the archive, or
// die. Used by rebase to discover the new Origname.
std::string archive_single_top_name(const std::string& archive);

// One parsed "diff --git" block.
struct FileDiff {
    std::string text; // raw block text including trailing newline
    std::string a_path; // old-side repo path ("" for pure additions)
    std::string b_path; // new-side repo path ("" for pure deletions)
};

// Split a unified diff into FileDiff blocks. Handles "diff --git" plus the
// "diff --cc"/"diff --combined" variants git merge produces (folded into the
// git form where possible); anything else starts a new opaque block so we
// never silently merge two files' hunks.
std::vector<FileDiff> split_file_diffs(const std::string& patch);

// Rewrite a WID-label diff (labels "a/<wid>/..." / "b/<wid>/...") into
// plain a//b/ label form relative to the workdir root, for `git apply -p1`
// with cwd=workdir (strip "a"/"b" and <wid>; tolerate an absent wid).
// keep_wid=true keeps the wid component (for callers that apply with -p2).
// Returns the rewritten patch.
std::string relabel_wid_patch(const std::string& patch, const std::string& wid,
                              bool keep_wid);

// Labels in freshly generated patches are canonical: "a/<wid>/..." /
// "b/<wid>/..." where wid is the workdir basename, rename lines are bare
// workdir-relative paths, and no absolute paths appear anywhere.
std::string canonicalize_git_diff(const std::string& patch, const std::string& wid,
                                  const std::string& base_abs,
                                  const std::string& work_abs);

// git hunk headers carry stale line counts after we split/rewrite patches;
// recount them so `git apply --recount`-free application never trips.
std::string recount_patch(const std::string& patch);

// Wrap binary-safe invariant: these helpers operate on text patches. A patch
// containing NUL bytes is a hard error (it came from a text file anyway).
void require_text_patch(const std::string& patch, const std::string& what);

// Normalize for patch comparison and storage: git emits a blank context line
// as "" (empty) while some producers write it as " " (one space); map the
// latter to the former. All other lines (including context/added lines with
// significant trailing spaces or tabs) are preserved EXACTLY. Only the final
// line terminator is normalized: the result ends with exactly one '\n' when
// non-empty ("" stays ""). In particular, NO blanket right-trimming is done.
std::string normalize_patch_text(const std::string& patch);

// Compute the user diff: unpack `archive` (expecting top dir `origname`) to a
// temp dir and `git diff --no-index` base-tree vs `workdir`. Labels are
// a/<wid>/... and b/<wid>/... where wid is the workdir basename.
std::string diff_workdir_vs_base(const std::string& archive,
                                 const std::string& origname,
                                 const std::string& workdir,
                                 const std::string& scratch_parent);

// Same but between two on-disk trees (used at commit). Includes rename
// detection so pending Renamed ops render as rename diffs.
std::string diff_trees(const std::string& base_tree, const std::string& workdir,
                       const std::string& wid);

// Apply `patch` (WID-label form, wid == `wid`) inside `treedir`
// (cwd=treedir, -p1). `wid` is the patch's workdir name, which may differ
// from basename(treedir) for unpacked "origname" trees. Returns true on full
// success. On failure the tree may be partially patched; callers prefer the
// per-file path below for merge.
bool apply_patch_whole(const std::string& treedir, const std::string& patch,
                       const std::string& wid, const std::string& scratch_parent);

// Apply each FileDiff block individually (via --include on the rewritten
// path, -p1, cwd=workdir). Returns the list of indices into `blocks` that
// failed to apply. Blocks already applied are retried with -R --check first
// and skipped on success.
std::vector<size_t> apply_patch_per_file(const std::string& workdir,
                                         const std::vector<FileDiff>& blocks,
                                         const std::string& wid);

// Three-way merge one file: base (may be missing), ours (fresh setup file,
// may be missing), theirs (user file, may be missing) -> write merged result
// with conflict markers into dst_path. Returns true if clean.
bool merge_one_file(const std::string& base_file, const std::string& ours_file,
                    const std::string& theirs_file, const std::string& dst_path);
