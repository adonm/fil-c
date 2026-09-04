// projeny - original work, MIT-licensed. See ops.h.
#include "ops.h"

#include "projeny_file.h"
#include "tree.h"
#include "util.h"

#include <algorithm>
#include <iostream>

Ctx resolve_ctx(const std::string& projeny_arg)
{
    Ctx c;
    c.projeny_arg = projeny_arg;
    c.pdir = dirname_of(projeny_arg);
    c.statusfile = projeny_arg + ".status";
    return c;
}

namespace {

// Normalize a user-supplied path (CWD-relative or absolute, or already
// workdir-relative like "lua/src/f.c", or prefixed like "lua/src/f.c" where
// the first component equals the workdir name) to workdir-relative form.
// Dies if the path escapes the workdir.
std::string normalize_workdir_rel(const std::string& workdir, const std::string& wid,
                                  const std::string& user_path)
{
    std::string wabs = absolutize(strip_trailing_slashes(workdir));
    std::string p = user_path;
    // "wid/..." style: strip the leading workdir name.
    if (p == wid || starts_with(p, wid + "/")) {
        p = (p == wid) ? "" : p.substr(wid.size() + 1);
        std::string wrel = p;
        if (wrel.empty())
            die("path '" + user_path + "' refers to the workdir itself");
        if (wrel.find("..") != std::string::npos) {
            // Lexical check below handles it; re-resolve against workdir.
        }
        std::string abs = join_path(wabs, wrel);
        (void)abs;
        // Fall through to lexical validation.
        p = wrel;
        // Validate components.
        std::vector<std::string> parts;
        size_t i = 0;
        while (i <= p.size()) {
            size_t j = p.find('/', i);
            std::string comp = (j == std::string::npos) ? p.substr(i)
                                                       : p.substr(i, j - i);
            if (j == std::string::npos)
                i = p.size() + 1;
            else
                i = j + 1;
            if (comp.empty() || comp == ".")
                continue;
            if (comp == "..")
                die("path '" + user_path + "' escapes the workdir");
            parts.push_back(comp);
        }
        if (parts.empty())
            die("path '" + user_path + "' refers to the workdir itself");
        std::string out = parts[0];
        for (size_t k = 1; k < parts.size(); ++k)
            out += "/" + parts[k];
        return out;
    }
    std::string abs = absolutize(p);
    std::string w = wabs;
    if (abs == w)
        die("path '" + user_path + "' refers to the workdir itself");
    if (!starts_with(abs, w + "/"))
        die("path '" + user_path + "' is outside the workdir '" + workdir + "'");
    return abs.substr(w.size() + 1);
}

std::string scratch_parent_for(const std::string& pdir)
{
    // Scratch temp dirs must NEVER live inside the workdir (or pdir): a crash
    // between temp creation and cleanup would otherwise leave junk behind
    // that pollutes the next diff. Use the system temp dir; TempDir removes
    // the tree on all paths (RAII) and die() removes registered temp dirs
    // too. diff_trees additionally filters any legacy ".projeny-tmp*" entries
    // left behind by older crashed runs. (pdir is unused; kept for call-site
    // readability.)
    (void)pdir;
    return system_scratch_parent();
}

// Unpack `archive` expecting top dir `origname`, then apply `patch_wid`
// (WID-label form, wid == `wid`) inside the unpacked tree. Returns the path
// of the resulting tree (inside our temp dir). Caller owns tmp lifetime.
std::string build_tree_from_patch(TempDir& tmp, const std::string& archive,
                                  const std::string& origname, const std::string& wid,
                                  const std::string& patch_wid,
                                  const std::string& what)
{
    std::string scratch = scratch_parent_for(tmp.path);
    unpack_single_top(archive, tmp.path, origname);
    std::string tree = join_path(tmp.path, origname);
    if (normalize_patch_text(patch_wid).empty())
        return tree;
    if (!apply_patch_whole(tree, patch_wid, wid, scratch)) {
        // Retry per-file to produce a precise error.
        std::vector<FileDiff> blocks = split_file_diffs(patch_wid);
        std::vector<size_t> bad = apply_patch_per_file(tree, blocks, wid);
        std::string detail;
        for (size_t bi : bad) {
            std::string nm = !blocks[bi].b_path.empty() ? blocks[bi].b_path
                                                        : blocks[bi].a_path;
            detail += "  " + nm + "\n";
        }
        die("cannot apply " + what + ": patch does not apply cleanly", detail);
    }
    return tree;
}

// Merge user diff U (WID labels, wid `uwid`) onto fresh tree N (on-disk
// path), using base tree E for 3-way merges. `user_tree` is the on-disk
// user workdir holding the THEIRS content; it may differ from N (in setup,
// N is a fresh temp tree while the user workdir has the local edits).
// Records conflicts into `conflicts` (workdir-relative paths). Applies
// file-by-file; files that apply cleanly via git apply are applied
// directly, the rest go through merge_one_file.
void merge_user_diff_onto(const std::string& base_tree, const std::string& fresh_tree,
                          const std::string& user_tree, const std::string& workdir,
                          const std::string& wid, const std::string& uwid,
                          const std::vector<FileDiff>& ublocks,
                          std::vector<std::string>* conflicts)
{
    std::vector<size_t> bad = apply_patch_per_file(workdir, ublocks, wid);
    if (bad.empty())
        return;
    // For each failed block, do a 3-way merge of base/ours(=fresh)/theirs.
    // A block may touch renames; merge at the granularity of the block's
    // new-side path when it's a simple add/modify/delete, else fall back to
    // whole-block conflict markers on every touched file.
    std::string scratch = scratch_parent_for(workdir);
    for (size_t bi : bad) {
        const FileDiff& b = ublocks[bi];
        // Determine touched new-side files. U-blocks carry the OLD wid
        // (`uwid`), which may differ from the fresh tree's wid — strip
        // either prefix.
        auto strip = [&](const std::string& p) -> std::string {
            if (p == wid || p == uwid)
                return "";
            if (!wid.empty() && starts_with(p, wid + "/"))
                return p.substr(wid.size() + 1);
            if (!uwid.empty() && uwid != wid && starts_with(p, uwid + "/"))
                return p.substr(uwid.size() + 1);
            return p;
        };
        std::vector<std::string> touched;
        if (!b.b_path.empty())
            touched.push_back(strip(b.b_path));
        else if (!b.a_path.empty())
            touched.push_back(strip(b.a_path));
        if (touched.empty() || touched[0].empty()) {
            // Rename blocks: collect both sides.
            if (!b.a_path.empty())
                touched.push_back(strip(b.a_path));
            if (!b.b_path.empty() && b.b_path != b.a_path)
                touched.push_back(strip(b.b_path));
        }
        for (const std::string& rel : touched) {
            if (rel.empty())
                continue;
            // base = E-file, ours = N-file (fresh, possibly partially
            // patched with the clean files), theirs = user workdir file.
            // Failed blocks are skipped atomically per --include, so the
            // user file still holds the theirs content. Snapshot it first:
            // merge_one_file writes its output to the N-tree path, which
            // for in-place merges IS the user path (snapshot protects us).
            TempDir one(scratch, "projeny-mg-");
            std::string bf = join_path(base_tree, rel);
            std::string of = join_path(fresh_tree, rel);
            std::string tf = join_path(user_tree, rel);
            std::string dst = join_path(workdir, rel);
            std::string snapshot;
            bool had_theirs = path_exists(tf);
            if (had_theirs) {
                snapshot = join_path(one.path, "theirs");
                copy_file_bytes(tf, snapshot);
            }
            bool clean = merge_one_file(bf, of, had_theirs ? snapshot : tf, dst);
            if (!clean)
                conflicts->push_back(rel);
        }
    }
}

void sort_unique(std::vector<std::string>* v)
{
    std::sort(v->begin(), v->end());
    v->erase(std::unique(v->begin(), v->end()), v->end());
}

void write_status(const Ctx& ctx, const StatusData& sd)
{
    write_file_bytes(ctx.statusfile, sd.serialize());
}

// Fresh setup: wipe workdir, unpack current archive, apply current patch.
void do_fresh_setup(const Ctx& ctx, const ProjenyFile& cur)
{
    std::string workdir = join_path(ctx.pdir, cur.name);
    if (path_exists(workdir) && !remove_recursive(workdir))
        die("cannot remove existing workdir '" + workdir + "'");
    TempDir tmp(scratch_parent_for(ctx.pdir), "projeny-setup-");
    unpack_single_top(join_path(ctx.pdir, cur.archive), tmp.path, cur.origname);
    if (!apply_patch_whole(join_path(tmp.path, cur.origname), cur.patch,
                           cur.name, scratch_parent_for(ctx.pdir))) {
        std::vector<FileDiff> blocks = split_file_diffs(cur.patch);
        std::vector<size_t> bad =
            apply_patch_per_file(join_path(tmp.path, cur.origname), blocks, cur.name);
        std::string detail;
        for (size_t bi : bad) {
            std::string nm = !blocks[bi].b_path.empty() ? blocks[bi].b_path
                                                        : blocks[bi].a_path;
            detail += "  " + nm + "\n";
        }
        die("patch in '" + ctx.projeny_arg + "' does not apply to archive '" +
                cur.archive + "'",
            detail);
    }
    move_path(join_path(tmp.path, cur.origname), workdir);
}

} // namespace

