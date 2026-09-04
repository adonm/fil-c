# projeny — project tarball+patch manager

Original work for the Fil-C project, MIT-licensed. Contains no GPL code and
has zero third-party dependencies (C++ standard library + POSIX only; at
runtime it shells out to `tar`, `git`, and `cp` — see Runtime dependencies).

`projeny` replaces the old workflow where `projects/` held full copies of
external release tarballs plus Fil-C commits on top (huge git checkins).
Instead, git tracks two small files per project:

- the release tarball (e.g. `lua-5.4.7.tar.bz2`), and
- a `.projeny` file naming that tarball plus a git-style patch.

The unpacked work tree (`lua/`) and the `.projeny.status` bookkeeping file
are never tracked by git.

## Usage

All commands take the `.projeny` path (relative or absolute). The tarball is
looked up next to the `.projeny` file, and the work tree is created next to
it as well (named by the `Name:` header).

```
projeny setup <f.projeny>                unpack archive, apply patch
projeny commit <f.projeny>               fold workdir changes into the patch
projeny add <f.projeny> <path>           mark a file as added
projeny rm <f.projeny> <path>            delete a file, mark as removed
projeny mv <f.projeny> <src> <dst>       rename a file, mark as renamed
projeny resolve <f.projeny> <path>       clear a conflict entry
projeny rebase <f.projeny> <tarball>     point the project at a new tarball
projeny status <f.projeny>               show setup/conflict/pending state
projeny help                             show help
```

Paths into the work tree may be CWD-relative, absolute, or workdir-relative
(`<Name>/...`); they are stored relative to the workdir.

- `setup`: unpacks `Archive:` next to the `.projeny` file, requires it to
  produce exactly one top-level directory named by `Origname:` (hard error
  otherwise), renames it to `Name:`, applies the patch, and writes
  `<f>.projeny.status`. If the workdir already exists, the status file is
  required; projeny reconstructs the expected tree from the status copy,
  diffs it against the workdir to find your uncommitted changes, and merges
  them onto a fresh setup of the *current* `.projeny` (which may name a
  different `Archive:` — e.g. upstream moved to a newer tarball). Merge
  failures leave conflict markers in the workdir and record the files in
  the status file.
- `commit`: requires the `.projeny` file to match the status copy exactly
  (else hard error: run `setup` to merge first) and refuses when conflicts
  are pending. Otherwise it diffs the workdir against the base archive and
  stores the new patch in both `.projeny` and `.status` (pending
  add/rm/mv ops are validated and folded in — the diff already reflects
  the on-disk renames/deletions).
- `add`/`rm`/`mv`: record pending added/removed/renamed files in the
  status file (`rm` also deletes the file; `mv` also renames it). Adding a
  file that a later `setup` also adds is a merge conflict.
