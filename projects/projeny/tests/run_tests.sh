#!/bin/sh
# projeny test suite: fixture-based shell tests over tiny fake-project
# tarballs v1/v2. Covers fresh setup, edit+commit roundtrips, setup-again
# noops, divergent merges (clean + conflicting), add/rm/mv + commit,
# rebase (clean + conflict), and the hard-error paths.
#
# Usage: ./tests/run_tests.sh ./projeny
# Exits nonzero on failure; prints ok/FAIL lines plus summary counts.
#
# Original work for the Fil-C project, MIT-licensed.
set -u

PROJENY="${1:-./projeny}"
case "$PROJENY" in
/*) ;;
*) PROJENY="$(pwd)/$PROJENY" ;;
esac

PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    echo "ok $PASS - $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "FAIL - $1"
    if [ $# -ge 2 ]; then
        echo "  detail: $2"
    fi
}

# expect_ok <name> <command...>: command must exit 0.
expect_ok() {
    name="$1"
    shift
    out="$("$@" 2>&1)"
    rc=$?
    if [ $rc -eq 0 ]; then
        ok "$name"
    else
        fail "$name" "exit=$rc out: $out"
    fi
}

# expect_fail <name> <command...>: command must exit nonzero.
expect_fail() {
    name="$1"
    shift
    out="$("$@" 2>&1)"
    rc=$?
    if [ $rc -ne 0 ]; then
        ok "$name"
    else
        fail "$name" "expected failure but exited 0 (out: $out)"
    fi
}

# expect_file_contains <name> <file> <fixed-string>
expect_file_contains() {
    if grep -qF -- "$3" "$2"; then
        ok "$1"
    else
        fail "$1" "'$2' lacks '$3'"
    fi
}

# expect_file_not_contains <name> <file> <fixed-string>
expect_file_not_contains() {
    if grep -qF -- "$3" "$2"; then
        fail "$1" "'$2' unexpectedly contains '$3'"
    else
        ok "$1"
    fi
}

# expect_file_eq <name> <file> <expected-content> (exact bytes via stdin heredoc file)
expect_file_eq() {
    if [ ! -f "$2" ]; then
        fail "$1" "'$2' does not exist"
        return
    fi
    if cmp -s "$2" "$3"; then
        ok "$1"
    else
        fail "$1" "'$2' differs from expected; got: $(cat "$2")"
    fi
}


# Run a command in a directory without forking the assertion counters:
# (cd X && expect_...) would run expect_* in a subshell, losing PASS/FAIL.
# Instead cd there, run, and cd back — all in the current shell.
run_in() {
    _dir="$1"
    shift
    _prev="$(pwd)"
    cd "$_dir" || { fail "cannot cd to $_dir"; return 1; }
    "$@"
    _rc=$?
    cd "$_prev" || exit 1
    return $_rc
}

ROOT="$(pwd)/.projeny-test-tmp"
rm -rf "$ROOT"
mkdir -p "$ROOT"

# ---------------------------------------------------------------- fixtures
# fake v1/v2: multi-line files with GAPS between change regions so that
# simultaneous edits to different regions merge cleanly with git merge-file.
make_tarballs() {
    dir="$1"       # scratch dir (created fresh)
    stem="$2"      # e.g. fake
    mkdir -p "$dir"
    rm -rf "$dir/$stem-1.0" "$dir/$stem-2.0"
    mkdir -p "$dir/$stem-1.0/src"
    cat > "$dir/$stem-1.0/src/a.c" <<'EOF'
int alpha = 1;

int beta = 1;

int gamma = 1;

int delta = 1;
EOF
    printf 'line one v1\n' > "$dir/$stem-1.0/src/b.c"
    printf 'hello v1\n' > "$dir/$stem-1.0/README"
    (cd "$dir" && tar -czf "$stem-1.0.tar.gz" "$stem-1.0")
    mkdir -p "$dir/$stem-2.0/src"
    cat > "$dir/$stem-2.0/src/a.c" <<'EOF'
int alpha = 2;

int beta = 1;

int gamma = 1;

int delta = 1;
EOF
    printf 'line one v2\n' > "$dir/$stem-2.0/src/b.c"
    printf 'hello v2\n' > "$dir/$stem-2.0/README"
    (cd "$dir" && tar -czf "$stem-2.0.tar.gz" "$stem-2.0")
    rm -rf "$dir/$stem-1.0" "$dir/$stem-2.0"
}

write_projeny() {
    # $1 = dir, $2 = stem, $3 = version (1.0/2.0), $4 = workdir name
    cat > "$1/$2.projeny" <<EOF
Archive: $2-$3.tar.gz
Origname: $2-$3
Name: $4

    Fake project $2 for projeny tests.

EOF
}

check_deps() {
    if [ ! -x "$PROJENY" ]; then
        echo "FAIL - projeny binary '$PROJENY' missing/not executable" >&2
        exit 1
    fi
    for t in tar git; do
        if ! command -v $t >/dev/null 2>&1; then
            echo "FAIL - required helper '$t' missing" >&2
            exit 1
        fi
    done
}

check_deps

# ---------------------------------------------------------- 1. fresh setup
T1="$ROOT/t1"
make_tarballs "$T1" fake
write_projeny "$T1" fake 1.0 fake
run_in "$T1" expect_ok "fresh setup exits 0" "$PROJENY" setup fake.projeny
if [ -d "$T1/fake/src" ] && [ -f "$T1/fake/src/a.c" ]; then
    ok "fresh setup creates workdir with files"
else
    fail "fresh setup creates workdir with files" "ls: $(ls -R "$T1" 2>&1)"
fi
expect_file_contains "fresh setup workdir has v1 content" "$T1/fake/README" "hello v1"
if [ -f "$T1/fake.projeny.status" ]; then
    ok "fresh setup writes status file"
else
    fail "fresh setup writes status file"
fi
expect_file_contains "status reports setup state" "$T1/fake.projeny.status" "Status: setup"
expect_file_contains "status embeds projeny verbatim" "$T1/fake.projeny.status" "Archive: fake-1.0.tar.gz"

# ----------------------------------------------- 2. edit + commit roundtrip
T2="$ROOT/t2"
make_tarballs "$T2" fake
write_projeny "$T2" fake 1.0 fake
(cd "$T2" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T2/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int alpha = 1;", "int alpha = 10;")
open(p, "w").write(s)
EOF
run_in "$T2" expect_ok "commit edited file exits 0" "$PROJENY" commit fake.projeny
expect_file_contains "commit stores diff in projeny" "$T2/fake.projeny" "alpha = 10"
expect_file_contains "commit refreshes status copy" "$T2/fake.projeny.status" "alpha = 10"
run_in "$T2" expect_ok "setup-again noop exits 0" "$PROJENY" setup fake.projeny
expect_file_contains "setup-again keeps committed edit" "$T2/fake/src/a.c" "alpha = 10"

# --------------------------------------- 3. divergent setup merge, no conflict
T3="$ROOT/t3"
make_tarballs "$T3" fake
write_projeny "$T3" fake 1.0 fake
(cd "$T3" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
# local committed change: delta region.
python3 - "$T3/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int delta = 1;", "int delta = 100;")
open(p, "w").write(s)
EOF
(cd "$T3" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$T3/fake.projeny" "$ROOT/t3-local.projeny"
# upstream: same committed base, rebased onto v2 + gamma-region change.
(cd "$T3" && "$PROJENY" rebase fake.projeny fake-2.0.tar.gz >/dev/null 2>&1)
python3 - "$T3/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int gamma = 1;", "int gamma = 200;")
open(p, "w").write(s)
EOF
(cd "$T3" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$T3/fake.projeny" "$ROOT/t3-upstream.projeny"
# local clone: local base + uncommitted beta-region edit, then upstream merge.
rm -rf "$T3/fake" "$T3/fake.projeny.status"
cp "$ROOT/t3-local.projeny" "$T3/fake.projeny"
(cd "$T3" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T3/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 1;", "int beta = 300;")
open(p, "w").write(s)
EOF
cp "$ROOT/t3-upstream.projeny" "$T3/fake.projeny"
run_in "$T3" expect_ok "divergent setup merge exits 0" "$PROJENY" setup fake.projeny
expect_file_contains "divergent merge keeps local beta edit" "$T3/fake/src/a.c" "beta = 300"
expect_file_contains "divergent merge keeps committed delta edit" "$T3/fake/src/a.c" "delta = 100"
expect_file_contains "divergent merge takes upstream gamma edit" "$T3/fake/src/a.c" "gamma = 200"
expect_file_contains "divergent merge takes upstream v2 alpha" "$T3/fake/src/a.c" "alpha = 2"
expect_file_not_contains "divergent merge has no conflict markers" "$T3/fake/src/a.c" "<<<<<<<"
if grep -q "^Conflict:" "$T3/fake.projeny.status"; then
    fail "divergent merge records no conflicts" "$(cat "$T3/fake.projeny.status")"
else
    ok "divergent merge records no conflicts"
fi

# --------------------------- 4. conflicting setup merge + resolve + commit
T4="$ROOT/t4"
make_tarballs "$T4" fake
write_projeny "$T4" fake 1.0 fake
(cd "$T4" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T4/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 1;", "int beta = 10;")
open(p, "w").write(s)
EOF
(cd "$T4" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$T4/fake.projeny" "$ROOT/t4-local.projeny"
rm -rf "$T4/fake" "$T4/fake.projeny.status"
cp "$ROOT/t4-local.projeny" "$T4/fake.projeny"
(cd "$T4" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T4/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 10;", "int beta = 999;")
open(p, "w").write(s)
EOF
# upstream changes the same beta line differently (same base region).
U4="$ROOT/t4up"
mkdir -p "$U4"
cp "$T4/fake-1.0.tar.gz" "$U4/"
cp "$ROOT/t4-local.projeny" "$U4/fake.projeny"
(cd "$U4" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$U4/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 10;", "int beta = 555;")
open(p, "w").write(s)
EOF
(cd "$U4" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$U4/fake.projeny" "$T4/fake.projeny"
run_in "$T4" expect_ok "conflicting setup merge exits 0 (with markers)" "$PROJENY" setup fake.projeny
expect_file_contains "conflicting merge leaves markers" "$T4/fake/src/a.c" "<<<<<<<"
expect_file_contains "conflicting merge lists conflict in status" "$T4/fake.projeny.status" "Conflict: src/a.c"
run_in "$T4" expect_fail "commit fails while conflicted" "$PROJENY" commit fake.projeny
printf 'int alpha = 1;\n\nint beta = 777;\n\nint gamma = 1;\n\nint delta = 1;\n' > "$T4/fake/src/a.c"
run_in "$T4" expect_ok "resolve clears conflict" "$PROJENY" resolve fake.projeny fake/src/a.c
if grep -q "^Conflict:" "$T4/fake.projeny.status"; then
    fail "resolve removes conflict entry" "$(cat "$T4/fake.projeny.status")"
else
    ok "resolve removes conflict entry"
fi
run_in "$T4" expect_ok "commit succeeds after resolve" "$PROJENY" commit fake.projeny
expect_file_contains "post-resolve commit stores resolution" "$T4/fake.projeny" "beta = 777"

# ------------------------------------------------- 5. add + commit (new file)
T5="$ROOT/t5"
make_tarballs "$T5" fake
write_projeny "$T5" fake 1.0 fake
(cd "$T5" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
printf 'brand new file\n' > "$T5/fake/src/added.c"
run_in "$T5" expect_ok "add marks new file" "$PROJENY" add fake.projeny fake/src/added.c
expect_file_contains "add records pending op in status" "$T5/fake.projeny.status" "Added: src/added.c"
run_in "$T5" expect_ok "commit folds add into patch" "$PROJENY" commit fake.projeny
expect_file_contains "add commit stores new-file diff" "$T5/fake.projeny" "new file"
expect_file_contains "add commit keeps new content" "$T5/fake.projeny" "brand new file"
run_in "$T5" expect_ok "setup-again after add-commit" "$PROJENY" setup fake.projeny
expect_file_contains "added file survives re-setup" "$T5/fake/src/added.c" "brand new file"

# ----------------------------------------------- 6. rm + commit (deletion)
T6="$ROOT/t6"
make_tarballs "$T6" fake
write_projeny "$T6" fake 1.0 fake
(cd "$T6" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
run_in "$T6" expect_ok "rm marks deletion" "$PROJENY" rm fake.projeny fake/src/b.c
if [ ! -e "$T6/fake/src/b.c" ]; then
    ok "rm removes file from workdir"
else
    fail "rm removes file from workdir"
fi
expect_file_contains "rm records pending op in status" "$T6/fake.projeny.status" "Removed: src/b.c"
run_in "$T6" expect_ok "commit folds rm into patch" "$PROJENY" commit fake.projeny
expect_file_contains "rm commit stores deletion diff" "$T6/fake.projeny" "deleted file"
run_in "$T6" expect_ok "setup-again after rm-commit" "$PROJENY" setup fake.projeny
if [ ! -e "$T6/fake/src/b.c" ]; then
    ok "deleted file stays deleted after re-setup"
else
    fail "deleted file stays deleted after re-setup"
fi

# ------------------------------------------------------ 7. mv + commit
T7="$ROOT/t7"
make_tarballs "$T7" fake
write_projeny "$T7" fake 1.0 fake
(cd "$T7" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
run_in "$T7" expect_ok "mv renames file" "$PROJENY" mv fake.projeny fake/src/b.c fake/src/renamed.c
expect_file_contains "mv records pending op in status" "$T7/fake.projeny.status" "Renamed: src/b.c -> src/renamed.c"
run_in "$T7" expect_ok "commit folds mv into patch" "$PROJENY" commit fake.projeny
expect_file_contains "mv commit stores rename" "$T7/fake.projeny" "rename from"
run_in "$T7" expect_ok "setup-again after mv-commit" "$PROJENY" setup fake.projeny
if [ -f "$T7/fake/src/renamed.c" ] && [ ! -e "$T7/fake/src/b.c" ]; then
    ok "rename survives re-setup"
else
    fail "rename survives re-setup" "ls: $(ls "$T7/fake/src" 2>&1)"
fi

# ------------------------------------------------------- 8. rebase clean
T8="$ROOT/t8"
make_tarballs "$T8" fake
write_projeny "$T8" fake 1.0 fake
(cd "$T8" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T8/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int delta = 1;", "int delta = 42;")
open(p, "w").write(s)
EOF
(cd "$T8" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
run_in "$T8" expect_ok "clean rebase exits 0" "$PROJENY" rebase fake.projeny fake-2.0.tar.gz
expect_file_contains "rebase updates Archive header" "$T8/fake.projeny" "Archive: fake-2.0.tar.gz"
expect_file_contains "rebase updates Origname header" "$T8/fake.projeny" "Origname: fake-2.0"
expect_file_contains "rebase keeps local delta change" "$T8/fake/src/a.c" "delta = 42"
expect_file_contains "rebase takes new alpha" "$T8/fake/src/a.c" "alpha = 2"

# ------------------------------------------------------- 9. rebase conflict
T9="$ROOT/t9"
make_tarballs "$T9" fake
write_projeny "$T9" fake 1.0 fake
(cd "$T9" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T9/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int alpha = 1;", "int alpha = 100;")
open(p, "w").write(s)
EOF
(cd "$T9" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
run_in "$T9" expect_ok "conflicting rebase exits 0 (with markers)" "$PROJENY" rebase fake.projeny fake-2.0.tar.gz
expect_file_contains "conflicting rebase leaves markers" "$T9/fake/src/a.c" "<<<<<<<"
expect_file_contains "conflicting rebase records conflict" "$T9/fake.projeny.status" "Conflict: src/a.c"
expect_file_contains "conflicting rebase still updates Archive" "$T9/fake.projeny" "Archive: fake-2.0.tar.gz"

# ----------------------------------------- 10. missing-status setup error
T10="$ROOT/t10"
make_tarballs "$T10" fake
write_projeny "$T10" fake 1.0 fake
(cd "$T10" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
rm "$T10/fake.projeny.status"
run_in "$T10" expect_fail "setup without status hard-errors" "$PROJENY" setup fake.projeny

# ----------------------------------------- 11. bad tarball (multi top-level)
T11="$ROOT/t11"
mkdir -p "$T11/top1" "$T11/top2"
printf 'a\n' > "$T11/top1/f.c"
printf 'b\n' > "$T11/top2/g.c"
(cd "$T11" && tar -czf bad.tar.gz top1 top2)
cat > "$T11/b.projeny" <<'EOF'
Archive: bad.tar.gz
Origname: top1
Name: b

    Bad tarball fixture.

EOF
run_in "$T11" expect_fail "multi-top-level tarball hard-errors" "$PROJENY" setup b.projeny

# ----------------------------------------- 12. commit-after-projeny-edit error
T12="$ROOT/t12"
make_tarballs "$T12" fake
write_projeny "$T12" fake 1.0 fake
(cd "$T12" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
printf '# sneaky hand edit\n' >> "$T12/fake.projeny"
run_in "$T12" expect_fail "commit after projeny edit hard-errors" "$PROJENY" commit fake.projeny

# ----------------------------------------- 13. rebase dirty-tree refusal
T13="$ROOT/t13"
make_tarballs "$T13" fake
write_projeny "$T13" fake 1.0 fake
(cd "$T13" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
printf 'uncommitted change\n' >> "$T13/fake/src/a.c"
run_in "$T13" expect_fail "rebase with dirty tree fails" "$PROJENY" rebase fake.projeny fake-2.0.tar.gz

# ----------------------------------------- 14. rebase setup-first fallback
T14="$ROOT/t14"
make_tarballs "$T14" fake
write_projeny "$T14" fake 1.0 fake
run_in "$T14" expect_ok "rebase without setup runs setup first" "$PROJENY" rebase fake.projeny fake-2.0.tar.gz
expect_file_contains "setup-first rebase updates Archive" "$T14/fake.projeny" "Archive: fake-2.0.tar.gz"
expect_file_contains "setup-first rebase unpacks new tree" "$T14/fake/README" "hello v2"

# ----------------------------------------- 15. trailing-whitespace roundtrip
# A file whose content lines end in spaces/tabs must survive commit followed
# by a fresh setup byte-for-byte (normalize_patch_text must not rtrim them).
T15="$ROOT/t15"
make_tarballs "$T15" fake
write_projeny "$T15" fake 1.0 fake
(cd "$T15" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
printf 'keep   \nline2\t\n  indented  \n' > "$T15/fake/src/spacey.c"
run_in "$T15" expect_ok "add trailing-whitespace file" "$PROJENY" add fake.projeny fake/src/spacey.c
run_in "$T15" expect_ok "commit trailing-whitespace file" "$PROJENY" commit fake.projeny
cp "$T15/fake/src/spacey.c" "$ROOT/t15-expect-spacey.c"
rm -rf "$T15/fake" "$T15/fake.projeny.status"
run_in "$T15" expect_ok "fresh setup after whitespace commit" "$PROJENY" setup fake.projeny
if cmp -s "$T15/fake/src/spacey.c" "$ROOT/t15-expect-spacey.c"; then
    ok "trailing-whitespace file identical after fresh setup"
else
    fail "trailing-whitespace file identical after fresh setup" "got: $(cat -A "$T15/fake/src/spacey.c" 2>&1)"
fi
# Appending another trailing-space line + committing must also roundtrip.
printf 'extra   \n' >> "$T15/fake/src/spacey.c"
cp "$T15/fake/src/spacey.c" "$ROOT/t15-expect-spacey.c"
run_in "$T15" expect_ok "commit appended trailing-whitespace line" "$PROJENY" commit fake.projeny
rm -rf "$T15/fake" "$T15/fake.projeny.status"
run_in "$T15" expect_ok "fresh setup after append commit" "$PROJENY" setup fake.projeny
if cmp -s "$T15/fake/src/spacey.c" "$ROOT/t15-expect-spacey.c"; then
    ok "appended trailing-whitespace line identical after fresh setup"
else
    fail "appended trailing-whitespace line identical after fresh setup" "got: $(cat -A "$T15/fake/src/spacey.c" 2>&1)"
fi

# ----------------------------------------- 16. pax-header tarball setup
# Tarballs carrying pax_global_header metadata entries must still enforce
# exactly-one-top-dir on the REAL content and set up cleanly.
T16="$ROOT/t16"
make_tarballs "$T16" fake
if command -v python3 >/dev/null 2>&1; then
    (cd "$T16" && python3 - fake-1.0.tar.gz <<'PYEOF'
import sys, tarfile, io, os
src, dst = sys.argv[1], "pax-fake-1.0.tar.gz"
os.makedirs("_px/fake-1.0", exist_ok=True)
with tarfile.open(src) as t:
    t.extractall("_px")
with tarfile.open(dst, "w") as t:
    meta = b"pax metadata, not content\n"
    ti = tarfile.TarInfo("pax_global_header")
    ti.size = len(meta)
    ti.mtime = 0
    t.addfile(ti, io.BytesIO(meta))
    t.add("_px/fake-1.0", arcname="fake-1.0")
PYEOF
    )
    rm -rf "$T16/_px"
    cat > "$T16/pax.projeny" <<'EOF'
Archive: pax-fake-1.0.tar.gz
Origname: fake-1.0
Name: paxfake

    Pax-header fixture.

EOF
    run_in "$T16" expect_ok "pax-header tarball setup exits 0" "$PROJENY" setup pax.projeny
    expect_file_contains "pax-header tarball unpacks real content" "$T16/paxfake/README" "hello v1"
    if [ -e "$T16/paxfake/pax_global_header" ]; then
        fail "pax-header metadata not left in workdir" "$(ls "$T16/paxfake")"
    else
        ok "pax-header metadata not left in workdir"
    fi
else
    ok "pax-header tarball setup exits 0 (skipped: no python3)"
    ok "pax-header tarball unpacks real content (skipped: no python3)"
    ok "pax-header metadata not left in workdir (skipped: no python3)"
fi

# ----------------------------------------- 17. no-trailing-newline projeny
# A .projeny file without a final newline must set up AND commit cleanly
# (bytes preserved exactly; commit compares raw bytes).
T17="$ROOT/t17"
make_tarballs "$T17" fake
printf 'Archive: fake-1.0.tar.gz\nOrigname: fake-1.0\nName: fake\n\n    No trailing newline.' > "$T17/fake.projeny"
run_in "$T17" expect_ok "no-newline projeny setup exits 0" "$PROJENY" setup fake.projeny
expect_file_contains "no-newline projeny unpacks tree" "$T17/fake/README" "hello v1"
python3 - "$T17/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int alpha = 1;", "int alpha = 11;")
open(p, "w").write(s)
EOF
run_in "$T17" expect_ok "no-newline projeny commit exits 0" "$PROJENY" commit fake.projeny
expect_file_contains "no-newline commit stores diff" "$T17/fake.projeny" "alpha = 11"
run_in "$T17" expect_ok "setup-again after no-newline commit" "$PROJENY" setup fake.projeny
expect_file_contains "no-newline roundtrip keeps edit" "$T17/fake/src/a.c" "alpha = 11"

# ----------------------------------------- 18. tricky filenames in status
# Filenames containing " -> " and spaces must survive add/mv/commit/setup via
# the backslash-escaped status file (split on the unescaped separator only).
T18="$ROOT/t18"
mkdir -p "$T18/w-1.0/src"
printf 'int x = 1;\n' > "$T18/w-1.0/src/a.c"
printf 'old\n' > "$T18/w-1.0/src/old -> file.c"
(cd "$T18" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Tricky names.\n' > "$T18/w.projeny"
(cd "$T18" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
run_in "$T18" expect_ok "mv arrow-name file" "$PROJENY" mv w.projeny "w/src/old -> file.c" "w/src/new -> file.c"
expect_file_contains "status stores escaped rename" "$T18/w.projeny.status" 'Renamed: src/old -\> file.c -> src/new -\> file.c'
run_in "$T18" expect_ok "add alongside tricky rename" "$PROJENY" add w.projeny w/src/a.c
run_in "$T18" expect_ok "commit tricky rename" "$PROJENY" commit w.projeny
expect_file_contains "tricky commit stores rename" "$T18/w.projeny" "rename from"
rm -rf "$T18/w" "$T18/w.projeny.status"
run_in "$T18" expect_ok "fresh setup after tricky commit" "$PROJENY" setup w.projeny
if [ -f "$T18/w/src/new -> file.c" ] && [ ! -e "$T18/w/src/old -> file.c" ]; then
    ok "tricky rename survives re-setup"
else
    fail "tricky rename survives re-setup" "ls: $(ls "$T18/w/src" 2>&1)"
fi

# ----------------------------------------- 19. resolve warns on markers
# resolve must warn to stderr when markers remain, but still resolve.
T19="$ROOT/t19"
make_tarballs "$T19" fake
write_projeny "$T19" fake 1.0 fake
(cd "$T19" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
printf 'int alpha = 1;\n\nint beta = 1;\n\nint gamma = 1;\n\nint delta = 1;\n' > "$T19/fake/src/a.c"
(cd "$T19" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$T19/fake.projeny" "$ROOT/t19-local.projeny"
rm -rf "$T19/fake" "$T19/fake.projeny.status"
cp "$ROOT/t19-local.projeny" "$T19/fake.projeny"
(cd "$T19" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T19/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 1;", "int beta = 999;")
open(p, "w").write(s)
EOF
U19="$ROOT/t19up"
mkdir -p "$U19"
cp "$T19/fake-1.0.tar.gz" "$U19/"
cp "$ROOT/t19-local.projeny" "$U19/fake.projeny"
(cd "$U19" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$U19/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 1;", "int beta = 555;")
open(p, "w").write(s)
EOF
(cd "$U19" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$U19/fake.projeny" "$T19/fake.projeny"
run_in "$T19" expect_ok "conflicting setup leaves markers (t19)" "$PROJENY" setup fake.projeny
expect_file_contains "t19 merge leaves markers" "$T19/fake/src/a.c" "<<<<<<<"
out="$(cd "$T19" && "$PROJENY" resolve fake.projeny fake/src/a.c 2>&1)"
rc=$?
if [ $rc -eq 0 ]; then
    ok "resolve with markers still exits 0"
else
    fail "resolve with markers still exits 0" "exit=$rc out: $out"
fi
case "$out" in
*conflict*marker*|*marker*|*warning*)
    ok "resolve with markers warns on stderr"
    ;;
*)
    if [ -f "$T19/fake/src/a.c" ] && grep -q "<<<<<<<" "$T19/fake/src/a.c"; then
        fail "resolve with markers warns on stderr" "no warning; out: $out"
    else
        ok "resolve with markers warns on stderr (no markers left)"
    fi
    ;;
esac

# ----------------------------------------- 20. tar escape rejection
# Symlink members pointing outside the tree must hard-error on setup.
T20="$ROOT/t20"
mkdir -p "$T20/evil-1.0"
printf 'hi\n' > "$T20/evil-1.0/f.c"
ln -s /etc/passwd "$T20/evil-1.0/evil-link"
(cd "$T20" && tar -czf evil-1.0.tar.gz evil-1.0)
cat > "$T20/e.projeny" <<'EOF'
Archive: evil-1.0.tar.gz
Origname: evil-1.0
Name: e

    Evil tarball fixture.

EOF
run_in "$T20" expect_fail "absolute symlink target hard-errors" "$PROJENY" setup e.projeny

# ----------------------------------------- 21. rebase keeps pending ops
# Pending add/rm/mv operations must survive a clean rebase.
T21="$ROOT/t21"
make_tarballs "$T21" fake
write_projeny "$T21" fake 1.0 fake
(cd "$T21" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
printf 'pending new\n' > "$T21/fake/src/pending.c"
run_in "$T21" expect_ok "stage pending add before rebase" "$PROJENY" add fake.projeny fake/src/pending.c
run_in "$T21" expect_ok "clean rebase with pending add" "$PROJENY" rebase fake.projeny fake-2.0.tar.gz
expect_file_contains "rebase preserves pending add" "$T21/fake.projeny.status" "Added: src/pending.c"
expect_file_contains "rebase keeps pending file" "$T21/fake/src/pending.c" "pending new"

# ----------------------------------------- 22. bare resolve path UX
# resolve must accept the stored wid-relative form without the <Name>/ prefix.
T22="$ROOT/t22"
make_tarballs "$T22" fake
write_projeny "$T22" fake 1.0 fake
(cd "$T22" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T22/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 1;", "int beta = 10;")
open(p, "w").write(s)
EOF
(cd "$T22" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$T22/fake.projeny" "$ROOT/t22-local.projeny"
rm -rf "$T22/fake" "$T22/fake.projeny.status"
cp "$ROOT/t22-local.projeny" "$T22/fake.projeny"
(cd "$T22" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T22/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 10;", "int beta = 999;")
open(p, "w").write(s)
EOF
U22="$ROOT/t22up"
mkdir -p "$U22"
cp "$T22/fake-1.0.tar.gz" "$U22/"
cp "$ROOT/t22-local.projeny" "$U22/fake.projeny"
(cd "$U22" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$U22/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 10;", "int beta = 555;")
open(p, "w").write(s)
EOF
(cd "$U22" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
cp "$U22/fake.projeny" "$T22/fake.projeny"
(cd "$T22" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
printf 'int alpha = 1;\n\nint beta = 777;\n\nint gamma = 1;\n\nint delta = 1;\n' > "$T22/fake/src/a.c"
run_in "$T22" expect_ok "resolve accepts bare wid-relative path" "$PROJENY" resolve fake.projeny src/a.c
if grep -q "^Conflict:" "$T22/fake.projeny.status"; then
    fail "bare resolve removes conflict entry" "$(cat "$T22/fake.projeny.status")"
else
    ok "bare resolve removes conflict entry"
fi

# ----------------------------------------- 23. space/arrow filenames roundtrip
# Filenames with spaces and "->" used to produce un-applyable patches: git
# leaves them unquoted, the "diff --git" split misparsed, and the stored patch
# leaked absolute tmp labels with ---/+++ disagreeing. Commit two such files,
# wipe, and fresh-setup must reproduce them byte-identical.
T23="$ROOT/t23"
mkdir -p "$T23/w-1.0"
printf 'base\n' > "$T23/w-1.0/base.c"
(cd "$T23" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Space/arrow names.\n' > "$T23/w.projeny"
(cd "$T23" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'new\n' > "$T23/w/new -> file.c"
printf 'new2\n' > "$T23/w/my file.c"
cp "$T23/w/new -> file.c" "$ROOT/t23-expect-arrow.c"
cp "$T23/w/my file.c" "$ROOT/t23-expect-space.c"
run_in "$T23" expect_ok "add arrow-name file" "$PROJENY" add w.projeny "w/new -> file.c"
run_in "$T23" expect_ok "add space-name file" "$PROJENY" add w.projeny "w/my file.c"
run_in "$T23" expect_ok "commit space/arrow files" "$PROJENY" commit w.projeny
if grep -q "tmp" "$T23/w.projeny"; then
    fail "space/arrow commit stores no absolute tmp labels" "$(grep '^diff --git' "$T23/w.projeny")"
else
    ok "space/arrow commit stores no absolute tmp labels"
fi
# The stored patch must pass git's own consistency check (diff --git agrees
# with ---/+++). Extract the patch, relabel wid prefixes (as projeny does for
# -p1 application with cwd=tree), and check against the pristine base.
if command -v python3 >/dev/null 2>&1; then
    (cd "$T23" && sed -n '/^diff --git /,$p' w.projeny > patch-extract.diff && mkdir -p check-base && tar -xzf w-1.0.tar.gz -C check-base && python3 - patch-extract.diff check-relabeled.diff <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
s = s.replace("a/w/", "a/").replace("b/w/", "b/")
open(sys.argv[2], "w").write(s)
PYEOF
    )
    if (cd "$T23/check-base/w-1.0" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CEILING_DIRECTORIES=/ GIT_DIR=/dev/null/no-such-projeny-repo GIT_WORK_TREE= git apply -p1 --whitespace=nowarn --check ../../check-relabeled.diff 2>/dev/null); then
        ok "space/arrow stored patch passes git apply --check"
    else
        fail "space/arrow stored patch passes git apply --check"
    fi
    rm -rf "$T23/check-base" "$T23/patch-extract.diff" "$T23/check-relabeled.diff"
else
    ok "space/arrow stored patch passes git apply --check (skipped: no python3)"
fi
rm -rf "$T23/w" "$T23/w.projeny.status"
run_in "$T23" expect_ok "fresh setup after space/arrow commit" "$PROJENY" setup w.projeny
if cmp -s "$T23/w/new -> file.c" "$ROOT/t23-expect-arrow.c"; then
    ok "arrow-name file identical after fresh setup"
else
    fail "arrow-name file identical after fresh setup" "ls: $(ls "$T23/w" 2>&1)"
fi
if cmp -s "$T23/w/my file.c" "$ROOT/t23-expect-space.c"; then
    ok "space-name file identical after fresh setup"
else
    fail "space-name file identical after fresh setup" "ls: $(ls "$T23/w" 2>&1)"
fi

# ------------------------------------------------------------- summary
echo "---"
echo "passed: $PASS, failed: $FAIL"
rm -rf "$ROOT"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
exit 0