int cmd_setup(const std::string& projeny_arg)
{
    Ctx ctx = resolve_ctx(projeny_arg);
    ProjenyFile cur = ProjenyFile::parse(ctx.projeny_arg);
    std::string workdir = join_path(ctx.pdir, cur.name);

    if (!path_exists(workdir)) {
        if (is_dir(workdir))
            die("internal error"); // unreachable
        do_fresh_setup(ctx, cur);
        StatusData sd;
        sd.status = "setup";
        sd.embedded = cur.raw;
        write_status(ctx, sd);
        printf("projeny: set up '%s' from '%s'\n", workdir.c_str(),
               cur.archive.c_str());
        return 0;
    }
    if (!is_dir(workdir))
        die("workdir '" + workdir + "' exists but is not a directory");

    // Workdir exists: statusfile is required.
    if (!path_exists(ctx.statusfile))
        die("workdir '" + workdir +
            "' exists but status file '" + ctx.statusfile +
            "' is missing; refusing (remove the workdir or restore the status "
            "file)");

    StatusData old = StatusData::parse(ctx.statusfile);
    ProjenyFile oldpf =
        ProjenyFile::parse_bytes(old.embedded, "embedded copy in '" + ctx.statusfile + "'");
    std::string old_workdir = join_path(ctx.pdir, oldpf.name);

    // Reconstruct the expected tree E from the statusfile's copy.
    TempDir tE(scratch_parent_for(ctx.pdir), "projeny-E-");
    TempDir tN(scratch_parent_for(ctx.pdir), "projeny-N-");
    std::string Etree = build_tree_from_patch(
        tE, join_path(ctx.pdir, oldpf.archive), oldpf.origname, oldpf.name,
        oldpf.patch, "embedded patch in '" + ctx.statusfile + "'");

    // User diff U = workdir vs E. Note diff direction: diff_trees(base,
    // workdir) so applying U to a fresh tree reproduces the workdir.
    // Careful: if old Name != current Name, workdir lives at the OLD name.
    // The spec assumes Name is stable across the merge; if it changed, the
    // current workdir path (new name) doesn't exist. Handle: work at the
    // actual existing dir.
    std::string actual_workdir = workdir;
    std::string actual_wid = cur.name;
    if (!path_exists(actual_workdir) && path_exists(old_workdir) &&
        oldpf.name != cur.name) {
        actual_workdir = old_workdir;
        actual_wid = oldpf.name;
    }
    std::string U = diff_trees(Etree, actual_workdir, oldpf.name);

    if (normalize_patch_text(U) == normalize_patch_text(oldpf.patch)) {
        // No local changes: plain fresh setup from CURRENT .projeny. Keep
        // pending add/rm/mv ops (documented choice); clear conflicts.
        do_fresh_setup(ctx, cur);
        StatusData sd;
        sd.status = "setup";
        sd.added = old.added;
        sd.removed = old.removed;
        sd.renamed = old.renamed;
        sd.embedded = cur.raw;
        write_status(ctx, sd);
        printf("projeny: re-set up '%s' from '%s' (no local changes)\n",
               workdir.c_str(), cur.archive.c_str());
        return 0;
    }

    // MERGE: fresh setup from current .projeny into a temp tree N, then apply
    // U onto N file-by-file, then move N into place. U carries the OLD wid
    // (oldpf.name); N carries the CURRENT wid (cur.name).
    std::string Ntree = build_tree_from_patch(
        tN, join_path(ctx.pdir, cur.archive), cur.origname, cur.name, cur.patch,
        "patch in '" + ctx.projeny_arg + "'");
    std::vector<FileDiff> ublocks = split_file_diffs(U);
    std::vector<std::string> conflicts;
    merge_user_diff_onto(Etree, Ntree, actual_workdir, Ntree, cur.name,
                         oldpf.name, ublocks, &conflicts);
    // Move merged N into place: remove workdir (at old or new name), move N,
    // and if the name changed, the old dir is gone.
    if (path_exists(old_workdir) && old_workdir != workdir) {
        if (!remove_recursive(old_workdir))
            die("cannot remove old workdir '" + old_workdir + "'");
    }
    if (path_exists(workdir) && !remove_recursive(workdir))
        die("cannot remove existing workdir '" + workdir + "'");
    move_path(Ntree, workdir);
    tN.release(); // Ntree moved out; don't delete it

    StatusData sd;
    sd.status = "setup";
    sd.conflicts = conflicts;
    sort_unique(&sd.conflicts);
    // Pending ops refer to workdir-relative files; keep them (documented).
    sd.added = old.added;
    sd.removed = old.removed;
    sd.renamed = old.renamed;
    sd.embedded = cur.raw;
    write_status(ctx, sd);
    if (!sd.conflicts.empty()) {
        printf("projeny: merged with %zu conflict(s):\n", sd.conflicts.size());
        for (auto& c : sd.conflicts)
            printf("  %s\n", c.c_str());
    } else {
        printf("projeny: merged local changes onto '%s'\n", workdir.c_str());
    }
    return 0;
}