- `resolve`: drops a file from the status conflict list after you fix it.
  Conflict paths are stored workdir-relative (e.g. `src/a.c`), and `resolve`
  accepts any of: the stored form as-is, the on-disk `<Name>/...`-prefixed
  form, a CWD-relative path, or an absolute path — whichever matches the
  conflict entry. If the file still contains conflict-marker lines
  (`<<<<<<<`, `=======`, `>>>>>>>`, `|||||||`), projeny prints a warning to
  stderr but still resolves (warn, don't error), since committing markers
  would bake them into the patch.
- `rebase <new-tarball>`: requires a clean tree (workdir matches the
  current patch) and no pending conflicts. If never set up, it runs
  `setup` first. It applies the current patch onto the new tarball,
  rewrites `Archive:`/`Origname:`, regenerates the patch, and moves the
  result into place; conflicts leave markers and are recorded in status.
  Pending add/rm/mv operations are preserved across the rebase (they are
  workdir-relative intent, still valid against the new base), matching how
  `setup` merges keep them. If the new tarball's basename equals the
  current `Archive:` but its content differs (size/hash compare), projeny
  warns to stderr and proceeds with the new file — it never silently keeps
  the old bytes.

## `.projeny` format

```
Archive: lua-5.4.7.tar.bz2
Origname: lua-5.4.7
Name: lua

    Free text (anything) between the headers and the patch.

diff --git a/lua/makefile b/lua/makefile
...
```

Headers (`Archive:`, `Origname:`, `Name:` — all required; extra headers are
preserved verbatim) end at the first blank line. Everything up to the first
`diff --git` line is free text. Patch labels use the workdir name
(`a/<Name>/...`, `b/<Name>/...`); rename entries use bare workdir-relative
paths. The patch may be empty (plain tarball, no changes). Paths with spaces,
tabs, quotes, backslashes, `->`, or other special bytes are stored git
C-quoted (`"a/<Name>/my file.c"`); plain paths stay unquoted. Either form is
accepted on input, so hand-written patches need no special handling.

## `.status` format

Text file `<f>.projeny.status` (untracked by git):

```
Status: setup
Conflict: src/a.c        (repeatable, optional)
Added: src/new.c         (repeatable, optional)
Removed: src/old.c       (repeatable, optional)
Renamed: src/a.c -> src/b.c   (repeatable, optional)
--- projeny content ---
<verbatim copy of the .projeny file as of the last setup/commit>
```

`Status: setup` means the workdir was set up; the embedded copy lets
`setup` reconstruct the expected tree later (even across `Archive:`
changes); conflicts and pending add/rm/mv operations are listed above the
delimiter.

## Runtime dependencies

Exactly three external programs (no shell, no `system()`/`popen()` anywhere
— every helper runs via direct `posix_spawnp` with an argv list):

- `tar` to unpack (`-xf ... --no-same-owner --no-same-permissions`, so the
  archive's ownership/permission bits never leak onto the workdir) and to
  list archives (`-tf` for top-dir discovery, `-tvf` for the
  symlink/hardlink-escape audit). Before unpacking, projeny hard-errors on
  absolute member paths, `..` components, and symlink/hardlink members
  whose target is absolute or contains `..`.
- `git` (`diff --no-index --find-renames` for diffing, `apply -p1` for
  patching, `merge-file -p` for three-way merges). Projeny isolates git
  from your config and any enclosing repository, and refuses binary files.
- `cp -a` for whole-tree copies (moving trees across filesystems when
  `rename(2)` returns `EXDEV` — scratch dirs live in the system temp dir,
  never inside the workdir — and snapshotting files for three-way merges).

## Build and test

```
make -j$(nproc)     # builds ./projeny with $(CXX) (default g++)
make test           # builds (if needed) and runs tests/run_tests.sh
make clean          # removes the binary and all .o/.d files
```

The Makefile supports `CXX`/`CC` overrides and generates header
dependencies (`-MMD -MP`) so parallel builds work. The code is warning-free
with `-Wall -Wextra` under both system `g++` and the Fil-C compiler:

```
make clean && make CXX=$(pwd)/../../build/bin/clang++ -j$(nproc) && make test
```

## Testing with the Fil-C compiler

After `./build_all_fast.sh`, `build/bin/clang++` exists at the repo root.
Build and test projeny with it (absolute `CXX` path, from this directory):

```
make clean
make CXX=/path/to/fil-c/build/bin/clang++ -j$(nproc)
make test
make clean
```

The test suite (`tests/run_tests.sh`) builds tiny fake-project tarballs
v1/v2 in a temp dir and exercises fresh setup, edit+commit roundtrips,
setup-again noops, divergent merges (clean and conflicting, including
across `Archive:` versions), resolve+commit, add/rm/mv+commit, clean and
conflicting rebases, the setup-first rebase fallback, rebase with pending
ops preserved, bare wid-relative `resolve`, marker-warning `resolve`,
trailing-whitespace commit→setup roundtrips, pax-metadata tarballs,
newline-less `.projeny` setup→commit, `" -> "` filenames in the status
file, tar-escape rejection, and every hard-error path (missing status,
multi-top-level tarball, commit-after-edit, dirty rebase). It prints
`ok`/`FAIL` lines with a `passed/failed` summary and exits nonzero on
any failure.