int cmd_commit(const std::string& projeny_arg)
{
    Ctx ctx = resolve_ctx(projeny_arg);
    if (!path_exists(ctx.statusfile))
        die("status file '" + ctx.statusfile + "' is missing; run setup first");
    StatusData st = StatusData::parse(ctx.statusfile);
    std::string cur_raw = read_file_bytes(ctx.projeny_arg);
    if (cur_raw != st.embedded)
        die("'" + ctx.projeny_arg +
            "' differs from the copy in '" + ctx.statusfile +
            "'; run setup to merge first");
    if (!st.conflicts.empty()) {
        std::string detail;
        for (auto& c : st.conflicts)
            detail += "  " + c + "\n";
        die("cannot commit with unresolved conflicts", detail);
    }
    ProjenyFile cur = ProjenyFile::parse_bytes(cur_raw, "'" + ctx.projeny_arg + "'");
    std::string workdir = join_path(ctx.pdir, cur.name);
    if (!is_dir(workdir))
        die("workdir '" + workdir + "' is missing; run setup first");

    // Validate pending ops against the workdir, then fold them into the
    // status bookkeeping (the diff itself already reflects on-disk state).
    for (const auto& a : st.added) {
        if (!path_exists(join_path(workdir, a)))
            die("pending add '" + a + "' does not exist in '" + workdir + "'");
    }
    for (const auto& rn : st.renamed) {
        if (!path_exists(join_path(workdir, rn.second)))
            die("pending rename '" + rn.first + " -> " + rn.second +
                "': destination missing in '" + workdir + "'");
        if (path_exists(join_path(workdir, rn.first)))
            die("pending rename '" + rn.first + " -> " + rn.second +
                "': source still exists in '" + workdir + "'");
    }
    // Removed entries: file should be gone from workdir (rm deletes it).
    // Tolerate either state; the diff decides.

    TempDir tmp(scratch_parent_for(ctx.pdir), "projeny-commit-");
    unpack_single_top(join_path(ctx.pdir, cur.archive), tmp.path, cur.origname);
    std::string base = join_path(tmp.path, cur.origname);
    // diff_trees already returns canonical "a/<wid>/..." labels, so no
    // second canonicalization pass is needed (the old code double-wrapped
    // absolute paths and produced garbage labels). normalize_patch_text
    // already ends the patch with exactly one newline.
    std::string new_patch = normalize_patch_text(diff_trees(base, workdir, cur.name));

    cur.rebuild(new_patch);
    write_file_bytes(ctx.projeny_arg, cur.raw);
    StatusData sd;
    sd.status = "setup";
    sd.embedded = cur.raw;
    write_status(ctx, sd);
    printf("projeny: committed new patch to '%s'\n", ctx.projeny_arg.c_str());
    return 0;
}

int cmd_add(const std::string& projeny_arg, const std::string& path)
{
    Ctx ctx = resolve_ctx(projeny_arg);
    if (!path_exists(ctx.statusfile))
        die("status file '" + ctx.statusfile + "' is missing; run setup first");
    ProjenyFile cur = ProjenyFile::parse(ctx.projeny_arg);
    StatusData st = StatusData::parse(ctx.statusfile);
    std::string workdir = join_path(ctx.pdir, cur.name);
    std::string rel = normalize_workdir_rel(workdir, cur.name, path);
    if (!path_exists(join_path(workdir, rel)))
        die("path '" + path + "' does not exist in workdir '" + workdir + "'");
    // Adding a file that's already tracked by the base patch is allowed but
    // pointless; just record it idempotently.
    for (auto& a : st.added) {
        if (a == rel) {
            printf("projeny: '%s' already marked as added\n", rel.c_str());
            return 0;
        }
    }
    // Un-remove if it was pending removal.
    st.removed.erase(std::remove(st.removed.begin(), st.removed.end(), rel),
                     st.removed.end());
    st.added.push_back(rel);
    write_status(ctx, st);
    printf("projeny: marked '%s' as added\n", rel.c_str());
    return 0;
}

int cmd_rm(const std::string& projeny_arg, const std::string& path)
{
    Ctx ctx = resolve_ctx(projeny_arg);
    if (!path_exists(ctx.statusfile))
        die("status file '" + ctx.statusfile + "' is missing; run setup first");
    ProjenyFile cur = ProjenyFile::parse(ctx.projeny_arg);
    StatusData st = StatusData::parse(ctx.statusfile);
    std::string workdir = join_path(ctx.pdir, cur.name);
    std::string rel = normalize_workdir_rel(workdir, cur.name, path);
    std::string full = join_path(workdir, rel);
    // rm deletes the file from the workdir immediately AND records the
    // pending removal, so the deletion shows in the next commit's diff.
    if (path_exists(full) && !remove_recursive(full))
        die("cannot remove '" + full + "'");
    st.added.erase(std::remove(st.added.begin(), st.added.end(), rel), st.added.end());
    // Drop renames touching this path.
    {
        std::vector<std::pair<std::string, std::string>> kept;
        for (auto& rn : st.renamed) {
            if (rn.first != rel && rn.second != rel)
                kept.push_back(rn);
        }
        st.renamed = kept;
    }
    if (std::find(st.removed.begin(), st.removed.end(), rel) == st.removed.end())
        st.removed.push_back(rel);
    write_status(ctx, st);
    printf("projeny: marked '%s' as removed\n", rel.c_str());
    return 0;
}

int cmd_mv(const std::string& projeny_arg, const std::string& src,
           const std::string& dst)
{
    Ctx ctx = resolve_ctx(projeny_arg);
    if (!path_exists(ctx.statusfile))
        die("status file '" + ctx.statusfile + "' is missing; run setup first");
    ProjenyFile cur = ProjenyFile::parse(ctx.projeny_arg);
    StatusData st = StatusData::parse(ctx.statusfile);
    std::string workdir = join_path(ctx.pdir, cur.name);
    std::string srel = normalize_workdir_rel(workdir, cur.name, src);
    std::string drel = normalize_workdir_rel(workdir, cur.name, dst);
    if (srel == drel)
        die("source and destination are the same");
    std::string sfull = join_path(workdir, srel);
    std::string dfull = join_path(workdir, drel);
    if (!path_exists(sfull))
        die("source '" + src + "' does not exist in workdir '" + workdir + "'");
    if (path_exists(dfull))
        die("destination '" + dst + "' already exists in workdir '" + workdir + "'");
    make_dirs(dirname_of(dfull));
    move_path(sfull, dfull);
    // Maintain pending-op bookkeeping: moving a pending-added file keeps it
    // added under the new name; otherwise chain/append the rename.
    bool was_added = std::find(st.added.begin(), st.added.end(), srel) != st.added.end();
    if (was_added) {
        st.added.erase(std::remove(st.added.begin(), st.added.end(), srel),
                       st.added.end());
        if (std::find(st.added.begin(), st.added.end(), drel) == st.added.end())
            st.added.push_back(drel);
    } else {
        // If srel was itself a rename destination, chain to the original.
        std::string orig = srel;
        std::vector<std::pair<std::string, std::string>> kept;
        for (auto& rn : st.renamed) {
            if (rn.second == srel)
                orig = rn.first;
            else
                kept.push_back(rn);
        }
        st.renamed = kept;
        // Drop any rename whose source is now drel (cycles shouldn't happen).
        if (orig != drel)
            st.renamed.push_back({orig, drel});
    }
    // Moving onto a pending-removed path un-removes it.
    st.removed.erase(std::remove(st.removed.begin(), st.removed.end(), drel),
                     st.removed.end());
    write_status(ctx, st);
    printf("projeny: renamed '%s' -> '%s'\n", srel.c_str(), drel.c_str());
    return 0;
}

int cmd_resolve(const std::string& projeny_arg, const std::string& path)
{
    Ctx ctx = resolve_ctx(projeny_arg);
    if (!path_exists(ctx.statusfile))
        die("status file '" + ctx.statusfile + "' is missing; run setup first");
    ProjenyFile cur = ProjenyFile::parse(ctx.projeny_arg);
    StatusData st = StatusData::parse(ctx.statusfile);
    std::string workdir = join_path(ctx.pdir, cur.name);
    // Conflict entries are stored wid-relative (e.g. "src/a.c"), but users
    // naturally type the on-disk form ("<Name>/src/a.c", a CWD-relative
    // path, or an absolute path). Accept any of them: try (a) as-given
    // against the conflict list, (b) with a leading "<Name>/" prefix
    // stripped, (c) normalized against the workdir (CWD-relative/absolute).
    // Accept whichever hits the conflict list; error otherwise.
    std::string rel;
    bool hit = false;
    if (std::find(st.conflicts.begin(), st.conflicts.end(), path) !=
        st.conflicts.end()) {
        rel = path;
        hit = true;
    }
    if (!hit) {
        std::string stripped = path;
        if (stripped == cur.name)
            stripped = "";
        else if (starts_with(stripped, cur.name + "/"))
            stripped = stripped.substr(cur.name.size() + 1);
        if (!stripped.empty() &&
            std::find(st.conflicts.begin(), st.conflicts.end(), stripped) !=
                st.conflicts.end()) {
            rel = stripped;
            hit = true;
        }
    }
    if (!hit) {
        std::string norm = normalize_workdir_rel(workdir, cur.name, path);
        if (std::find(st.conflicts.begin(), st.conflicts.end(), norm) ==
            st.conflicts.end())
            die("'" + norm + "' is not listed as conflicted");
        rel = norm;
        hit = true;
    }
    size_t before = st.conflicts.size();
    st.conflicts.erase(std::remove(st.conflicts.begin(), st.conflicts.end(), rel),
                       st.conflicts.end());
    if (st.conflicts.size() == before)
        die("'" + rel + "' is not listed as conflicted");
    // Warn (don't error) when the file still carries conflict markers:
    // resolving then committing would bake "<<<<<<<" into the patch.
    std::string full = join_path(workdir, rel);
    std::string content;
    if (try_read_file_bytes(full, &content)) {
        bool has_markers = false;
        for (const std::string& line : split_lines(content)) {
            if (starts_with(line, "<<<<<<<") || starts_with(line, "=======") ||
                starts_with(line, ">>>>>>>") || starts_with(line, "|||||||")) {
                has_markers = true;
                break;
            }
        }
        if (has_markers)
            warn("'" + rel + "' still contains conflict markers");
    }
    write_status(ctx, st);
    printf("projeny: resolved '%s'\n", rel.c_str());
    return 0;
}

int cmd_rebase(const std::string& projeny_arg, const std::string& new_tarball)
{
    Ctx ctx = resolve_ctx(projeny_arg);

    // If status/workdir are missing, do a setup first.
    ProjenyFile cur0 = ProjenyFile::parse(ctx.projeny_arg);
    std::string workdir0 = join_path(ctx.pdir, cur0.name);
    if (!path_exists(ctx.statusfile) || !is_dir(workdir0)) {
        printf("projeny: no setup yet; running setup first\n");
        cmd_setup(projeny_arg);
    }

    StatusData st = StatusData::parse(ctx.statusfile);
    std::string cur_raw = read_file_bytes(ctx.projeny_arg);
    if (cur_raw != st.embedded)
        die("'" + ctx.projeny_arg +
            "' differs from the copy in '" + ctx.statusfile +
            "'; run setup to merge first");
    ProjenyFile cur = ProjenyFile::parse_bytes(cur_raw, "'" + ctx.projeny_arg + "'");
    std::string workdir = join_path(ctx.pdir, cur.name);
    if (!is_dir(workdir))
        die("workdir '" + workdir + "' is missing; run setup first");

    // Require a clean tree: workdir diff must equal the current patch. The
    // workdir diff MUST be computed with the same wid as the stored patch
    // (diff_workdir_vs_base uses the workdir basename, which differs when
    // Name != Origname... actually wid IS Name in both; but be explicit:
    // compare canonical forms). Also refuse when conflicts are pending:
    // conflict markers in the tree would otherwise be diffed as content.
    // Pending add/rm/mv ops are honored: the tree is "clean" when it matches
    // base+patch modulo exactly the recorded pending ops (verified below by
    // replaying the ops onto a fresh base+patch tree and diffing).
    if (!st.conflicts.empty()) {
        std::string detail;
        for (auto& c : st.conflicts)
            detail += "  " + c + "\n";
        die("workdir '" + workdir +
            "' has unresolved conflicts; resolve them before rebasing",
            detail);
    }
    {
        TempDir tC(scratch_parent_for(ctx.pdir), "projeny-rebase-clean-");
        unpack_single_top(join_path(ctx.pdir, cur.archive), tC.path,
                          cur.origname);
        std::string expect = join_path(tC.path, cur.origname);
        if (!normalize_patch_text(cur.patch).empty() &&
            !apply_patch_whole(expect, cur.patch, cur.name,
                               scratch_parent_for(ctx.pdir)))
            die("patch in '" + ctx.projeny_arg +
                "' does not apply to its own base archive '" + cur.archive +
                "'; run setup to repair first");
        // Replay recorded pending ops onto the expected tree, then require
        // the workdir to match exactly: any other delta is uncommitted work.
        for (const auto& a : st.added) {
            std::string wf = join_path(workdir, a);
            if (!path_exists(wf))
                die("pending add '" + a + "' does not exist in '" + workdir +
                    "'; resolve pending ops before rebasing");
            make_dirs(dirname_of(join_path(expect, a)));
            copy_file_bytes(wf, join_path(expect, a));
        }
        for (const auto& rn : st.renamed) {
            if (!path_exists(join_path(workdir, rn.second)))
                die("pending rename '" + rn.first + " -> " + rn.second +
                    "': destination missing in '" + workdir + "'");
            remove_recursive(join_path(expect, rn.first));
            make_dirs(dirname_of(join_path(expect, rn.second)));
            copy_file_bytes(join_path(workdir, rn.second),
                            join_path(expect, rn.second));
        }
        for (const auto& r : st.removed)
            remove_recursive(join_path(expect, r));
        std::string U = diff_trees(expect, workdir, cur.name);
        if (!normalize_patch_text(U).empty())
            die("workdir '" + workdir +
                "' has uncommitted changes; commit or revert before rebasing");
    }

    if (!path_exists(new_tarball))
        die("new tarball '" + new_tarball + "' does not exist");
    std::string new_base = basename_of(new_tarball);
    if (new_base.empty() || new_base.find('/') != std::string::npos)
        die("bad tarball path '" + new_tarball + "'");

    // Copy the tarball into pdir if it isn't already there. When the new
    // tarball's basename matches the current Archive but its bytes differ,
    // warn (content changed under a familiar name) and continue with the new
    // file — never silently keep the old bytes.
    std::string dest_archive = join_path(ctx.pdir, new_base);
    std::string new_abs = absolutize(new_tarball);
    std::string dest_abs = absolutize(dest_archive);
    if (new_base == cur.archive && path_exists(dest_archive) &&
        new_abs != dest_abs) {
        if (file_hash_hex(new_tarball) != file_hash_hex(dest_archive) ||
            file_size_bytes(new_tarball) != file_size_bytes(dest_archive))
            warn("tarball '" + new_base +
                 "' differs from the current '" + cur.archive +
                 "'; using the new file");
    }
    if (new_abs != dest_abs)
        copy_file_bytes(new_tarball, dest_archive);

    std::string new_origname = archive_single_top_name(dest_archive);

    // Build the new tree: unpack new tarball, apply current patch, then
    // replay pending add/rm/mv ops so the result includes the pending intent
    // (the ops were validated against base+patch by the clean-check above).
    TempDir tmp(scratch_parent_for(ctx.pdir), "projeny-rebase-");
    unpack_single_top(dest_archive, tmp.path, new_origname);
    std::string tree = join_path(tmp.path, new_origname);
    std::vector<std::string> conflicts;
    if (!normalize_patch_text(cur.patch).empty() &&
        !apply_patch_whole(tree, cur.patch, cur.name,
                           scratch_parent_for(ctx.pdir))) {
        std::vector<FileDiff> blocks = split_file_diffs(cur.patch);
        std::vector<size_t> bad = apply_patch_per_file(tree, blocks, cur.name);
        // 3-way merge each failed file: base = OLD tree file, ours = new
        // tree file (patched except failed parts), theirs = old tree file.
        TempDir tO(scratch_parent_for(ctx.pdir), "projeny-rebase-old-");
        unpack_single_top(join_path(ctx.pdir, cur.archive), tO.path, cur.origname);
        std::string old_tree = join_path(tO.path, cur.origname);
        // Apply the old patch to the old tree to get the "theirs" content?
        // The old tree unpacked is the base; workdir == base+patch (clean
        // check above), so theirs-file == workdir file.
        for (size_t bi : bad) {
            const FileDiff& b = blocks[bi];
            auto strip = [&](const std::string& p) -> std::string {
                if (p == cur.name)
                    return "";
                if (starts_with(p, cur.name + "/"))
                    return p.substr(cur.name.size() + 1);
                return p;
            };
            std::vector<std::string> touched;
            if (!b.a_path.empty())
                touched.push_back(strip(b.a_path));
            if (!b.b_path.empty() && b.b_path != b.a_path)
                touched.push_back(strip(b.b_path));
            sort_unique(&touched);
            for (const std::string& rel : touched) {
                if (rel.empty())
                    continue;
                bool clean = merge_one_file(join_path(old_tree, rel),
                                            join_path(tree, rel),
                                            join_path(workdir, rel),
                                            join_path(tree, rel));
                if (!clean)
                    conflicts.push_back(rel);
            }
        }
    }

    // Replay pending ops onto the rebased tree: adds/renames copy the user's
    // on-disk content forward (the new tree may differ textually from the old
    // base), removals delete, and renames remove the source. The regenerated
    // patch below is diffed against this final tree, so pending intent is
    // folded into the stored patch while the ops ALSO stay listed as pending
    // (commit validates and formally folds them).
    for (const auto& a : st.added) {
        std::string wf = join_path(workdir, a);
        if (!path_exists(wf))
            die("pending add '" + a + "' vanished from '" + workdir + "'");
        make_dirs(dirname_of(join_path(tree, a)));
        copy_file_bytes(wf, join_path(tree, a));
    }
    for (const auto& rn : st.renamed) {
        std::string wf = join_path(workdir, rn.second);
        if (!path_exists(wf))
            die("pending rename '" + rn.first + " -> " + rn.second +
                "' vanished from '" + workdir + "'");
        remove_recursive(join_path(tree, rn.first));
        make_dirs(dirname_of(join_path(tree, rn.second)));
        copy_file_bytes(wf, join_path(tree, rn.second));
    }
    for (const auto& r : st.removed)
        remove_recursive(join_path(tree, r));

    // Update headers: Archive: -> new basename, Origname: -> new top dir.
    // The patch body's wid labels already use Name (unchanged).
    cur.head = replace_header_value(cur.head, "Archive", new_base);
    cur.head = replace_header_value(cur.head, "Origname", new_origname);
    cur.archive = new_base;
    cur.origname = new_origname;
    // Regenerate the patch against the new base so hunk positions/counts are
    // exact (content is base+patch by construction).
    {
        TempDir tB(scratch_parent_for(ctx.pdir), "projeny-rebase-base-");
        unpack_single_top(dest_archive, tB.path, new_origname);
        // diff_trees already returns canonical labels; normalize ends with
        // exactly one newline.
        std::string regen = normalize_patch_text(
            diff_trees(join_path(tB.path, new_origname), tree, cur.name));
        cur.rebuild(regen);
    }
    write_file_bytes(ctx.projeny_arg, cur.raw);

    if (path_exists(workdir) && !remove_recursive(workdir))
        die("cannot remove existing workdir '" + workdir + "'");
    move_path(tree, workdir);
    tmp.release();

    StatusData sd;
    sd.status = "setup";
    sd.conflicts = conflicts;
    sort_unique(&sd.conflicts);
    // Pending add/rm/mv operations survive the rebase (they describe
    // workdir-relative intent, still valid against the new base), matching
    // setup's merge path which also keeps them.
    sd.added = st.added;
    sd.removed = st.removed;
    sd.renamed = st.renamed;
    sd.embedded = cur.raw;
    write_status(ctx, sd);
    if (!sd.conflicts.empty()) {
        printf("projeny: rebased onto '%s' with %zu conflict(s):\n",
               new_base.c_str(), sd.conflicts.size());
        for (auto& c : sd.conflicts)
            printf("  %s\n", c.c_str());
    } else {
        printf("projeny: rebased onto '%s'\n", new_base.c_str());
    }
    if (!sd.added.empty() || !sd.removed.empty() || !sd.renamed.empty())
        printf("projeny: kept %zu added, %zu removed, %zu renamed pending op(s)\n",
               sd.added.size(), sd.removed.size(), sd.renamed.size());
    return 0;
}

int cmd_status(const std::string& projeny_arg)
{
    Ctx ctx = resolve_ctx(projeny_arg);
    if (!path_exists(ctx.statusfile)) {
        printf("projeny: '%s' is not set up (no status file)\n",
               projeny_arg.c_str());
        return 1;
    }
    StatusData st = StatusData::parse(ctx.statusfile);
    printf("Status: %s\n", st.status.c_str());
    for (auto& c : st.conflicts)
        printf("Conflict: %s\n", c.c_str());
    for (auto& a : st.added)
        printf("Added: %s\n", a.c_str());
    for (auto& r : st.removed)
        printf("Removed: %s\n", r.c_str());
    for (auto& rn : st.renamed)
        printf("Renamed: %s -> %s\n", rn.first.c_str(), rn.second.c_str());
    return 0;
}

int cmd_help(const std::string& arg0)
{
    printf("usage: %s <command> [args]\n", arg0.c_str());
    printf("\n"
           "Manage \"project = release tarball + patch\" pairs.\n"
           "\n"
           "  setup <f.projeny>                unpack archive, apply patch\n"
           "  commit <f.projeny>               fold workdir changes into the patch\n"
           "  add <f.projeny> <path>           mark a file as added\n"
           "  rm <f.projeny> <path>            delete a file, mark as removed\n"
           "  mv <f.projeny> <src> <dst>       rename a file, mark as renamed\n"
           "  resolve <f.projeny> <path>       clear a conflict marker entry\n"
           "  rebase <f.projeny> <tarball>     point the project at a new tarball\n"
           "  status <f.projeny>               show setup/conflict/pending state\n"
           "  help                             show this message\n"
           "\n"
           "Paths into the work tree may be CWD-relative, absolute, or\n"
           "workdir-relative (\"<Name>/...\"). They are stored relative to\n"
           "the workdir.\n"
           "\n"
           "resolve also accepts the stored wid-relative form (\"src/a.c\")\n"
           "directly: as-given, \"<Name>\"-stripped, or workdir-relative -\n"
           "whichever matches the conflict entry. Leftover conflict markers\n"
           "print a warning to stderr but still resolve.\n"
           "\n"
           "rebase preserves pending add/rm/mv ops and warns on stderr when\n"
           "the new tarball reuses the current Archive basename with\n"
           "different content.\n");
    return 0;
}
