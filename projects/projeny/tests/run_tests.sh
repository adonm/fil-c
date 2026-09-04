#!/bin/bash
# projeny test suite: fixture-based shell tests over tiny fake-project
# tarballs v1/v2. Covers fresh setup, edit+commit roundtrips, setup-again
# noops, divergent merges (clean + conflicting), add/rm/mv + commit,
# rebase (clean + conflict), and the hard-error paths.
#
# Bash is required (process substitution in the status-copy comparisons
# below); /bin/sh (dash) cannot run this suite.
#
# Usage: ./tests/run_tests.sh ./projeny
# Exits nonzero on failure; prints ok/FAIL lines plus summary counts.
#
# Copyright (c) 2026 Filip Pizlo. All Rights Reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY FILIP PIZLO ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL FILIP PIZLO OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
    # projeny itself needs only tar at runtime (diff/patch/merge are
    # internal); git/patch below are used solely for optional compatibility
    # spot-checks, which skip themselves when the helper is absent.
    for t in tar; do
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
# Skipped when git or python3 is unavailable (projeny itself needs neither).
if command -v python3 >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
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
elif command -v python3 >/dev/null 2>&1; then
    ok "space/arrow stored patch passes git apply --check (skipped: no git)"
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

# ----------------------------------------- 24. empty files roundtrip
T24="$ROOT/t24"
mkdir -p "$T24/w-1.0"
printf 'normal\n' > "$T24/w-1.0/n.c"
: > "$T24/w-1.0/empty.c"
(cd "$T24" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Empty files.\n' > "$T24/w.projeny"
run_in "$T24" expect_ok "setup with empty base file" "$PROJENY" setup w.projeny
if [ ! -f "$T24/w/empty.c" ]; then
    fail "empty base file unpacked"
else
    if [ -s "$T24/w/empty.c" ]; then
        fail "empty base file is really empty"
    else
        ok "empty base file is really empty"
    fi
fi
: > "$T24/w/newempty.c"
run_in "$T24" expect_ok "add empty file" "$PROJENY" add w.projeny w/newempty.c
run_in "$T24" expect_ok "commit empty file" "$PROJENY" commit w.projeny
expect_file_contains "empty commit stores new-file entry" "$T24/w.projeny" "new file mode"
rm -rf "$T24/w" "$T24/w.projeny.status"
run_in "$T24" expect_ok "setup after empty commit" "$PROJENY" setup w.projeny
if [ -f "$T24/w/newempty.c" ] && [ ! -s "$T24/w/newempty.c" ]; then
    ok "empty added file survives re-setup"
else
    fail "empty added file survives re-setup" "ls: $(ls -l "$T24/w" 2>&1)"
fi
run_in "$T24" expect_ok "rm empty file" "$PROJENY" rm w.projeny w/empty.c
run_in "$T24" expect_ok "commit empty rm" "$PROJENY" commit w.projeny
rm -rf "$T24/w" "$T24/w.projeny.status"
run_in "$T24" expect_ok "setup after empty rm" "$PROJENY" setup w.projeny
if [ ! -e "$T24/w/empty.c" ]; then
    ok "deleted empty file stays deleted"
else
    fail "deleted empty file stays deleted"
fi

# ----------------------------------------- 25. missing trailing newline
T25="$ROOT/t25"
mkdir -p "$T25/w-1.0"
printf 'aaa\nbbb' > "$T25/w-1.0/nonl.c"
printf 'x\n' > "$T25/w-1.0/nl.c"
(cd "$T25" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    No-newline files.\n' > "$T25/w.projeny"
run_in "$T25" expect_ok "no-newline setup" "$PROJENY" setup w.projeny
printf 'aaa\nBBB' > "$T25/w/nonl.c"
run_in "$T25" expect_ok "no-newline commit" "$PROJENY" commit w.projeny
expect_file_contains "no-newline commit stores marker" "$T25/w.projeny" "No newline at end of file"
cp "$T25/w/nonl.c" "$ROOT/t25-expect-nonl.c"
rm -rf "$T25/w" "$T25/w.projeny.status"
run_in "$T25" expect_ok "setup after no-newline commit" "$PROJENY" setup w.projeny
if cmp -s "$T25/w/nonl.c" "$ROOT/t25-expect-nonl.c"; then
    ok "no-newline file byte-identical after re-setup"
else
    fail "no-newline file byte-identical after re-setup" "got: $(xxd "$T25/w/nonl.c" 2>&1)"
fi
printf 'brand new no newline' > "$T25/w/added-no-nl.c"
run_in "$T25" expect_ok "add no-newline file" "$PROJENY" add w.projeny w/added-no-nl.c
run_in "$T25" expect_ok "commit no-newline add" "$PROJENY" commit w.projeny
cp "$T25/w/added-no-nl.c" "$ROOT/t25-expect-added.c"
rm -rf "$T25/w" "$T25/w.projeny.status"
run_in "$T25" expect_ok "setup after no-newline add" "$PROJENY" setup w.projeny
if cmp -s "$T25/w/added-no-nl.c" "$ROOT/t25-expect-added.c"; then
    ok "added no-newline file byte-identical after re-setup"
else
    fail "added no-newline file byte-identical after re-setup"
fi

# ----------------------------------------- 26. CRLF line endings roundtrip
T26="$ROOT/t26"
mkdir -p "$T26/w-1.0"
printf 'line1\r\nline2\r\nline3\r\n' > "$T26/w-1.0/crlf.c"
printf 'plain\n' > "$T26/w-1.0/n.c"
(cd "$T26" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    CRLF files.\n' > "$T26/w.projeny"
run_in "$T26" expect_ok "crlf setup" "$PROJENY" setup w.projeny
printf 'line1\r\nLINE2\r\nline3\r\n' > "$T26/w/crlf.c"
run_in "$T26" expect_ok "crlf commit" "$PROJENY" commit w.projeny
if grep -q "$(printf '\r')" "$T26/w.projeny"; then
    ok "crlf commit preserves CR bytes in patch"
else
    fail "crlf commit preserves CR bytes in patch"
fi
cp "$T26/w/crlf.c" "$ROOT/t26-expect-crlf.c"
rm -rf "$T26/w" "$T26/w.projeny.status"
run_in "$T26" expect_ok "setup after crlf commit" "$PROJENY" setup w.projeny
if cmp -s "$T26/w/crlf.c" "$ROOT/t26-expect-crlf.c"; then
    ok "crlf file byte-identical after re-setup"
else
    fail "crlf file byte-identical after re-setup" "got: $(xxd "$T26/w/crlf.c" 2>&1)"
fi

# ----------------------------------------- 27. large file, distant edits
T27="$ROOT/t27"
mkdir -p "$T27/w-1.0"
seq 1 5000 > "$T27/w-1.0/big.txt"
(cd "$T27" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Large file.\n' > "$T27/w.projeny"
run_in "$T27" expect_ok "large setup" "$PROJENY" setup w.projeny
python3 - "$T27/w/big.txt" <<'EOF'
import sys
p = sys.argv[1]
ls = open(p).read().split("\n")
ls[99] = "CHANGED-100"
ls[4899] = "CHANGED-4900"
open(p, "w").write("\n".join(ls))
EOF
run_in "$T27" expect_ok "large commit" "$PROJENY" commit w.projeny
n_hunks="$(awk '/^diff --git /{f=1} f&&/^@@ /{c++} END{print c+0}' "$T27/w.projeny")"
if [ "$n_hunks" -ge 2 ]; then
    ok "large distant edits produce separate hunks ($n_hunks)"
else
    fail "large distant edits produce separate hunks" "found $n_hunks"
fi
cp "$T27/w/big.txt" "$ROOT/t27-expect-big.txt"
rm -rf "$T27/w" "$T27/w.projeny.status"
run_in "$T27" expect_ok "setup after large commit" "$PROJENY" setup w.projeny
if cmp -s "$T27/w/big.txt" "$ROOT/t27-expect-big.txt"; then
    ok "large file byte-identical after re-setup"
else
    fail "large file byte-identical after re-setup"
fi

# ----------------------------------------- 28. close edits share one hunk
T28="$ROOT/t28"
mkdir -p "$T28/w-1.0"
seq 1 30 > "$T28/w-1.0/n.txt"
(cd "$T28" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Hunk merging.\n' > "$T28/w.projeny"
(cd "$T28" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$T28/w/n.txt" <<'EOF'
import sys
p = sys.argv[1]
ls = open(p).read().split("\n")
ls[9] = "C10"
ls[13] = "C14"
open(p, "w").write("\n".join(ls))
EOF
run_in "$T28" expect_ok "close-edit commit" "$PROJENY" commit w.projeny
n_hunks="$(awk '/^diff --git /{f=1} f&&/^@@ /{c++} END{print c+0}' "$T28/w.projeny")"
if [ "$n_hunks" -eq 1 ]; then
    ok "close edits merge into one hunk"
else
    fail "close edits merge into one hunk" "found $n_hunks"
fi
cp "$T28/w/n.txt" "$ROOT/t28-expect-n.txt"
rm -rf "$T28/w" "$T28/w.projeny.status"
run_in "$T28" expect_ok "setup after close-edit commit" "$PROJENY" setup w.projeny
if cmp -s "$T28/w/n.txt" "$ROOT/t28-expect-n.txt"; then
    ok "close-edit file identical after re-setup"
else
    fail "close-edit file identical after re-setup"
fi

# ----------------------------------------- 29. binary files are refused
T29="$ROOT/t29"
make_tarballs "$T29" fake
write_projeny "$T29" fake 1.0 fake
(cd "$T29" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 -c "open('$T29/fake/src/bin.dat','wb').write(b'ab\x00cd\n')"
out="$(cd "$T29" && "$PROJENY" commit fake.projeny 2>&1)"
rc=$?
if [ $rc -ne 0 ]; then
    ok "commit with binary file fails"
else
    fail "commit with binary file fails" "exited 0"
fi
case "$out" in
*inary*)
    ok "binary failure message is clear"
    ;;
*)
    fail "binary failure message is clear" "out: $out"
    ;;
esac
rm -f "$T29/fake/src/bin.dat"
run_in "$T29" expect_ok "commit works after removing binary" "$PROJENY" commit fake.projeny

# ----------------------------------------- 30. executable bit roundtrips
T30="$ROOT/t30"
mkdir -p "$T30/w-1.0"
printf 'echo hi\n' > "$T30/w-1.0/run.sh"
printf 'code\n' > "$T30/w-1.0/f.c"
(cd "$T30" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Modes.\n' > "$T30/w.projeny"
run_in "$T30" expect_ok "mode setup" "$PROJENY" setup w.projeny
chmod 755 "$T30/w/run.sh"
printf 'echo HI\n' > "$T30/w/run.sh"
chmod 755 "$T30/w/run.sh"
run_in "$T30" expect_ok "mode+content commit" "$PROJENY" commit w.projeny
expect_file_contains "mode commit stores new mode" "$T30/w.projeny" "new mode 100755"
rm -rf "$T30/w" "$T30/w.projeny.status"
run_in "$T30" expect_ok "setup after mode commit" "$PROJENY" setup w.projeny
if [ -x "$T30/w/run.sh" ]; then
    ok "executable bit survives re-setup"
else
    fail "executable bit survives re-setup" "$(ls -l "$T30/w/run.sh" 2>&1)"
fi
expect_file_contains "mode commit keeps content" "$T30/w/run.sh" "echo HI"
# Content-only change on an executable file must not drop +x.
chmod 755 "$T30/w/run.sh"
printf 'echo YO\n' > "$T30/w/run.sh"
chmod 755 "$T30/w/run.sh"
run_in "$T30" expect_ok "second content commit" "$PROJENY" commit w.projeny
rm -rf "$T30/w" "$T30/w.projeny.status"
run_in "$T30" expect_ok "setup after second commit" "$PROJENY" setup w.projeny
if [ -x "$T30/w/run.sh" ]; then
    ok "content-only change keeps +x after re-setup"
else
    fail "content-only change keeps +x after re-setup" "$(ls -l "$T30/w/run.sh" 2>&1)"
fi

# ----------------------------------------- 31. patch compatibility
# (a) wid-stripped (plain a/b-label) patches still set up via projeny
# (no git needed); (b) stored patches pass git apply / patch -p1 checks
# when those helpers exist (projeny itself needs neither).
T31="$ROOT/t31"
make_tarballs "$T31" fake
write_projeny "$T31" fake 1.0 fake
(cd "$T31" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T31/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int beta = 1;", "int beta = 4242;")
open(p, "w").write(s)
EOF
(cd "$T31" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
mkdir -p "$T31/s-top-tmp"
(cd "$T31" && tar -xzf fake-1.0.tar.gz && mv fake-1.0 s-top && tar -czf s.tar.gz s-top && rm -rf s-top)
cat > "$T31/s.projeny" <<'EOF'
Archive: s.tar.gz
Origname: s-top
Name: s

    Stripped-label fixture.

EOF
(sed -n '/^diff --git /,$p' "$T31/fake.projeny" | sed 's|a/fake/|a/|g; s|b/fake/|b/|g' >> "$T31/s.projeny")
run_in "$T31" expect_ok "setup with plain a/b-label patch" "$PROJENY" setup s.projeny
expect_file_contains "plain-label setup applies content" "$T31/s/src/a.c" "beta = 4242"
# Hand-written p0-style patch (no a/ b/ prefixes at all).
cat > "$T31/h.projeny" <<'EOF'
Archive: s.tar.gz
Origname: s-top
Name: h

    Hand-written fixture.

diff --git a/h/README b/h/README
--- README
+++ README
@@ -1,1 +1,1 @@
-hello v1
+hello HAND
EOF
run_in "$T31" expect_ok "setup with hand-written p0 patch" "$PROJENY" setup h.projeny
expect_file_contains "p0 patch applies content" "$T31/h/README" "hello HAND"
if command -v git >/dev/null 2>&1; then
    (cd "$T31" && sed -n '/^diff --git /,$p' fake.projeny > compat-git.diff && sed -i 's|a/fake/|a/|g; s|b/fake/|b/|g' compat-git.diff && rm -rf compat-base && mkdir compat-base && tar -xzf fake-1.0.tar.gz -C compat-base)
    if (cd "$T31/compat-base/fake-1.0" && git apply -p1 --whitespace=nowarn --check ../../compat-git.diff 2>/dev/null); then
        ok "stored patch passes git apply --check"
    else
        fail "stored patch passes git apply --check"
    fi
    rm -rf "$T31/compat-base" "$T31/compat-git.diff"
else
    ok "stored patch passes git apply --check (skipped: no git)"
fi
if command -v patch >/dev/null 2>&1; then
    (cd "$T31" && sed -n '/^diff --git /,$p' fake.projeny > compat-patch.diff && sed -i 's|a/fake/|a/|g; s|b/fake/|b/|g' compat-patch.diff && rm -rf compat-pbase && mkdir compat-pbase && tar -xzf fake-1.0.tar.gz -C compat-pbase)
    if (cd "$T31/compat-pbase/fake-1.0" && patch -p1 --dry-run < ../../compat-patch.diff >/dev/null 2>&1); then
        ok "stored patch passes patch -p1 --dry-run"
    else
        fail "stored patch passes patch -p1 --dry-run"
    fi
    rm -rf "$T31/compat-pbase" "$T31/compat-patch.diff"
else
    ok "stored patch passes patch -p1 --dry-run (skipped: no patch)"
fi

# ----------------------------------------- 32. applier tolerates bad hunk offsets
T32="$ROOT/t32"
make_tarballs "$T32" fake
write_projeny "$T32" fake 1.0 fake
(cd "$T32" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T32/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int gamma = 1;", "int gamma = 7777;")
open(p, "w").write(s)
EOF
(cd "$T32" && "$PROJENY" commit fake.projeny >/dev/null 2>&1)
python3 - "$T32/fake.projeny" <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
def bump(m):
    return "@@ -%d,%s +%s,%s @@" % (int(m.group(1)) + 6, m.group(2), m.group(3), m.group(4))
s2 = re.sub(r"@@ -(\d+),(\d+) \+(\d+),(\d+) @@", bump, s, count=1)
assert s2 != s
open(p, "w").write(s2)
PYEOF
cp "$T32/fake/src/a.c" "$ROOT/t32-expect-a.c" 2>/dev/null || true
rm -rf "$T32/fake" "$T32/fake.projeny.status"
run_in "$T32" expect_ok "setup applies patch with shifted hunk offsets" "$PROJENY" setup fake.projeny
expect_file_contains "shifted-offset setup yields right content" "$T32/fake/src/a.c" "gamma = 7777"

# ----------------------------------------- 33. rename with modification
T33="$ROOT/t33"
mkdir -p "$T33/w-1.0"
seq 1 10 > "$T33/w-1.0/nums.txt"
(cd "$T33" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Rename+edit.\n' > "$T33/w.projeny"
(cd "$T33" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
run_in "$T33" expect_ok "mv for rename+edit" "$PROJENY" mv w.projeny w/nums.txt w/digits.txt
python3 - "$T33/w/digits.txt" <<'EOF'
import sys
p = sys.argv[1]
ls = open(p).read().split("\n")
ls[4] = "FIVE"
open(p, "w").write("\n".join(ls))
EOF
run_in "$T33" expect_ok "commit rename+edit" "$PROJENY" commit w.projeny
expect_file_contains "rename+edit stores rename" "$T33/w.projeny" "rename from"
expect_file_contains "rename+edit stores content hunk" "$T33/w.projeny" "FIVE"
rm -rf "$T33/w" "$T33/w.projeny.status"
run_in "$T33" expect_ok "setup after rename+edit" "$PROJENY" setup w.projeny
if [ -f "$T33/w/digits.txt" ] && [ ! -e "$T33/w/nums.txt" ]; then
    ok "rename+edit paths correct after re-setup"
else
    fail "rename+edit paths correct after re-setup" "ls: $(ls "$T33/w" 2>&1)"
fi
expect_file_contains "rename+edit content correct" "$T33/w/digits.txt" "FIVE"

# ----------------------------------------- 34. manual delete+add of same content
T34="$ROOT/t34"
mkdir -p "$T34/w-1.0"
printf 'identical bytes\n' > "$T34/w-1.0/oldname.txt"
(cd "$T34" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Manual rename.\n' > "$T34/w.projeny"
(cd "$T34" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
run_in "$T34" expect_ok "rm old for manual rename" "$PROJENY" rm w.projeny w/oldname.txt
printf 'identical bytes\n' > "$T34/w/newname.txt"
run_in "$T34" expect_ok "add new for manual rename" "$PROJENY" add w.projeny w/newname.txt
run_in "$T34" expect_ok "commit manual rename" "$PROJENY" commit w.projeny
expect_file_contains "manual rename detected as rename" "$T34/w.projeny" "rename from"
rm -rf "$T34/w" "$T34/w.projeny.status"
run_in "$T34" expect_ok "setup after manual rename" "$PROJENY" setup w.projeny
if [ -f "$T34/w/newname.txt" ] && [ ! -e "$T34/w/oldname.txt" ]; then
    ok "manual rename survives re-setup"
else
    fail "manual rename survives re-setup" "ls: $(ls "$T34/w" 2>&1)"
fi

# ----------------------------------------- 35. CLI error paths and help
T35="$ROOT/t35"
make_tarballs "$T35" fake
write_projeny "$T35" fake 1.0 fake
(cd "$T35" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
run_in "$T35" expect_fail "add missing file fails" "$PROJENY" add fake.projeny fake/src/nope.c
run_in "$T35" expect_fail "mv onto existing fails" "$PROJENY" mv fake.projeny fake/src/a.c fake/src/b.c
run_in "$T35" expect_fail "mv same src/dst fails" "$PROJENY" mv fake.projeny fake/src/a.c fake/src/a.c
run_in "$T35" expect_fail "resolve non-conflict fails" "$PROJENY" resolve fake.projeny fake/src/a.c
run_in "$T35" expect_fail "status of missing setup fails" "$PROJENY" status "$T35/never.projeny"
run_in "$T35" expect_ok "help exits 0" "$PROJENY" help
run_in "$T35" expect_fail "unknown command fails" "$PROJENY" frobnicate fake.projeny
run_in "$T35" expect_fail "setup with missing tarball fails" "$PROJENY" setup "$T35/never.projeny"
run_in "$T35" expect_ok "commit with no changes succeeds" "$PROJENY" commit fake.projeny
if grep -q "^diff --git " "$T35/fake.projeny"; then
    fail "no-change commit stores empty patch"
else
    ok "no-change commit stores empty patch"
fi
run_in "$T35" expect_ok "status shows setup" "$PROJENY" status fake.projeny

# ----------------------------------------- 36. symlinks roundtrip
T36="$ROOT/t36"
mkdir -p "$T36/w-1.0"
printf 'target content\n' > "$T36/w-1.0/real.txt"
ln -s real.txt "$T36/w-1.0/link"
(cd "$T36" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Symlinks.\n' > "$T36/w.projeny"
run_in "$T36" expect_ok "symlink setup" "$PROJENY" setup w.projeny
if [ -L "$T36/w/link" ] && [ "$(readlink "$T36/w/link")" = "real.txt" ]; then
    ok "symlink unpacked with target intact"
else
    fail "symlink unpacked with target intact" "ls: $(ls -l "$T36/w" 2>&1)"
fi
printf 'other\n' > "$T36/w/other.txt"
run_in "$T36" expect_ok "add symlink neighbor" "$PROJENY" add w.projeny w/other.txt
ln -sf other.txt "$T36/w/link"
run_in "$T36" expect_ok "commit retargeted symlink" "$PROJENY" commit w.projeny
expect_file_contains "symlink retarget stored" "$T36/w.projeny" "other.txt"
rm -rf "$T36/w" "$T36/w.projeny.status"
run_in "$T36" expect_ok "setup after symlink commit" "$PROJENY" setup w.projeny
if [ -L "$T36/w/link" ] && [ "$(readlink "$T36/w/link")" = "other.txt" ]; then
    ok "retargeted symlink survives re-setup"
else
    fail "retargeted symlink survives re-setup" "ls: $(ls -l "$T36/w" 2>&1)"
fi
# Dot-dot link targets are rejected at unpack.
T36B="$ROOT/t36b"
mkdir -p "$T36B/e-1.0"
printf 'x\n' > "$T36B/e-1.0/f.c"
ln -s sub/../f.c "$T36B/e-1.0/esc"
(cd "$T36B" && tar -czf e-1.0.tar.gz e-1.0)
printf 'Archive: e-1.0.tar.gz\nOrigname: e-1.0\nName: e\n\n    Escape.\n' > "$T36B/e.projeny"
run_in "$T36B" expect_fail "dotdot symlink target hard-errors" "$PROJENY" setup e.projeny

# ----------------------------------------- 37. adjacent hunks stay exact
T37="$ROOT/t37"
mkdir -p "$T37/w-1.0"
seq 1 40 > "$T37/w-1.0/n.txt"
(cd "$T37" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Adjacent.\n' > "$T37/w.projeny"
(cd "$T37" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$T37/w/n.txt" <<'EOF'
import sys
p = sys.argv[1]
ls = open(p).read().split("\n")
ls[9] = "C10"
ls[19] = "C20"
open(p, "w").write("\n".join(ls))
EOF
run_in "$T37" expect_ok "distant-edit commit" "$PROJENY" commit w.projeny
n_hunks="$(awk '/^diff --git /{f=1} f&&/^@@ /{c++} END{print c+0}' "$T37/w.projeny")"
if [ "$n_hunks" -eq 2 ]; then
    ok "edits 10 lines apart give two hunks"
else
    fail "edits 10 lines apart give two hunks" "found $n_hunks"
fi
cp "$T37/w/n.txt" "$ROOT/t37-expect-n.txt"
rm -rf "$T37/w" "$T37/w.projeny.status"
run_in "$T37" expect_ok "setup after distant edits" "$PROJENY" setup w.projeny
if cmp -s "$T37/w/n.txt" "$ROOT/t37-expect-n.txt"; then
    ok "distant-edit file identical after re-setup"
else
    fail "distant-edit file identical after re-setup"
fi

# ----------------------------------------- 38. new executable file keeps +x
T38="$ROOT/t38"
mkdir -p "$T38/w-1.0"
printf 'base\n' > "$T38/w-1.0/b.c"
(cd "$T38" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    New exec.\n' > "$T38/w.projeny"
(cd "$T38" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf '#!/bin/sh\necho new\n' > "$T38/w/tool.sh"
chmod 755 "$T38/w/tool.sh"
run_in "$T38" expect_ok "add executable file" "$PROJENY" add w.projeny w/tool.sh
run_in "$T38" expect_ok "commit executable file" "$PROJENY" commit w.projeny
expect_file_contains "new exec stores mode" "$T38/w.projeny" "new file mode 100755"
rm -rf "$T38/w" "$T38/w.projeny.status"
run_in "$T38" expect_ok "setup after new-exec commit" "$PROJENY" setup w.projeny
if [ -x "$T38/w/tool.sh" ]; then
    ok "new executable file keeps +x after re-setup"
else
    fail "new executable file keeps +x after re-setup" "$(ls -l "$T38/w/tool.sh" 2>&1)"
fi
expect_file_contains "new exec content correct" "$T38/w/tool.sh" "echo new"

# ----------------------------------------- 39. extra headers survive commit
T39="$ROOT/t39"
make_tarballs "$T39" fake
write_projeny "$T39" fake 1.0 fake
python3 - "$T39/fake.projeny" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("Name: fake\n", "Name: fake\nX-Custom: yes\n")
open(p, "w").write(s)
EOF
(cd "$T39" && "$PROJENY" setup fake.projeny >/dev/null 2>&1)
python3 - "$T39/fake/src/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("int alpha = 1;", "int alpha = 31337;")
open(p, "w").write(s)
EOF
run_in "$T39" expect_ok "commit with extra header" "$PROJENY" commit fake.projeny
expect_file_contains "extra header preserved" "$T39/fake.projeny" "X-Custom: yes"
expect_file_contains "extra-header commit stores diff" "$T39/fake.projeny" "31337"

# ----------------------------------------- 40. quoting in filenames roundtrip
T40="$ROOT/t40"
mkdir -p "$T40/w-1.0"
printf 'base\n' > "$T40/w-1.0/base.c"
(cd "$T40" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Quoting.\n' > "$T40/w.projeny"
(cd "$T40" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'quoted\n' > "$T40/w/say \"hi\".c"
printf 'tabbed\n' > "$T40/w/with	tab.c"
cp "$T40/w/say \"hi\".c" "$ROOT/t40-expect-quote.c"
cp "$T40/w/with	tab.c" "$ROOT/t40-expect-tab.c"
run_in "$T40" expect_ok "add quoted-name file" "$PROJENY" add w.projeny 'w/say "hi".c'
run_in "$T40" expect_ok "add tab-name file" "$PROJENY" add w.projeny 'w/with	tab.c'
run_in "$T40" expect_ok "commit quoted names" "$PROJENY" commit w.projeny
rm -rf "$T40/w" "$T40/w.projeny.status"
run_in "$T40" expect_ok "setup after quoted commit" "$PROJENY" setup w.projeny
if cmp -s "$T40/w/say \"hi\".c" "$ROOT/t40-expect-quote.c"; then
    ok "quoted-name file identical after re-setup"
else
    fail "quoted-name file identical after re-setup" "ls: $(ls "$T40/w" 2>&1)"
fi
if cmp -s "$T40/w/with	tab.c" "$ROOT/t40-expect-tab.c"; then
    ok "tab-name file identical after re-setup"
else
    fail "tab-name file identical after re-setup" "ls: $(ls "$T40/w" 2>&1)"
fi

# ----------------------------------------- 41. long single-line file
T41="$ROOT/t41"
mkdir -p "$T41/w-1.0"
python3 -c "open('$T41/w-1.0/long.txt','w').write('A'*100000 + '\n')"
(cd "$T41" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Long line.\n' > "$T41/w.projeny"
(cd "$T41" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 -c "open('$T41/w/long.txt','w').write('B'*100000 + '\n')"
run_in "$T41" expect_ok "long-line commit" "$PROJENY" commit w.projeny
cp "$T41/w/long.txt" "$ROOT/t41-expect-long.txt"
rm -rf "$T41/w" "$T41/w.projeny.status"
run_in "$T41" expect_ok "setup after long-line commit" "$PROJENY" setup w.projeny
if cmp -s "$T41/w/long.txt" "$ROOT/t41-expect-long.txt"; then
    ok "long single-line file identical after re-setup"
else
    fail "long single-line file identical after re-setup"
fi

# ----------------------------------------- 42. tabs and trailing tabs roundtrip
T42="$ROOT/t42"
mkdir -p "$T42/w-1.0"
printf 'a\n' > "$T42/w-1.0/t.c"
(cd "$T42" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Tabs.\n' > "$T42/w.projeny"
(cd "$T42" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf '\tindented\nmid\tdle\ntrailing\t\n' > "$T42/w/tabs.c"
run_in "$T42" expect_ok "add tab-content file" "$PROJENY" add w.projeny w/tabs.c
run_in "$T42" expect_ok "commit tab-content file" "$PROJENY" commit w.projeny
cp "$T42/w/tabs.c" "$ROOT/t42-expect-tabs.c"
rm -rf "$T42/w" "$T42/w.projeny.status"
run_in "$T42" expect_ok "setup after tab commit" "$PROJENY" setup w.projeny
if cmp -s "$T42/w/tabs.c" "$ROOT/t42-expect-tabs.c"; then
    ok "tab-content file byte-identical after re-setup"
else
    fail "tab-content file byte-identical after re-setup" "got: $(cat -A "$T42/w/tabs.c" 2>&1)"
fi

# ----------------------------------------- 43. dual-parser unification

# Combined, p0 and mode-only patches must not diverge into OOB/wrong names:

# a combined diff is a precise per-file failure (not silent success).

T43="$ROOT/t43"

mkdir -p "$T43/w-1.0"

printf 'hello\n' > "$T43/w-1.0/f.c"

(cd "$T43" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Dual parser.\n' > "$T43/w.projeny"

cat >> "$T43/w.projeny" <<'EOF'
diff --git a/w/f.c b/w/f.c
--- a/w/f.c
+++ b/w/f.c
@@ -1,1 +1,1 @@
-hello
+hello patched
diff --cc f.c
index 1111111,2222222..0000000
--- a/f.c
+++ b/f.c
@@@ -1,1 -1,1 +1,1 @@@
-hello
 -hello2
++hello patched
EOF

out="$(cd "$T43" && "$PROJENY" setup w.projeny 2>&1)"

rc=$?

if [ $rc -ne 0 ]; then

    ok "combined block fails cleanly (no OOB/silent success)"

else

    fail "combined block fails cleanly (no OOB/silent success)" "exited 0"

fi

case "$out" in

*f.c*)

    ok "combined failure names the file precisely"

    ;;

*)

    fail "combined failure names the file precisely" "out: $out"

    ;;

esac

# p0 hand-written form (no a/b prefixes on ---/+++) still applies.

T43B="$ROOT/t43b"

mkdir -p "$T43B/w-1.0"

printf 'hello v1\n' > "$T43B/w-1.0/README"

(cd "$T43B" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

cat > "$T43B/h.projeny" <<'EOF'
Archive: w-1.0.tar.gz
Origname: w-1.0
Name: h

    Hand-written p0.

diff --git a/h/README b/h/README
--- README
+++ README
@@ -1,1 +1,1 @@
-hello v1
+hello HAND
EOF

run_in "$T43B" expect_ok "p0 patch setup succeeds" "$PROJENY" setup h.projeny

expect_file_contains "p0 patch applies content" "$T43B/h/README" "hello HAND"

# Mode-only patch (no ---/+++/hunks) applies and sets the bit.

T43C="$ROOT/t43c"

mkdir -p "$T43C/w-1.0"

printf 'code\n' > "$T43C/w-1.0/f.c"

(cd "$T43C" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Mode only.\n' > "$T43C/w.projeny"

cat >> "$T43C/w.projeny" <<'EOF'

diff --git a/w/f.c b/w/f.c

old mode 100644

new mode 100755

EOF

run_in "$T43C" expect_ok "mode-only patch setup succeeds" "$PROJENY" setup w.projeny

if [ -x "$T43C/w/f.c" ]; then

    ok "mode-only patch sets +x"

else

    fail "mode-only patch sets +x" "$(ls -l "$T43C/w/f.c" 2>&1)"

fi

# ----------------------------------------- 44. pure-rename lineage

# Same-content destination is idempotent success; different content fails

# without overwriting.

T44="$ROOT/t44"

mkdir -p "$T44/w-1.0"

printf 'same\n' > "$T44/w-1.0/old.txt"

printf 'same\n' > "$T44/w-1.0/new.txt"

(cd "$T44" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Rename.\n' > "$T44/w.projeny"

cat >> "$T44/w.projeny" <<'EOF'

diff --git a/w/old.txt b/w/new.txt

similarity index 100%

rename from old.txt

rename to new.txt

EOF

run_in "$T44" expect_ok "pure-rename same-content dest succeeds" "$PROJENY" setup w.projeny

if [ -f "$T44/w/new.txt" ]; then

    ok "pure-rename same-content keeps dest"

else

    fail "pure-rename same-content keeps dest" "ls: $(ls "$T44/w" 2>&1)"

fi

if grep -q "same" "$T44/w/new.txt"; then

    ok "pure-rename same-content dest bytes intact"

else

    fail "pure-rename same-content dest bytes intact"

fi

T44B="$ROOT/t44b"

mkdir -p "$T44B/w-1.0"

printf 'same\n' > "$T44B/w-1.0/old.txt"

printf 'DIFFERENT\n' > "$T44B/w-1.0/new.txt"

(cd "$T44B" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Rename.\n' > "$T44B/w.projeny"

cat >> "$T44B/w.projeny" <<'EOF'

diff --git a/w/old.txt b/w/new.txt

similarity index 100%

rename from old.txt

rename to new.txt

EOF

run_in "$T44B" expect_fail "pure-rename different-content dest fails" "$PROJENY" setup w.projeny

# ----------------------------------------- 45. Already enforces mode/newline

# New-file Already with correct content but wrong +x must repair the bit on

# rebase onto a base that already contains the file.

T45="$ROOT/t45"

mkdir -p "$T45/w-1.0"

printf 'hello\n' > "$T45/w-1.0/f.c"

(cd "$T45" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Already mode.\n' > "$T45/w.projeny"

(cd "$T45" && "$PROJENY" setup w.projeny >/dev/null 2>&1)

printf 'hello new\n' > "$T45/w/newfile.c"

chmod 755 "$T45/w/newfile.c"

(cd "$T45" && "$PROJENY" add w.projeny w/newfile.c >/dev/null 2>&1)

(cd "$T45" && "$PROJENY" commit w.projeny >/dev/null 2>&1)

mkdir -p "$T45/w-2.0"

printf 'hello\n' > "$T45/w-2.0/f.c"

printf 'hello new\n' > "$T45/w-2.0/newfile.c"

chmod 644 "$T45/w-2.0/newfile.c"

(cd "$T45" && tar -czf w-2.0.tar.gz w-2.0 && rm -rf w-2.0)

run_in "$T45" expect_ok "rebase onto drifted new-file mode" "$PROJENY" rebase w.projeny w-2.0.tar.gz

if [ -x "$T45/w/newfile.c" ]; then

    ok "Already new-file repairs +x"

else

    fail "Already new-file repairs +x" "$(ls -l "$T45/w/newfile.c" 2>&1)"

fi

# Modify Already with correct lines but wrong +x and missing newline must

# repair both on rebase.

T45B="$ROOT/t45b"

mkdir -p "$T45B/w-1.0"

printf 'line1\nline2\nline3\n' > "$T45B/w-1.0/f.c"

(cd "$T45B" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Already mod.\n' > "$T45B/w.projeny"

(cd "$T45B" && "$PROJENY" setup w.projeny >/dev/null 2>&1)

printf 'line1\nLINE2\nline3\n' > "$T45B/w/f.c"

chmod 755 "$T45B/w/f.c"

(cd "$T45B" && "$PROJENY" commit w.projeny >/dev/null 2>&1)

mkdir -p "$T45B/w-2.0"

printf 'line1\nLINE2\nline3' > "$T45B/w-2.0/f.c"

chmod 755 "$T45B/w-2.0/f.c"

(cd "$T45B" && tar -czf w-2.0.tar.gz w-2.0 && rm -rf w-2.0)

run_in "$T45B" expect_ok "rebase onto drifted newline" "$PROJENY" rebase w.projeny w-2.0.tar.gz

printf 'line1\nLINE2\nline3\n' > "$ROOT/t45b-expect.c"

if cmp -s "$T45B/w/f.c" "$ROOT/t45b-expect.c"; then

    ok "Already modify repairs trailing newline"

else

    fail "Already modify repairs trailing newline" "got: $(xxd "$T45B/w/f.c" 2>&1)"

fi

# Independent fixture for the +x drift (same patch shape, fresh base).

T45C="$ROOT/t45c"

mkdir -p "$T45C/w-1.0"

printf 'line1\nline2\nline3\n' > "$T45C/w-1.0/f.c"

(cd "$T45C" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Already mod.\n' > "$T45C/w.projeny"

(cd "$T45C" && "$PROJENY" setup w.projeny >/dev/null 2>&1)

printf 'line1\nLINE2\nline3\n' > "$T45C/w/f.c"

chmod 755 "$T45C/w/f.c"

(cd "$T45C" && "$PROJENY" commit w.projeny >/dev/null 2>&1)

mkdir -p "$T45C/w-2.0"

printf 'line1\nLINE2\nline3\n' > "$T45C/w-2.0/f.c"

chmod 644 "$T45C/w-2.0/f.c"

(cd "$T45C" && tar -czf w-2.0.tar.gz w-2.0 && rm -rf w-2.0)

run_in "$T45C" expect_ok "rebase onto drifted mode bit" "$PROJENY" rebase w.projeny w-2.0.tar.gz

if [ -x "$T45C/w/f.c" ]; then

    ok "Already modify repairs +x"

else

    fail "Already modify repairs +x" "$(ls -l "$T45C/w/f.c" 2>&1)"

fi

# ----------------------------------------- 46. patch symlink escape

# Patch symlinks with absolute or .. targets must hard-error like tar.

T46="$ROOT/t46"

mkdir -p "$T46/w-1.0"

printf 'hello\n' > "$T46/w-1.0/f.c"

(cd "$T46" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Link escape.\n' > "$T46/w.projeny"

cat >> "$T46/w.projeny" <<'EOF'

diff --git a/w/evil b/w/evil

new file mode 120000

--- /dev/null

+++ b/w/evil

@@ -0,0 +1,1 @@

+/etc/passwd

\ No newline at end of file

EOF

run_in "$T46" expect_fail "patch absolute symlink target hard-errors" "$PROJENY" setup w.projeny

T46B="$ROOT/t46b"

mkdir -p "$T46B/w-1.0"

printf 'hello\n' > "$T46B/w-1.0/f.c"

(cd "$T46B" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)

printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Link escape.\n' > "$T46B/w.projeny"

cat >> "$T46B/w.projeny" <<'EOF'

diff --git a/w/evil b/w/evil

new file mode 120000

--- /dev/null

+++ b/w/evil

@@ -0,0 +1,1 @@

+../escape

\ No newline at end of file

EOF

run_in "$T46B" expect_fail "patch dotdot symlink target hard-errors" "$PROJENY" setup w.projeny

# ----------------------------------------- 47. opaque combined merge/rebase

# Opaque blocks (diff --cc with no parseable per-file path would silently
# drop the failed block: touched stays empty, no conflict, success). A
# failure must never be a no-op: merge and rebase with a combined diff must
# fail visibly, not succeed silently.

T47="$ROOT/t47"
mkdir -p "$T47/w-1.0"
printf 'hello\n' > "$T47/w-1.0/f.c"
(cd "$T47" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Base.\n' > "$T47/w.projeny"
(cd "$T47" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'hello local\n' > "$T47/w/f.c"
cat > "$T47/up.projeny" <<'EOF'
Archive: w-1.0.tar.gz
Origname: w-1.0
Name: w

    Upstream with combined.
diff --cc f.c
index 1111111,2222222..0000000
--- a/f.c
+++ b/f.c
@@@ -1,1 -1,1 +1,1 @@@
-hello
 -hello2
++hello upstream
EOF
cp "$T47/up.projeny" "$T47/w.projeny"
run_in "$T47" expect_fail "merge with combined diff fails (not silent)" "$PROJENY" setup w.projeny
out="$(cd "$T47" && "$PROJENY" setup w.projeny 2>&1 || true)"
case "$out" in
*f.c*|*combined*|*unsupported*|*cannot*|*does*apply*)
    ok "merge opaque failure is visible (names block)"
    ;;
*)
    fail "merge opaque failure is visible (names block)" "out: $out"
    ;;
esac

T48="$ROOT/t48"
mkdir -p "$T48/w-1.0"
printf 'hello\n' > "$T48/w-1.0/f.c"
(cd "$T48" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Base.\n' > "$T48/w.projeny"
cat >> "$T48/w.projeny" <<'EOF'
diff --cc f.c
index 1111111,2222222..0000000
--- a/f.c
+++ b/f.c
@@@ -1,1 -1,1 +1,1 @@@
-hello
 -hello2
++hello upstream
EOF
mkdir -p "$T48/w-2.0"
printf 'hello v2\n' > "$T48/w-2.0/f.c"
(cd "$T48" && tar -czf w-2.0.tar.gz w-2.0 && rm -rf w-2.0)
run_in "$T48" expect_fail "rebase with combined diff fails (not silent)" "$PROJENY" rebase w.projeny w-2.0.tar.gz

# ----------------------------------------- 48. symlink merge: link vs link

# Links must be compared by target string, never by dereferenced bytes.
# Same bytes via different targets is a mismatch and must conflict.

T49="$ROOT/t49"
mkdir -p "$T49/w-1.0"
printf 'same content\n' > "$T49/w-1.0/a.txt"
printf 'same content\n' > "$T49/w-1.0/b.txt"
printf 'same content\n' > "$T49/w-1.0/c.txt"
printf 'base\n' > "$T49/w-1.0/f.c"
ln -s a.txt "$T49/w-1.0/lnk"
(cd "$T49" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Base.\n' > "$T49/w.projeny"
(cd "$T49" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
ln -sf c.txt "$T49/w/lnk"
(cd "$T49" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$T49/w.projeny" "$ROOT/t49-upstream.projeny"
cat > "$T49/w.projeny" <<'EOF'
Archive: w-1.0.tar.gz
Origname: w-1.0
Name: w

    Base.
EOF
rm -rf "$T49/w" "$T49/w.projeny.status"
(cd "$T49" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
ln -sf b.txt "$T49/w/lnk"
cp "$ROOT/t49-upstream.projeny" "$T49/w.projeny"
run_in "$T49" expect_ok "symlink-vs-symlink divergent merge exits 0 (with conflict)" "$PROJENY" setup w.projeny
expect_file_contains "symlink target mismatch conflicts" "$T49/w.projeny.status" "Conflict: lnk"
expect_file_contains "symlink conflict leaves markers" "$T49/w/lnk" "<<<<<<<"
if [ -L "$T49/w/lnk" ]; then
    fail "symlink conflict is regular markers file, not link" "$(ls -l "$T49/w/lnk" 2>&1)"
else
    ok "symlink conflict is regular markers file, not link"
fi

# ----------------------------------------- 49. symlink merge: link vs file

# Link vs regular file is always a mismatch, even when dereferenced bytes
# are identical.

T50="$ROOT/t50"
mkdir -p "$T50/w-1.0"
printf 'hello\n' > "$T50/w-1.0/f.c"
printf 'hello\n' > "$T50/w-1.0/other.txt"
(cd "$T50" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Base.\n' > "$T50/w.projeny"
(cd "$T50" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'hello upstream\n' > "$T50/w/f.c"
(cd "$T50" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$T50/w.projeny" "$ROOT/t50-upstream.projeny"
cat > "$T50/w.projeny" <<'EOF'
Archive: w-1.0.tar.gz
Origname: w-1.0
Name: w

    Base.
EOF
rm -rf "$T50/w" "$T50/w.projeny.status"
(cd "$T50" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
rm "$T50/w/f.c"
ln -s other.txt "$T50/w/f.c"
cp "$ROOT/t50-upstream.projeny" "$T50/w.projeny"
run_in "$T50" expect_ok "symlink-vs-file divergent merge exits 0 (with conflict)" "$PROJENY" setup w.projeny
expect_file_contains "symlink-vs-file records conflict" "$T50/w.projeny.status" "Conflict: f.c"
expect_file_contains "symlink-vs-file leaves markers" "$T50/w/f.c" "<<<<<<<"

# ----------------------------------------- 50. symlink merge: escape rejected

# Any link placed via merge is validated like patch/tar links: absolute and
# .. targets are rejected, never created.

T51="$ROOT/t51"
mkdir -p "$T51/w-1.0"
printf 'hello\n' > "$T51/w-1.0/f.c"
printf 'other\n' > "$T51/w-1.0/g.c"
(cd "$T51" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Base.\n' > "$T51/w.projeny"
(cd "$T51" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'other upstream\n' > "$T51/w/g.c"
(cd "$T51" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$T51/w.projeny" "$ROOT/t51-upstream.projeny"
cat > "$T51/w.projeny" <<'EOF'
Archive: w-1.0.tar.gz
Origname: w-1.0
Name: w

    Base.
EOF
rm -rf "$T51/w" "$T51/w.projeny.status"
(cd "$T51" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
rm "$T51/w/f.c"
ln -s /etc/passwd "$T51/w/f.c"
cp "$ROOT/t51-upstream.projeny" "$T51/w.projeny"
out="$(cd "$T51" && "$PROJENY" setup w.projeny 2>&1)"; rc=$?
if [ $rc -ne 0 ]; then
    ok "malicious absolute link via merge rejected (dies)"
else
    if [ -L "$T51/w/f.c" ] && [ "$(readlink "$T51/w/f.c")" = "/etc/passwd" ]; then
        fail "malicious absolute link via merge rejected (not created)" "link was created"
    else
        ok "malicious absolute link via merge rejected (conflict, not created)"
    fi
fi
if [ -L "$T51/w/f.c" ] && [ "$(readlink "$T51/w/f.c" 2>/dev/null)" = "/etc/passwd" ] && [ $rc -eq 0 ]; then
    fail "absolute link not planted on success path" "$(ls -l "$T51/w/f.c" 2>&1)"
else
    ok "absolute link not planted"
fi
case "$out" in
*escape*|*refus*|*cannot*|*Conflict*|*conflict*)
    ok "malicious merge failure is visible"
    ;;
*)
    if [ $rc -ne 0 ]; then
        ok "malicious merge failure is visible"
    else
        fail "malicious merge failure is visible" "out: $out"
    fi
    ;;
esac

T52="$ROOT/t52"
mkdir -p "$T52/w-1.0"
printf 'hello\n' > "$T52/w-1.0/f.c"
printf 'other\n' > "$T52/w-1.0/g.c"
(cd "$T52" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Base.\n' > "$T52/w.projeny"
(cd "$T52" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'other upstream\n' > "$T52/w/g.c"
(cd "$T52" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$T52/w.projeny" "$ROOT/t52-upstream.projeny"
cat > "$T52/w.projeny" <<'EOF'
Archive: w-1.0.tar.gz
Origname: w-1.0
Name: w

    Base.
EOF
rm -rf "$T52/w" "$T52/w.projeny.status"
(cd "$T52" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
rm "$T52/w/f.c"
ln -s ../escape "$T52/w/f.c"
cp "$ROOT/t52-upstream.projeny" "$T52/w.projeny"
out="$(cd "$T52" && "$PROJENY" setup w.projeny 2>&1)"; rc=$?
if [ $rc -ne 0 ]; then
    ok "malicious dotdot link via merge rejected (dies)"
else
    if [ -L "$T52/w/f.c" ] && [ "$(readlink "$T52/w/f.c")" = "../escape" ]; then
        fail "malicious dotdot link via merge rejected (not created)" "link was created"
    else
        ok "malicious dotdot link via merge rejected (conflict, not created)"
    fi
fi
if [ -L "$T52/w/f.c" ] && [ "$(readlink "$T52/w/f.c" 2>/dev/null)" = "../escape" ] && [ $rc -eq 0 ]; then
    fail "dotdot link not planted on success path" "$(ls -l "$T52/w/f.c" 2>&1)"
else
    ok "dotdot link not planted"
fi

# ----------------------------------------- 51. nasty filenames roundtrip
# Leading dashes, glob characters, trailing spaces and backslashes must not
# confuse the differ, the status file, or the applier.
T53="$ROOT/t53"
mkdir -p "$T53/w-1.0"
printf 'base\n' > "$T53/w-1.0/base.c"
(cd "$T53" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Nasty names.\n' > "$T53/w.projeny"
(cd "$T53" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'dash\n' > "$T53/w/-dash.c"
printf 'glob\n' > "$T53/w/star*.c"
printf 'q\n' > "$T53/w/what?.c"
printf 'trail\n' > "$T53/w/trailspace .c"
printf 'back\n' > "$T53/w/back\\slash.c"
run_in "$T53" expect_ok "add leading-dash file" "$PROJENY" add w.projeny "w/-dash.c"
run_in "$T53" expect_ok "add glob-char file" "$PROJENY" add w.projeny "w/star*.c"
run_in "$T53" expect_ok "add question-mark file" "$PROJENY" add w.projeny "w/what?.c"
run_in "$T53" expect_ok "add trailing-space file" "$PROJENY" add w.projeny "w/trailspace .c"
run_in "$T53" expect_ok "add backslash file" "$PROJENY" add w.projeny 'w/back\slash.c'
run_in "$T53" expect_ok "commit nasty names" "$PROJENY" commit w.projeny
run_in "$T53" expect_ok "setup after nasty commit" "$PROJENY" setup w.projeny
for n in "-dash.c" "star*.c" "what?.c" "trailspace .c" 'back\slash.c'; do
    if [ -f "$T53/w/$n" ]; then
        ok "nasty file '$n' survives re-setup"
    else
        fail "nasty file '$n' survives re-setup" "ls: $(ls "$T53/w" 2>&1)"
    fi
done
expect_file_contains "dash content intact" "$T53/w/-dash.c" "dash"
expect_file_contains "backslash content intact" "$T53/w/back\\slash.c" "back"

# ----------------------------------------- 52. unicode names and content
# UTF-8 filenames roundtrip byte-exact; non-ASCII content (including emoji)
# is plain text to projeny, not binary.
T54="$ROOT/t54"
mkdir -p "$T54/w-1.0"
printf 'base\n' > "$T54/w-1.0/base.c"
(cd "$T54" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Unicode.\n' > "$T54/w.projeny"
(cd "$T54" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$T54/w" <<'EOF'
import sys, os
d = sys.argv[1]
open(os.path.join(d, "caf\xc3\xa9-\u20ac.c"), "w").write("plain\n")
open(os.path.join(d, "emoji.c"), "w").write("smile \U0001F600\nsnow \u2603\n")
EOF
(cd "$T54" && ls w | LC_ALL=C sort > "$ROOT/t54-expect-ls.txt")
run_in "$T54" expect_ok "commit unicode names (no add needed)" "$PROJENY" commit w.projeny
rm -rf "$T54/w" "$T54/w.projeny.status"
run_in "$T54" expect_ok "setup after unicode commit" "$PROJENY" setup w.projeny
(cd "$T54" && ls w | LC_ALL=C sort > "$ROOT/t54-got-ls.txt")
if cmp -s "$ROOT/t54-expect-ls.txt" "$ROOT/t54-got-ls.txt"; then
    ok "unicode filenames byte-identical after re-setup"
else
    fail "unicode filenames byte-identical after re-setup" "got: $(cat "$ROOT/t54-got-ls.txt" 2>&1)"
fi
python3 - "$T54/w" <<'EOF'
import sys, os
d = sys.argv[1]
names = os.listdir(d)
assert any(n.startswith("caf") for n in names), names
data = open(os.path.join(d, "emoji.c"), encoding="utf-8").read()
assert "\U0001F600" in data and "\u2603" in data, repr(data)
EOF
if [ $? -eq 0 ]; then
    ok "unicode and emoji content intact after re-setup"
else
    fail "unicode and emoji content intact after re-setup"
fi

# ----------------------------------------- 53. newline in filename roundtrip
# The status escaper and the C-quoted diff labels must carry a raw newline.
T55="$ROOT/t55"
mkdir -p "$T55/w-1.0"
printf 'base\n' > "$T55/w-1.0/base.c"
(cd "$T55" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Newline name.\n' > "$T55/w.projeny"
(cd "$T55" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
NLFILE="w/new
line.c"
printf 'nlcontent\n' > "$T55/$NLFILE"
run_in "$T55" expect_ok "add newline-name file" "$PROJENY" add w.projeny "$NLFILE"
run_in "$T55" expect_ok "commit newline-name file" "$PROJENY" commit w.projeny
cp "$T55/$NLFILE" "$ROOT/t55-expect-nl.c"
rm -rf "$T55/w" "$T55/w.projeny.status"
run_in "$T55" expect_ok "setup after newline-name commit" "$PROJENY" setup w.projeny
if cmp -s "$T55/$NLFILE" "$ROOT/t55-expect-nl.c"; then
    ok "newline-name file byte-identical after re-setup"
else
    fail "newline-name file byte-identical after re-setup" "ls: $(ls "$T55/w" 2>&1)"
fi

# ----------------------------------------- 54. deep nesting roundtrip
T56="$ROOT/t56"
mkdir -p "$T56/w-1.0/a/b/c/d/e/f/g/h"
printf 'deep\n' > "$T56/w-1.0/a/b/c/d/e/f/g/h/deep.c"
(cd "$T56" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Deep.\n' > "$T56/w.projeny"
run_in "$T56" expect_ok "deep setup" "$PROJENY" setup w.projeny
printf 'deeper\n' >> "$T56/w/a/b/c/d/e/f/g/h/deep.c"
printf 'brand new\n' > "$T56/w/a/b/c/d/e/f/g/h/fresh.c"
run_in "$T56" expect_ok "add deeply nested file" "$PROJENY" add w.projeny w/a/b/c/d/e/f/g/h/fresh.c
run_in "$T56" expect_ok "commit deeply nested tree" "$PROJENY" commit w.projeny
cp "$T56/w/a/b/c/d/e/f/g/h/deep.c" "$ROOT/t56-expect-deep.c"
rm -rf "$T56/w" "$T56/w.projeny.status"
run_in "$T56" expect_ok "setup after deep commit" "$PROJENY" setup w.projeny
if cmp -s "$T56/w/a/b/c/d/e/f/g/h/deep.c" "$ROOT/t56-expect-deep.c"; then
    ok "deep file identical after re-setup"
else
    fail "deep file identical after re-setup"
fi
expect_file_contains "deep fresh file survives" "$T56/w/a/b/c/d/e/f/g/h/fresh.c" "brand new"

# ----------------------------------------- 55. many files at once
T57="$ROOT/t57"
mkdir -p "$T57/m-1.0"
for i in $(seq 1 60); do printf 'content %s\n' "$i" > "$T57/m-1.0/f$i.c"; done
(cd "$T57" && tar -czf m-1.0.tar.gz m-1.0 && rm -rf m-1.0)
printf 'Archive: m-1.0.tar.gz\nOrigname: m-1.0\nName: m\n\n    Many.\n' > "$T57/m.projeny"
run_in "$T57" expect_ok "many-file setup" "$PROJENY" setup m.projeny
for i in $(seq 1 60); do printf 'changed %s\n' "$i" > "$T57/m/f$i.c"; done
rm "$T57/m/f1.c" "$T57/m/f2.c"
printf 'extra\n' > "$T57/m/extra.c"
run_in "$T57" expect_ok "add among many files" "$PROJENY" add m.projeny m/extra.c
run_in "$T57" expect_ok "commit 60-file change" "$PROJENY" commit m.projeny
rm -rf "$T57/m" "$T57/m.projeny.status"
run_in "$T57" expect_ok "setup after many-file commit" "$PROJENY" setup m.projeny
expect_file_contains "many-file edit survives" "$T57/m/f60.c" "changed 60"
expect_file_contains "many-file extra survives" "$T57/m/extra.c" "extra"
if [ ! -e "$T57/m/f1.c" ] && [ ! -e "$T57/m/f2.c" ]; then
    ok "many-file deletions stay deleted"
else
    fail "many-file deletions stay deleted" "ls: $(ls "$T57/m" 2>&1)"
fi

# ----------------------------------------- 56. empty dirs are untracked
# Empty directories carry no files, so the differ ignores them: setup and
# commit must succeed and simply not track them.
T58="$ROOT/t58"
mkdir -p "$T58/w-1.0/emptydir/nested"
printf 'base\n' > "$T58/w-1.0/base.c"
(cd "$T58" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Empty dirs.\n' > "$T58/w.projeny"
run_in "$T58" expect_ok "setup with empty base dirs" "$PROJENY" setup w.projeny
mkdir -p "$T58/w/newempty/a/b"
run_in "$T58" expect_ok "commit with empty dirs present" "$PROJENY" commit w.projeny
if grep -q "^diff --git " "$T58/w.projeny"; then
    fail "empty dirs leave patch empty"
else
    ok "empty dirs leave patch empty"
fi
# ----------------------------------------- 57. mode-only changes both ways
# A chmod with no content edit stores an old/new-mode block; flipping the bit
# back empties the patch again. New files default to 0644.
T59="$ROOT/t59"
mkdir -p "$T59/w-1.0"
printf 'code\n' > "$T59/w-1.0/f.c"
printf 'plain\n' > "$T59/w-1.0/p.c"
(cd "$T59" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Modes.\n' > "$T59/w.projeny"
run_in "$T59" expect_ok "mode setup" "$PROJENY" setup w.projeny
chmod 755 "$T59/w/f.c"
run_in "$T59" expect_ok "mode-only commit" "$PROJENY" commit w.projeny
expect_file_contains "mode-only stores old mode" "$T59/w.projeny" "old mode 100644"
expect_file_contains "mode-only stores new mode" "$T59/w.projeny" "new mode 100755"
rm -rf "$T59/w" "$T59/w.projeny.status"
run_in "$T59" expect_ok "setup after mode-only commit" "$PROJENY" setup w.projeny
if [ -x "$T59/w/f.c" ] && [ ! -x "$T59/w/p.c" ]; then
    ok "mode-only bits exact after re-setup"
else
    fail "mode-only bits exact after re-setup" "$(ls -l "$T59/w" 2>&1)"
fi
chmod 644 "$T59/w/f.c"
run_in "$T59" expect_ok "mode flip-back commit" "$PROJENY" commit w.projeny
if grep -q "^diff --git " "$T59/w.projeny"; then
    fail "mode flip-back empties patch"
else
    ok "mode flip-back empties patch"
fi
printf 'fresh\n' > "$T59/w/fresh.c"
run_in "$T59" expect_ok "add fresh regular file" "$PROJENY" add w.projeny w/fresh.c
run_in "$T59" expect_ok "commit fresh regular file" "$PROJENY" commit w.projeny
rm -rf "$T59/w" "$T59/w.projeny.status"
run_in "$T59" expect_ok "setup after fresh commit" "$PROJENY" setup w.projeny
if [ ! -x "$T59/w/fresh.c" ]; then
    ok "new regular file defaults to non-exec"
else
    fail "new regular file defaults to non-exec" "$(ls -l "$T59/w/fresh.c" 2>&1)"
fi

# ----------------------------------------- 58. symlinks: dangling, loop, subdir
# Relative links that stay inside the tree roundtrip even when dangling or
# self-referential; links with ".." are refused like tar escapes.
T60="$ROOT/t60"
mkdir -p "$T60/w-1.0/sub"
printf 'base\n' > "$T60/w-1.0/base.c"
printf 'sub target\n' > "$T60/w-1.0/sub/t.txt"
(cd "$T60" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Links.\n' > "$T60/w.projeny"
run_in "$T60" expect_ok "link setup" "$PROJENY" setup w.projeny
ln -s nowhere "$T60/w/dangling"
ln -s self "$T60/w/self"
ln -s sub/t.txt "$T60/w/sublink"
run_in "$T60" expect_ok "commit dangling/loop/subdir links" "$PROJENY" commit w.projeny
expect_file_contains "dangling link stored" "$T60/w.projeny" "nowhere"
rm -rf "$T60/w" "$T60/w.projeny.status"
run_in "$T60" expect_ok "setup after link commit" "$PROJENY" setup w.projeny
if [ -L "$T60/w/dangling" ] && [ "$(readlink "$T60/w/dangling")" = "nowhere" ]; then
    ok "dangling link survives re-setup"
else
    fail "dangling link survives re-setup" "$(ls -l "$T60/w" 2>&1)"
fi
if [ -L "$T60/w/self" ] && [ "$(readlink "$T60/w/self")" = "self" ]; then
    ok "self-loop link survives re-setup"
else
    fail "self-loop link survives re-setup" "$(ls -l "$T60/w" 2>&1)"
fi
if [ -L "$T60/w/sublink" ] && [ "$(cat "$T60/w/sublink")" = "sub target" ]; then
    ok "subdir-relative link resolves after re-setup"
else
    fail "subdir-relative link resolves after re-setup" "$(ls -l "$T60/w" 2>&1)"
fi
ln -s ../escape "$T60/w/dotescape"
run_in "$T60" expect_fail "commit with dotdot link fails" "$PROJENY" commit w.projeny
rm -f "$T60/w/dotescape"
run_in "$T60" expect_ok "commit works after removing escape link" "$PROJENY" commit w.projeny

# ----------------------------------------- 59. symlink rename roundtrip
T61="$ROOT/t61"
mkdir -p "$T61/w-1.0"
printf 'target\n' > "$T61/w-1.0/r.txt"
ln -s r.txt "$T61/w-1.0/lnk"
(cd "$T61" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Link mv.\n' > "$T61/w.projeny"
run_in "$T61" expect_ok "link-mv setup" "$PROJENY" setup w.projeny
run_in "$T61" expect_ok "mv symlink" "$PROJENY" mv w.projeny w/lnk w/lnk2
run_in "$T61" expect_ok "commit symlink rename" "$PROJENY" commit w.projeny
rm -rf "$T61/w" "$T61/w.projeny.status"
run_in "$T61" expect_ok "setup after symlink rename" "$PROJENY" setup w.projeny
if [ -L "$T61/w/lnk2" ] && [ "$(readlink "$T61/w/lnk2")" = "r.txt" ] && [ ! -e "$T61/w/lnk" ]; then
    ok "renamed symlink survives re-setup"
else
    fail "renamed symlink survives re-setup" "$(ls -l "$T61/w" 2>&1)"
fi

# ----------------------------------------- 60. hardlinks flatten to regular files
T62="$ROOT/t62"
mkdir -p "$T62/w-1.0"
printf 'base\n' > "$T62/w-1.0/base.c"
(cd "$T62" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Hardlinks.\n' > "$T62/w.projeny"
run_in "$T62" expect_ok "hardlink setup" "$PROJENY" setup w.projeny
printf 'shared bytes\n' > "$T62/w/orig.txt"
ln "$T62/w/orig.txt" "$T62/w/twin.txt"
run_in "$T62" expect_ok "commit hardlinked pair" "$PROJENY" commit w.projeny
rm -rf "$T62/w" "$T62/w.projeny.status"
run_in "$T62" expect_ok "setup after hardlink commit" "$PROJENY" setup w.projeny
if cmp -s "$T62/w/orig.txt" "$T62/w/twin.txt"; then
    ok "hardlinked contents match after re-setup"
else
    fail "hardlinked contents match after re-setup"
fi

# ----------------------------------------- 61. FIFOs fail cleanly, never hang
T63="$ROOT/t63"
mkdir -p "$T63/w-1.0"
printf 'base\n' > "$T63/w-1.0/base.c"
(cd "$T63" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    FIFO.\n' > "$T63/w.projeny"
run_in "$T63" expect_ok "fifo setup" "$PROJENY" setup w.projeny
mkfifo "$T63/w/myfifo"
out="$(cd "$T63" && "$PROJENY" commit w.projeny 2>&1)"
rc=$?
if [ $rc -ne 0 ]; then
    ok "commit with FIFO fails (no hang)"
else
    fail "commit with FIFO fails (no hang)" "exited 0"
fi
case "$out" in
*unsupported*|*FIFO*|*fifo*|*file\ type*)
    ok "FIFO failure message is clear"
    ;;
*)
    fail "FIFO failure message is clear" "out: $out"
    ;;
esac
rm -f "$T63/w/myfifo"
run_in "$T63" expect_ok "commit works after removing FIFO" "$PROJENY" commit w.projeny

# ----------------------------------------- 62. mixed line endings roundtrip
T64="$ROOT/t64"
mkdir -p "$T64/w-1.0"
printf 'l1\nl2\nl3\n' > "$T64/w-1.0/m.txt"
(cd "$T64" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Mixed.\n' > "$T64/w.projeny"
run_in "$T64" expect_ok "mixed setup" "$PROJENY" setup w.projeny
printf 'l1\r\nl2\r\nl3\nl4\r\nmixed tail\n' > "$T64/w/m.txt"
run_in "$T64" expect_ok "mixed-endings commit" "$PROJENY" commit w.projeny
cp "$T64/w/m.txt" "$ROOT/t64-expect-m.txt"
rm -rf "$T64/w" "$T64/w.projeny.status"
run_in "$T64" expect_ok "setup after mixed commit" "$PROJENY" setup w.projeny
if cmp -s "$T64/w/m.txt" "$ROOT/t64-expect-m.txt"; then
    ok "mixed-endings file byte-identical after re-setup"
else
    fail "mixed-endings file byte-identical after re-setup" "got: $(xxd "$T64/w/m.txt" 2>&1)"
fi
# ----------------------------------------- 63. binary base is inert until touched
# A NUL-bearing file inside the base tarball sets up fine; any commit that
# must read it (even a pure delete) refuses with a clear message.
T65="$ROOT/t65"
mkdir -p "$T65/b-1.0"
python3 -c "open('$T65/b-1.0/b.dat','wb').write(b'a\x00b\n')"
printf 'ok\n' > "$T65/b-1.0/f.c"
(cd "$T65" && tar -czf b-1.0.tar.gz b-1.0 && rm -rf b-1.0)
printf 'Archive: b-1.0.tar.gz\nOrigname: b-1.0\nName: b\n\n    Binary base.\n' > "$T65/b.projeny"
run_in "$T65" expect_ok "setup with binary base file" "$PROJENY" setup b.projeny
out="$(cd "$T65" && "$PROJENY" commit b.projeny 2>&1)"
rc=$?
if [ $rc -ne 0 ]; then
    ok "commit touching binary base fails"
else
    fail "commit touching binary base fails" "exited 0"
fi
case "$out" in
*inary*)
    ok "binary-base failure message is clear"
    ;;
*)
    fail "binary-base failure message is clear" "out: $out"
    ;;
esac
run_in "$T65" expect_ok "rm binary file" "$PROJENY" rm b.projeny b/b.dat
run_in "$T65" expect_fail "commit deleting binary still refused" "$PROJENY" commit b.projeny

# ----------------------------------------- 64. delete + recreate same path
T66="$ROOT/t66"
mkdir -p "$T66/w-1.0"
printf 'v1\n' > "$T66/w-1.0/f.c"
(cd "$T66" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Recreate.\n' > "$T66/w.projeny"
run_in "$T66" expect_ok "recreate setup" "$PROJENY" setup w.projeny
run_in "$T66" expect_ok "rm for recreate" "$PROJENY" rm w.projeny w/f.c
printf 'v2 brand new\n' > "$T66/w/f.c"
run_in "$T66" expect_ok "add recreated file" "$PROJENY" add w.projeny w/f.c
run_in "$T66" expect_ok "commit delete+recreate" "$PROJENY" commit w.projeny
rm -rf "$T66/w" "$T66/w.projeny.status"
run_in "$T66" expect_ok "setup after delete+recreate" "$PROJENY" setup w.projeny
expect_file_contains "recreated content survives" "$T66/w/f.c" "v2 brand new"

# ----------------------------------------- 65. chained mv collapses
T67="$ROOT/t67"
mkdir -p "$T67/w-1.0"
seq 1 20 > "$T67/w-1.0/n.txt"
(cd "$T67" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Chain.\n' > "$T67/w.projeny"
run_in "$T67" expect_ok "chain setup" "$PROJENY" setup w.projeny
run_in "$T67" expect_ok "mv chain step one" "$PROJENY" mv w.projeny w/n.txt w/m1.txt
run_in "$T67" expect_ok "mv chain step two" "$PROJENY" mv w.projeny w/m1.txt w/m2.txt
expect_file_contains "chained rename recorded once" "$T67/w.projeny.status" "Renamed: n.txt -> m2.txt"
run_in "$T67" expect_ok "commit chained rename" "$PROJENY" commit w.projeny
rm -rf "$T67/w" "$T67/w.projeny.status"
run_in "$T67" expect_ok "setup after chained rename" "$PROJENY" setup w.projeny
if [ -f "$T67/w/m2.txt" ] && [ ! -e "$T67/w/n.txt" ] && [ ! -e "$T67/w/m1.txt" ]; then
    ok "chained rename paths exact after re-setup"
else
    fail "chained rename paths exact after re-setup" "ls: $(ls "$T67/w" 2>&1)"
fi
run_in "$T67" expect_ok "mv cycle step one" "$PROJENY" mv w.projeny w/m2.txt w/tmp.txt
run_in "$T67" expect_ok "mv cycle step two (back)" "$PROJENY" mv w.projeny w/tmp.txt w/m2.txt
if grep -q "^Renamed:" "$T67/w.projeny.status"; then
    fail "mv cycle collapses pending rename" "$(cat "$T67/w.projeny.status")"
else
    ok "mv cycle collapses pending rename"
fi

# ----------------------------------------- 66. add/rm whole directory
T68="$ROOT/t68"
mkdir -p "$T68/w-1.0"
printf 'base\n' > "$T68/w-1.0/base.c"
(cd "$T68" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Dirs.\n' > "$T68/w.projeny"
run_in "$T68" expect_ok "dir setup" "$PROJENY" setup w.projeny
mkdir -p "$T68/w/newdir"
printf 'one\n' > "$T68/w/newdir/one.c"
printf 'two\n' > "$T68/w/newdir/two.c"
run_in "$T68" expect_ok "add file under new dir" "$PROJENY" add w.projeny w/newdir/one.c
run_in "$T68" expect_ok "commit new dir content" "$PROJENY" commit w.projeny
expect_file_contains "newdir file committed" "$T68/w.projeny" "two"
rm -rf "$T68/w" "$T68/w.projeny.status"
run_in "$T68" expect_ok "setup after dir add" "$PROJENY" setup w.projeny
expect_file_contains "dir add file one survives" "$T68/w/newdir/one.c" "one"
expect_file_contains "dir add file two survives" "$T68/w/newdir/two.c" "two"
run_in "$T68" expect_ok "rm whole directory" "$PROJENY" rm w.projeny w/newdir
run_in "$T68" expect_ok "commit dir removal" "$PROJENY" commit w.projeny
rm -rf "$T68/w" "$T68/w.projeny.status"
run_in "$T68" expect_ok "setup after dir removal" "$PROJENY" setup w.projeny
if [ ! -e "$T68/w/newdir" ]; then
    ok "removed directory stays gone"
else
    fail "removed directory stays gone" "ls: $(ls -R "$T68/w" 2>&1)"
fi

# ----------------------------------------- 67. CLI arity and missing inputs
T69="$ROOT/t69"
mkdir -p "$T69/w-1.0"
printf 'a\n' > "$T69/w-1.0/f.c"
(cd "$T69" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    CLI.\n' > "$T69/w.projeny"
run_in "$T69" expect_fail "bare projeny fails" "$PROJENY"
run_in "$T69" expect_fail "setup with extra args fails" "$PROJENY" setup a b c
run_in "$T69" expect_fail "commit with extra args fails" "$PROJENY" commit a b
run_in "$T69" expect_fail "setup of missing projeny fails" "$PROJENY" setup "$T69/never.projeny"
run_in "$T69" expect_fail "rebase with missing tarball fails" "$PROJENY" rebase w.projeny "$T69/never.tar.gz"
(cd "$T69" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
run_in "$T69" expect_fail "add with too many args fails" "$PROJENY" add w.projeny w/f.c extra
run_in "$T69" expect_fail "resolve of unknown path fails" "$PROJENY" resolve w.projeny w/f.c
run_in "$T69" expect_ok "status shows pending add" "$PROJENY" add w.projeny w/f.c
run_in "$T69" expect_ok "status prints pending state" "$PROJENY" status w.projeny
out="$(cd "$T69" && "$PROJENY" status w.projeny 2>&1)"
case "$out" in
*Added:\ f.c*)
    ok "status lists pending add"
    ;;
*)
    fail "status lists pending add" "out: $out"
    ;;
esac
# ----------------------------------------- 68. corrupt inputs fail loudly
T70="$ROOT/t70"
mkdir -p "$T70/w-1.0"
printf 'v1\n' > "$T70/w-1.0/f.c"
(cd "$T70" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T70/w.projeny"
printf 'No headers here\njust text\n' > "$T70/bad1.projeny"
run_in "$T70" expect_fail "headerless projeny fails" "$PROJENY" setup bad1.projeny
printf 'Archive: sub/dir.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T70/bad2.projeny"
run_in "$T70" expect_fail "slashed Archive fails" "$PROJENY" setup bad2.projeny
printf 'Archive: w-1.0.tar.gz\nOrigname: a/b\nName: w\n\n    T.\n' > "$T70/bad3.projeny"
run_in "$T70" expect_fail "slashed Origname fails" "$PROJENY" setup bad3.projeny
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: ..\n\n    T.\n' > "$T70/bad4.projeny"
run_in "$T70" expect_fail "dotdot Name fails" "$PROJENY" setup bad4.projeny
run_in "$T70" expect_ok "good setup for status corruption" "$PROJENY" setup w.projeny
printf 'Garbage line\n' > "$T70/w.projeny.status"
run_in "$T70" expect_fail "garbage status line fails" "$PROJENY" setup w.projeny
printf 'Status: setup\nRenamed: broken-no-arrow\n' > "$T70/w.projeny.status"
run_in "$T70" expect_fail "malformed Renamed line fails" "$PROJENY" setup w.projeny
printf 'Conflict: f.c\n' > "$T70/w.projeny.status"
run_in "$T70" expect_fail "status without Status line fails" "$PROJENY" setup w.projeny

# ----------------------------------------- 69. tarball edge cases
T71="$ROOT/t71"
mkdir -p "$T71/real-9.9"
printf 'x\n' > "$T71/real-9.9/f.c"
(cd "$T71" && tar -czf real-9.9.tar.gz real-9.9 && rm -rf real-9.9)
printf 'Archive: real-9.9.tar.gz\nOrigname: wrong-top\nName: w\n\n    T.\n' > "$T71/o.projeny"
run_in "$T71" expect_fail "Origname mismatch fails" "$PROJENY" setup o.projeny
printf 'Archive: missing.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T71/m.projeny"
run_in "$T71" expect_fail "missing tarball fails" "$PROJENY" setup m.projeny
printf 'Archive: real-9.9.tar.gz\nOrigname: real-9.9\nName: w\n\n    T.\n' > "$T71/w.projeny"
run_in "$T71" expect_ok "Name differing from Origname works" "$PROJENY" setup w.projeny
expect_file_contains "renamed top unpacks content" "$T71/w/f.c" "x"
mkdir -p "$T71/dot-1.0"
printf 'y\n' > "$T71/dot-1.0/g.c"
(cd "$T71" && tar -czf dot.tar.gz -C . ./dot-1.0)
printf 'Archive: dot.tar.gz\nOrigname: dot-1.0\nName: d\n\n    T.\n' > "$T71/d.projeny"
run_in "$T71" expect_ok "dot-prefixed members unpack" "$PROJENY" setup d.projeny
expect_file_contains "dot-prefixed content intact" "$T71/d/g.c" "y"
mkdir -p "$T71/empty-1.0"
(cd "$T71" && tar -czf empty.tar.gz empty-1.0 && rm -rf empty-1.0)
printf 'Archive: empty.tar.gz\nOrigname: empty-1.0\nName: e\n\n    T.\n' > "$T71/e.projeny"
run_in "$T71" expect_ok "empty top dir sets up" "$PROJENY" setup e.projeny
run_in "$T71" expect_ok "empty top dir commits" "$PROJENY" commit e.projeny
if command -v python3 >/dev/null 2>&1; then
    (cd "$T71" && python3 - <<'PYEOF'
import tarfile, io
with tarfile.open("abs.tar.gz", "w") as t:
    d = tarfile.TarInfo("top"); d.type = tarfile.DIRTYPE; t.addfile(d)
    f = tarfile.TarInfo("/absmember"); f.size = 2; t.addfile(f, io.BytesIO(b"x\n"))
with tarfile.open("dotdot.tar.gz", "w") as t:
    d = tarfile.TarInfo("top"); d.type = tarfile.DIRTYPE; t.addfile(d)
    f = tarfile.TarInfo("top/../../evil"); f.size = 2; t.addfile(f, io.BytesIO(b"x\n"))
PYEOF
    )
    printf 'Archive: abs.tar.gz\nOrigname: top\nName: a\n\n    T.\n' > "$T71/a.projeny"
    run_in "$T71" expect_fail "absolute tar member refused" "$PROJENY" setup a.projeny
    out="$(cd "$T71" && "$PROJENY" setup a.projeny 2>&1 || true)"
    case "$out" in
    *absolute*)
        ok "absolute-member error names the problem"
        ;;
    *)
        fail "absolute-member error names the problem" "out: $out"
        ;;
    esac
    printf 'Archive: dotdot.tar.gz\nOrigname: top\nName: b\n\n    T.\n' > "$T71/b.projeny"
    run_in "$T71" expect_fail "dotdot tar member refused" "$PROJENY" setup b.projeny
    out="$(cd "$T71" && "$PROJENY" setup b.projeny 2>&1 || true)"
    case "$out" in
    *top/../../evil*)
        ok "dotdot-member error names the member"
        ;;
    *)
        fail "dotdot-member error names the member" "out: $out"
        ;;
    esac
else
    ok "absolute tar member refused (skipped: no python3)"
    ok "absolute-member error names the problem (skipped: no python3)"
    ok "dotdot tar member refused (skipped: no python3)"
    ok "dotdot-member error names the member (skipped: no python3)"
fi

# ----------------------------------------- 70. hostile patch paths fail cleanly
# A stored patch that creates a file under a path blocked by a regular file
# (or into a directory) must fail with a precise per-file error, not die.
T72="$ROOT/t72"
mkdir -p "$T72/w-1.0"
printf 'file-a\n' > "$T72/w-1.0/a"
(cd "$T72" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T72/w.projeny"
cat >> "$T72/w.projeny" <<'EOF'
diff --git a/w/a/b b/w/a/b
new file mode 100644
--- /dev/null
+++ b/w/a/b
@@ -0,0 +1,1 @@
+hello
EOF
run_in "$T72" expect_fail "file-under-file patch refused" "$PROJENY" setup w.projeny
out="$(cd "$T72" && "$PROJENY" setup w.projeny 2>&1 || true)"
case "$out" in
*a/b*)
    ok "file-under-file error names the path"
    ;;
*)
    fail "file-under-file error names the path" "out: $out"
    ;;
esac

# ----------------------------------------- 71. pending symlink survives rebase
T73="$ROOT/t73"
mkdir -p "$T73/w-1.0"
printf 'v1\n' > "$T73/w-1.0/f.c"
printf 'real\n' > "$T73/w-1.0/r.txt"
(cd "$T73" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T73/w.projeny"
run_in "$T73" expect_ok "pending-link setup" "$PROJENY" setup w.projeny
ln -s r.txt "$T73/w/pendlink"
run_in "$T73" expect_ok "stage pending symlink" "$PROJENY" add w.projeny w/pendlink
mkdir -p "$T73/w-2.0"
printf 'v2\n' > "$T73/w-2.0/f.c"
printf 'real\n' > "$T73/w-2.0/r.txt"
(cd "$T73" && tar -czf w-2.0.tar.gz w-2.0 && rm -rf w-2.0)
run_in "$T73" expect_ok "rebase with pending symlink" "$PROJENY" rebase w.projeny w-2.0.tar.gz
expect_file_contains "pending symlink kept in status" "$T73/w.projeny.status" "Added: pendlink"
if [ -L "$T73/w/pendlink" ] && [ "$(readlink "$T73/w/pendlink")" = "r.txt" ]; then
    ok "pending symlink still a link after rebase"
else
    fail "pending symlink still a link after rebase" "$(ls -l "$T73/w" 2>&1)"
fi
run_in "$T73" expect_ok "commit pending symlink after rebase" "$PROJENY" commit w.projeny
rm -rf "$T73/w" "$T73/w.projeny.status"
run_in "$T73" expect_ok "setup after symlink commit" "$PROJENY" setup w.projeny
if [ -L "$T73/w/pendlink" ]; then
    ok "committed symlink survives re-setup"
else
    fail "committed symlink survives re-setup" "$(ls -l "$T73/w" 2>&1)"
fi

# ----------------------------------------- 72. file/dir swaps merge safely
# Replacing a tracked file with a directory (or vice versa) must merge the
# real content or conflict — never silently drop user data, die, or hang.
T74="$ROOT/t74"
mkdir -p "$T74/w-1.0"
printf 'v1\n' > "$T74/w-1.0/f.c"
printf 'keep\n' > "$T74/w-1.0/g.c"
(cd "$T74" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T74/w.projeny"
run_in "$T74" expect_ok "swap setup" "$PROJENY" setup w.projeny
cp "$T74/w.projeny" "$ROOT/t74-base.projeny"
rm "$T74/w/f.c"
mkdir "$T74/w/f.c"
printf 'user inner\n' > "$T74/w/f.c/inner.txt"
cp "$ROOT/t74-base.projeny" "$T74/w.projeny"
run_in "$T74" expect_ok "file-to-dir merge keeps content" "$PROJENY" setup w.projeny
expect_file_contains "swapped dir content preserved" "$T74/w/f.c/inner.txt" "user inner"
T74B="$ROOT/t74b"
mkdir -p "$T74B/w-1.0"
printf 'v1\n' > "$T74B/w-1.0/f.c"
(cd "$T74B" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T74B/w.projeny"
(cd "$T74B" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'v1 upstream\n' > "$T74B/w/f.c"
(cd "$T74B" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$T74B/w.projeny" "$ROOT/t74b-up.projeny"
cat > "$T74B/w.projeny" <<'EOF'
Archive: w-1.0.tar.gz
Origname: w-1.0
Name: w

    T.
EOF
rm -rf "$T74B/w" "$T74B/w.projeny.status"
(cd "$T74B" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
rm "$T74B/w/f.c"
mkdir "$T74B/w/f.c"
printf 'local inner\n' > "$T74B/w/f.c/inner.txt"
cp "$ROOT/t74b-up.projeny" "$T74B/w.projeny"
run_in "$T74B" expect_ok "divergent file-to-dir merge exits 0" "$PROJENY" setup w.projeny
expect_file_contains "divergent swap records conflict" "$T74B/w.projeny.status" "Conflict: f.c"
expect_file_contains "divergent swap keeps local inner file" "$T74B/w/f.c/inner.txt" "local inner"
if [ -d "$T74B/w/f.c" ]; then
    ok "divergent swap keeps local directory"
else
    fail "divergent swap keeps local directory" "ls: $(ls -l "$T74B/w" 2>&1)"
fi

# ----------------------------------------- 73. huge line without trailing newline
T75="$ROOT/t75"
mkdir -p "$T75/w-1.0"
printf 'seed\n' > "$T75/w-1.0/s.txt"
(cd "$T75" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Huge.\n' > "$T75/w.projeny"
run_in "$T75" expect_ok "huge setup" "$PROJENY" setup w.projeny
python3 -c "open('$T75/w/huge.txt','w').write('Z'*100000)"
run_in "$T75" expect_ok "add huge no-newline file" "$PROJENY" add w.projeny w/huge.txt
run_in "$T75" expect_ok "commit huge no-newline file" "$PROJENY" commit w.projeny
expect_file_contains "huge commit stores no-newline marker" "$T75/w.projeny" "No newline at end of file"
cp "$T75/w/huge.txt" "$ROOT/t75-expect-huge.txt"
rm -rf "$T75/w" "$T75/w.projeny.status"
run_in "$T75" expect_ok "setup after huge commit" "$PROJENY" setup w.projeny
if cmp -s "$T75/w/huge.txt" "$ROOT/t75-expect-huge.txt"; then
    ok "huge no-newline file byte-identical after re-setup"
else
    fail "huge no-newline file byte-identical after re-setup"
fi

# ----------------------------------------- 74. wid-prefixed resolve and rebase noop
T76="$ROOT/t76"
mkdir -p "$T76/w-1.0"
printf 'one\ntwo\nthree\n' > "$T76/w-1.0/f.c"
(cd "$T76" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    T.\n' > "$T76/w.projeny"
(cd "$T76" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'ONE\ntwo\nthree\n' > "$T76/w/f.c"
(cd "$T76" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$T76/w.projeny" "$ROOT/t76-local.projeny"
rm -rf "$T76/w" "$T76/w.projeny.status"
cp "$ROOT/t76-local.projeny" "$T76/w.projeny"
(cd "$T76" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'local edit\n' > "$T76/w/f.c"
U76="$ROOT/t76up"
mkdir -p "$U76"
cp "$T76/w-1.0.tar.gz" "$U76/"
cp "$ROOT/t76-local.projeny" "$U76/w.projeny"
(cd "$U76" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'upstream edit\n' > "$U76/w/f.c"
(cd "$U76" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$U76/w.projeny" "$T76/w.projeny"
(cd "$T76" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'resolved\n' > "$T76/w/f.c"
run_in "$T76" expect_ok "resolve accepts wid-prefixed path" "$PROJENY" resolve w.projeny w/f.c
if grep -q "^Conflict:" "$T76/w.projeny.status"; then
    fail "wid-prefixed resolve clears conflict"
else
    ok "wid-prefixed resolve clears conflict"
fi
run_in "$T76" expect_ok "commit after wid resolve" "$PROJENY" commit w.projeny
run_in "$T76" expect_ok "rebase onto identical tarball" "$PROJENY" rebase w.projeny w-1.0.tar.gz
expect_file_contains "rebase noop keeps content" "$T76/w/f.c" "resolved"

# ----------------------------------------- 75. long names and odd-but-legal bytes
T77="$ROOT/t77"
mkdir -p "$T77/w-1.0"
printf 'base\n' > "$T77/w-1.0/base.c"
(cd "$T77" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Long.\n' > "$T77/w.projeny"
run_in "$T77" expect_ok "long-name setup" "$PROJENY" setup w.projeny
LONG="$(python3 -c "print('L'*200 + '.c')")"
printf 'long content\n' > "$T77/w/$LONG"
run_in "$T77" expect_ok "add 200-char name" "$PROJENY" add w.projeny "w/$LONG"
printf 'punct\n' > "$T77/w/semi;colon.c"
printf 'p2\n' > "$T77/w/eq=uals.c"
run_in "$T77" expect_ok "add semicolon name" "$PROJENY" add w.projeny "w/semi;colon.c"
run_in "$T77" expect_ok "add equals name" "$PROJENY" add w.projeny "w/eq=uals.c"
run_in "$T77" expect_ok "commit odd names" "$PROJENY" commit w.projeny
rm -rf "$T77/w" "$T77/w.projeny.status"
run_in "$T77" expect_ok "setup after odd-name commit" "$PROJENY" setup w.projeny
if [ -f "$T77/w/$LONG" ]; then
    ok "200-char filename survives re-setup"
else
    fail "200-char filename survives re-setup" "ls: $(ls "$T77/w" 2>&1)"
fi
expect_file_contains "semicolon name survives" "$T77/w/semi;colon.c" "punct"
expect_file_contains "equals name survives" "$T77/w/eq=uals.c" "p2"

T78="$ROOT/t78"
mkdir -p "$T78/A" "$T78/B"
printf 'one\ntwo\nthree\n' > "$T78/A/f.c"
printf 'one\nTWO\nthree\n' > "$T78/B/f.c"
printf 'new file\n' > "$T78/B/g.c"
out="$(cd "$T78" && "$PROJENY" diff A B 2>&1)"
rc=$?
if [ $rc -eq 0 ]; then
    ok "diff exits 0"
else
    fail "diff exits 0" "exit=$rc out: $out"
fi
if echo "$out" | grep -q "diff --git a/B/f.c b/B/f.c"; then
    ok "diff labels use second dir basename"
else
    fail "diff labels use second dir basename" "out: $out"
fi
if echo "$out" | grep -q "new file mode"; then
    ok "diff shows added file"
else
    fail "diff shows added file" "out: $out"
fi
out2="$(cd "$T78" && "$PROJENY" diff A A 2>&1)"
if [ -z "$out2" ]; then
    ok "diff of identical dirs is empty"
else
    fail "diff of identical dirs is empty" "out: $out2"
fi
# roundtrip: diff A B, patch a copy of A, get B back byte-for-byte.
(cd "$T78" && "$PROJENY" diff A B > roundtrip.diff && rm -rf C && cp -r A C && "$PROJENY" patch C roundtrip.diff >/dev/null 2>&1)
if [ $? -eq 0 ] && [ ! -e "$T78/C/B" ]; then
    ok "diff+patch roundtrip applies"
else
    fail "diff+patch roundtrip applies" "ls: $(ls -R "$T78/C" 2>&1)"
fi
if diff -r "$T78/C" "$T78/B" >/dev/null 2>&1; then
    ok "diff+patch roundtrip is byte-identical"
else
    fail "diff+patch roundtrip is byte-identical" "$(diff -r "$T78/C" "$T78/B" 2>&1 | head -5)"
fi
# rename detection through the diff command.
(cd "$T78" && rm -rf R1 R2 && mkdir R1 R2 && printf 'same bytes\n' > R1/old.txt && printf 'same bytes\n' > R2/new.txt && "$PROJENY" diff R1 R2 > rename.diff 2>&1)
if grep -q "rename from" "$T78/rename.diff"; then
    ok "diff detects renames"
else
    fail "diff detects renames" "$(cat "$T78/rename.diff")"
fi
run_in "$T78" expect_fail "diff of missing dir fails" "$PROJENY" diff A "$T78/nope"
printf 'x\n' > "$T78/plainfile"
run_in "$T78" expect_fail "diff of non-dir fails" "$PROJENY" diff "$T78/plainfile" B
run_in "$T78" expect_fail "diff with one arg fails" "$PROJENY" diff A
run_in "$T78" expect_fail "patch with one arg fails" "$PROJENY" patch A

# ----------------------------------------- 77. minimum-diff devious cases
T79="$ROOT/t79"
mkdir -p "$T79/A" "$T79/B"
python3 -c "open('$T79/A/big.c','w').write('same line\n'*100)"
python3 -c "open('$T79/B/big.c','w').write('same line\n'*49 + 'CHANGED\n' + 'same line\n'*50)"
(cd "$T79" && "$PROJENY" diff A B > big.diff 2>&1)
if [ "$(grep -c '^@@' "$T79/big.diff")" -eq 1 ]; then
    ok "repeated-line change is a single hunk"
else
    fail "repeated-line change is a single hunk" "hunks: $(grep -c '^@@' "$T79/big.diff")"
fi
if [ "$(wc -l < "$T79/big.diff")" -lt 20 ]; then
    ok "repeated-line diff stays small"
else
    fail "repeated-line diff stays small" "lines: $(wc -l < "$T79/big.diff")"
fi
# alternating-pattern trap: one flipped line among ABA BAB alternation.
python3 -c "open('$T79/A/alt.c','w').write('aaa\nbbb\n'*30)"
python3 -c "open('$T79/B/alt.c','w').write('aaa\nbbb\n'*14 + 'aaa\nFLIP\n' + 'aaa\nbbb\n'*15)"
(cd "$T79" && "$PROJENY" diff A B > alt.diff 2>&1)
if [ "$(grep -c '^@@' "$T79/alt.diff")" -le 2 ]; then
    ok "alternating-pattern change stays minimal"
else
    fail "alternating-pattern change stays minimal" "hunks: $(grep -c '^@@' "$T79/alt.diff")"
fi
(cd "$T79" && rm -rf C && cp -r A C && "$PROJENY" patch C alt.diff >/dev/null 2>&1 && "$PROJENY" patch C big.diff >/dev/null 2>&1)
if diff -r "$T79/C" "$T79/B" >/dev/null 2>&1; then
    ok "devious diffs roundtrip byte-identical"
else
    fail "devious diffs roundtrip byte-identical" "$(diff -r "$T79/C" "$T79/B" 2>&1 | head -5)"
fi
# trailing-whitespace-only change roundtrips exactly.
mkdir -p "$T79/W1" "$T79/W2"
printf 'pad   \nend\n' > "$T79/W1/ws.c"
printf 'pad\nend\n' > "$T79/W2/ws.c"
(cd "$T79" && "$PROJENY" diff W1 W2 > ws.diff 2>&1 && rm -rf W3 && cp -r W1 W3 && "$PROJENY" patch W3 ws.diff >/dev/null 2>&1)
if cmp -s "$T79/W3/ws.c" "$T79/W2/ws.c"; then
    ok "whitespace-only change roundtrips byte-identical"
else
    fail "whitespace-only change roundtrips byte-identical"
fi

# ----------------------------------------- 78. patch devious + conflicts
T80="$ROOT/t80"
mkdir -p "$T80/A" "$T80/B"
printf 'one\ntwo\nthree\n' > "$T80/A/f.c"
printf 'one\nTWO\nthree\n' > "$T80/B/f.c"
(cd "$T80" && "$PROJENY" diff A B > f.diff 2>&1)
mkdir -p "$T80/T"
printf 'one\ntwo\nthree\n' > "$T80/T/f.c"
out="$(cd "$T80" && "$PROJENY" patch T f.diff 2>&1)"
if [ $? -eq 0 ] && echo "$out" | grep -q "patched"; then
    ok "clean patch exits 0 with message"
else
    fail "clean patch exits 0 with message" "out: $out"
fi
expect_file_contains "clean patch updates content" "$T80/T/f.c" "TWO"
out="$(cd "$T80" && "$PROJENY" patch T f.diff 2>&1)"
if [ $? -eq 0 ]; then
    ok "re-applying a patch is idempotent"
else
    fail "re-applying a patch is idempotent" "out: $out"
fi
# shifted hunk offsets (fuzz) still apply.
python3 - "$T80/f.diff" <<'EOF'
import re, sys
s = open(sys.argv[1]).read()
s2 = re.sub(r"@@ -(\d+),", lambda m: "@@ -%d," % (int(m.group(1)) + 5), s, count=1)
assert s2 != s
open(sys.argv[1] + ".shifted", "w").write(s2)
EOF
mkdir -p "$T80/T2"
printf 'one\ntwo\nthree\n' > "$T80/T2/f.c"
run_in "$T80" expect_ok "patch with shifted offsets applies" "$PROJENY" patch T2 f.diff.shifted
expect_file_contains "shifted patch updates content" "$T80/T2/f.c" "TWO"
# conflicting patch: same line changed differently.
mkdir -p "$T80/T3"
printf 'one\nCONFLICT\nthree\n' > "$T80/T3/f.c"
out="$(cd "$T80" && "$PROJENY" patch T3 f.diff 2>&1)"
rc=$?
if [ $rc -eq 0 ]; then
    ok "conflicting patch still exits 0"
else
    fail "conflicting patch still exits 0" "exit=$rc out: $out"
fi
if echo "$out" | grep -q "f.c"; then
    ok "conflicting patch lists the file on console"
else
    fail "conflicting patch lists the file on console" "out: $out"
fi
expect_file_contains "conflicting patch inserts <<<<<<<" "$T80/T3/f.c" "<<<<<<<"
expect_file_contains "conflicting patch inserts =======" "$T80/T3/f.c" "======="
expect_file_contains "conflicting patch inserts >>>>>>>" "$T80/T3/f.c" ">>>>>>>"
expect_file_contains "conflicting patch keeps current side" "$T80/T3/f.c" "CONFLICT"
expect_file_contains "conflicting patch keeps patched side" "$T80/T3/f.c" "TWO"
# mixed: one clean file + one conflicted file in a single patch.
mkdir -p "$T80/M1" "$T80/M2"
printf 'keep\nme\n' > "$T80/M1/ok.c"
printf 'same\nline\n' > "$T80/M1/bad.c"
printf 'keep\nME\n' > "$T80/M2/ok.c"
printf 'same\nLINE\n' > "$T80/M2/bad.c"
(cd "$T80" && "$PROJENY" diff M1 M2 > m.diff 2>&1)
mkdir -p "$T80/M3"
printf 'keep\nme\n' > "$T80/M3/ok.c"
printf 'same\nDIFFERENT\n' > "$T80/M3/bad.c"
out="$(cd "$T80" && "$PROJENY" patch M3 m.diff 2>&1)"
expect_file_contains "mixed patch applies the clean file" "$T80/M3/ok.c" "ME"
expect_file_contains "mixed patch marks the conflicted file" "$T80/M3/bad.c" "<<<<<<<"
if echo "$out" | grep -q "bad.c" && ! echo "$out" | grep -q "ok.c"; then
    ok "mixed patch lists only the conflicted file"
else
    fail "mixed patch lists only the conflicted file" "out: $out"
fi
# new-file conflict: patch adds a file that exists with other bytes.
mkdir -p "$T80/N1" "$T80/N2"
printf 'base\n' > "$T80/N1/base.c"
printf 'base\n' > "$T80/N2/base.c"
printf 'wanted\n' > "$T80/N2/added.c"
(cd "$T80" && "$PROJENY" diff N1 N2 > n.diff 2>&1)
mkdir -p "$T80/N3"
printf 'base\n' > "$T80/N3/base.c"
printf 'rival\n' > "$T80/N3/added.c"
out="$(cd "$T80" && "$PROJENY" patch N3 n.diff 2>&1)"
expect_file_contains "new-file conflict leaves markers" "$T80/N3/added.c" "<<<<<<<"
expect_file_contains "new-file conflict keeps current bytes" "$T80/N3/added.c" "rival"
expect_file_contains "new-file conflict shows wanted bytes" "$T80/N3/added.c" "wanted"
if echo "$out" | grep -q "added.c"; then
    ok "new-file conflict is listed"
else
    fail "new-file conflict is listed" "out: $out"
fi
# delete-vs-modify: patch deletes a file the target changed.
mkdir -p "$T80/D1" "$T80/D2"
printf 'gone one\ngone two\n' > "$T80/D1/del.c"
mkdir -p "$T80/D3"
printf 'gone one\nCHANGED\n' > "$T80/D3/del.c"
(cd "$T80" && "$PROJENY" diff D1 D2 > d.diff 2>&1)
out="$(cd "$T80" && "$PROJENY" patch D3 d.diff 2>&1)"
if [ -f "$T80/D3/del.c" ]; then
    ok "delete-vs-modify keeps the file"
else
    fail "delete-vs-modify keeps the file" "ls: $(ls "$T80/D3" 2>&1)"
fi
if echo "$out" | grep -q "del.c"; then
    ok "delete-vs-modify is listed"
else
    fail "delete-vs-modify is listed" "out: $out"
fi
# empty and garbage patch files.
printf '' > "$T80/empty.diff"
run_in "$T80" expect_ok "empty patch is a noop" "$PROJENY" patch T3 empty.diff
printf 'just some text\nno diffs here\n' > "$T80/garbage.diff"
run_in "$T80" expect_fail "garbage patch file fails" "$PROJENY" patch T3 garbage.diff
run_in "$T80" expect_fail "missing patch file fails" "$PROJENY" patch T3 "$T80/nope.diff"
run_in "$T80" expect_fail "patch of missing dir fails" "$PROJENY" patch "$T80/nope" f.diff
# ----------------------------------------- 79. conflicted .projeny (markers)
# Helper: splice ours/theirs .projeny files into one git-style conflict.
make_conflicted() {
    # $1=ours $2=theirs $3=out [$4=style: merge (default) or diff3]
    python3 - "$1" "$2" "$3" "${4:-merge}" <<'EOF'
import sys
ours, theirs, out = sys.argv[1], sys.argv[2], sys.argv[3]
style = sys.argv[4] if len(sys.argv) > 4 else "merge"
a = open(ours).read().split("\n")
b = open(theirs).read().split("\n")
n = min(len(a), len(b))
i = 0
while i < n and a[i] == b[i]:
    i += 1
j0, j1 = len(a), len(b)
while j0 > i and j1 > i and a[j0 - 1] == b[j1 - 1]:
    j0 -= 1
    j1 -= 1
blk = ["<<<<<<< HEAD"] + a[i:j0]
if style == "diff3":
    blk += ["||||||| base"] + ["# ancestral placeholder"]
blk += ["======="] + b[i:j1] + [">>>>>>> branch"]
open(out, "w").write("\n".join(a[:i] + blk + a[j0:]))
EOF
}

T81="$ROOT/t81"
mkdir -p "$T81/w-1.0"
printf 'alpha 1\nbeta 1\ngamma 1\ndelta 1\n' > "$T81/w-1.0/a.c"
(cd "$T81" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    C.\n' > "$T81/w.projeny"
(cd "$T81" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$T81/w/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("beta 1", "beta LOCAL")
open(p, "w").write(s)
EOF
(cd "$T81" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$T81/w.projeny" "$ROOT/t81-local.projeny"
# upstream twin: same base, beta changed the other way.
U81="$ROOT/t81up"
mkdir -p "$U81"
cp "$T81/w-1.0.tar.gz" "$U81/"
cp "$ROOT/t81-local.projeny" "$U81/w.projeny"
(cd "$U81" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$U81/w/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("beta LOCAL", "beta UPSTREAM")
open(p, "w").write(s)
EOF
(cd "$U81" && "$PROJENY" commit w.projeny >/dev/null 2>&1)
cp "$U81/w.projeny" "$ROOT/t81-up.projeny"
# simple case: no uncommitted changes; conflict the .projeny file.
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T81/w.projeny"
out="$(cd "$T81" && "$PROJENY" setup w.projeny 2>&1)"
if [ $? -eq 0 ]; then
    ok "conflicted setup (simple) exits 0"
else
    fail "conflicted setup (simple) exits 0" "out: $out"
fi
if cmp -s "$T81/w.projeny" "$ROOT/t81-up.projeny"; then
    ok ".projeny force-takes upstream"
else
    fail ".projeny force-takes upstream" "$(cat "$T81/w.projeny")"
fi
if cmp -s <(sed -n '/^--- projeny content ---$/,$p' "$T81/w.projeny.status" | tail -n +2) "$ROOT/t81-up.projeny" 2>/dev/null || cmp -s "$T81/w.projeny" <(sed -n '/^--- projeny content ---$/,$p' "$T81/w.projeny.status" | tail -n +2); then
    ok "status embeds the upstream copy"
else
    fail "status embeds the upstream copy" "$(head -8 "$T81/w.projeny.status")"
fi
expect_file_contains "conflicted checkout has workdir markers" "$T81/w/a.c" "<<<<<<<"
expect_file_contains "conflicted checkout keeps local side" "$T81/w/a.c" "beta LOCAL"
expect_file_contains "conflicted checkout keeps upstream side" "$T81/w/a.c" "beta UPSTREAM"
expect_file_contains "conflicted checkout records conflict" "$T81/w.projeny.status" "Conflict: a.c"
if echo "$out" | grep -q "a.c"; then
    ok "conflicted setup lists conflicted files"
else
    fail "conflicted setup lists conflicted files" "out: $out"
fi
# every other command refuses the conflicted file (re-conflict first).
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T81/w.projeny"
run_in "$T81" expect_fail "commit refuses conflicted .projeny" "$PROJENY" commit w.projeny
run_in "$T81" expect_fail "add refuses conflicted .projeny" "$PROJENY" add w.projeny w/a.c
run_in "$T81" expect_fail "rm refuses conflicted .projeny" "$PROJENY" rm w.projeny w/a.c
run_in "$T81" expect_fail "mv refuses conflicted .projeny" "$PROJENY" mv w.projeny w/a.c w/b.c
run_in "$T81" expect_fail "resolve refuses conflicted .projeny" "$PROJENY" resolve w.projeny w/a.c
run_in "$T81" expect_fail "rebase refuses conflicted .projeny" "$PROJENY" rebase w.projeny w-1.0.tar.gz
# resolve+commit works after fixing through the conflicted setup.
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T81/w.projeny"
(cd "$T81" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
printf 'alpha 1\nbeta FIXED\ngamma 1\ndelta 1\n' > "$T81/w/a.c"
run_in "$T81" expect_ok "resolve after conflicted setup" "$PROJENY" resolve w.projeny w/a.c
run_in "$T81" expect_ok "commit after conflicted setup" "$PROJENY" commit w.projeny
expect_file_contains "commit stores the fix" "$T81/w.projeny" "beta FIXED"

# ----------------------------------------- 80. harder + no-checkout + diff3
T82="$ROOT/t82"
mkdir -p "$T82"
cp "$T81/w-1.0.tar.gz" "$T82/"
cp "$ROOT/t81-local.projeny" "$T82/w.projeny"
(cd "$T82" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
# uncommitted edit in a disjoint region (harder case).
python3 - "$T82/w/a.c" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("delta 1", "delta UNCOMMITTED")
open(p, "w").write(s)
EOF
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T82/w.projeny" diff3
expect_file_contains "diff3 fixture has base section" "$T82/w.projeny" "|||||||"
run_in "$T82" expect_ok "conflicted setup (harder, diff3) exits 0" "$PROJENY" setup w.projeny
expect_file_contains "harder case keeps uncommitted edit" "$T82/w/a.c" "delta UNCOMMITTED"
expect_file_contains "harder case still marks the conflict" "$T82/w/a.c" "<<<<<<<"
if cmp -s "$T82/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "harder case force-takes upstream"
else
    fail "harder case force-takes upstream"
fi
# no-checkout case: status file but no workdir (the checkout was lost).
# The status copy still breaks the direction tie, so the merge resolves.
T83="$ROOT/t83"
mkdir -p "$T83"
cp "$T81/w-1.0.tar.gz" "$T83/"
cp "$ROOT/t81-local.projeny" "$T83/w.projeny"
(cd "$T83" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
rm -rf "$T83/w"
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T83/w.projeny"
run_in "$T83" expect_ok "conflicted setup (no checkout) exits 0" "$PROJENY" setup w.projeny
if cmp -s "$T83/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "no-checkout case force-takes upstream"
else
    fail "no-checkout case force-takes upstream"
fi
expect_file_contains "no-checkout case marks conflicts" "$T83/w/a.c" "<<<<<<<"
expect_file_contains "no-checkout case records conflict" "$T83/w.projeny.status" "Conflict: a.c"
# header-only conflict (prose differs, patch identical) merges cleanly.
# The checkout is set up from the local-prose side first so the status copy
# breaks the direction tie (a voteless merge with no status must die).
T84="$ROOT/t84"
mkdir -p "$T84"
cp "$T81/w-1.0.tar.gz" "$T84/"
python3 - "$ROOT/t81-local.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
open(sys.argv[1] + ".ours", "w").write(s.replace("    C.\n", "    Local prose.\n"))
open(sys.argv[1] + ".theirs", "w").write(s.replace("    C.\n", "    Upstream prose.\n"))
PYEOF
cp "$ROOT/t81-local.projeny.ours" "$T84/w.projeny"
(cd "$T84" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
make_conflicted "$ROOT/t81-local.projeny.ours" "$ROOT/t81-local.projeny.theirs" "$T84/w.projeny"
(cd "$T84" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
if [ $? -eq 0 ]; then
    ok "prose-only conflict sets up"
else
    fail "prose-only conflict sets up"
fi
expect_file_contains "prose-only conflict takes upstream prose" "$T84/w.projeny" "Upstream prose."
if grep -q "^Conflict:" "$T84/w.projeny.status"; then
    fail "prose-only conflict records no conflicts" "$(cat "$T84/w.projeny.status")"
else
    ok "prose-only conflict records no conflicts"
fi
expect_file_contains "prose-only workdir keeps patch content" "$T84/w/a.c" "beta LOCAL"

# ----------------------------------------- 81. malformed/truncated/binary refuse
T85="$ROOT/t85"
mkdir -p "$T85"
cp "$T81/w-1.0.tar.gz" "$T85/"
cp "$ROOT/t81-local.projeny" "$T85/w.projeny"
(cd "$T85" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
cp "$T85/w/a.c" "$ROOT/t85-a-before.c"
# malformed: opener with no closer.
python3 -c "open('$T85/w.projeny','w').write(open('$ROOT/t81-local.projeny').read().replace('+beta LOCAL', '<<<<<<< HEAD\\n+beta LOCAL'))"
run_in "$T85" expect_fail "unclosed markers fail setup" "$PROJENY" setup w.projeny
if cmp -s "$T85/w/a.c" "$ROOT/t85-a-before.c"; then
    ok "failed setup leaves workdir untouched"
else
    fail "failed setup leaves workdir untouched"
fi
# truncated: no markers, headers incomplete.
python3 -c "open('$T85/w.projeny','w').write('Archive: w-1.0.tar.gz\nOrigname: TRUNC')"
run_in "$T85" expect_fail "truncated .projeny fails setup" "$PROJENY" setup w.projeny
if cmp -s "$T85/w/a.c" "$ROOT/t85-a-before.c"; then
    ok "truncated setup leaves workdir untouched"
else
    fail "truncated setup leaves workdir untouched"
fi
# Archive pointing at a missing tarball (half-pulled tree, LFS-style).
python3 -c "open('$T85/w.projeny','w').write(open('$ROOT/t81-local.projeny').read().replace('w-1.0.tar.gz', 'w-9.9.tar.gz'))"
run_in "$T85" expect_fail "missing tarball fails setup" "$PROJENY" setup w.projeny
if cmp -s "$T85/w/a.c" "$ROOT/t85-a-before.c"; then
    ok "missing-tarball setup leaves workdir untouched"
else
    fail "missing-tarball setup leaves workdir untouched"
fi
# binary garbage (NUL bytes, as a bad merge driver might leave).
python3 -c "open('$T85/w.projeny','wb').write(b'Archive: x\x00binary\n')"
run_in "$T85" expect_fail "binary .projeny fails setup" "$PROJENY" setup w.projeny
if cmp -s "$T85/w/a.c" "$ROOT/t85-a-before.c"; then
    ok "binary setup leaves workdir untouched"
else
    fail "binary setup leaves workdir untouched"
fi
# CRLF conflicted file: warns but resolves like LF. The conflict is built
# exactly like make_conflicted (common prefix/suffix factored out so each
# side byte-matches its fixture); only the line endings are CRLF. Note the
# trailing "" split element already terminates the text, so no extra
# newline is appended (an extra one would leave a phantom blank line in
# the split sides and break the status-copy comparison).
python3 - "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T85/w.projeny" <<'PYEOF'
import sys
a = open(sys.argv[1]).read().split("\n")
b = open(sys.argv[2]).read().split("\n")
n = min(len(a), len(b))
i = 0
while i < n and a[i] == b[i]:
    i += 1
j0, j1 = len(a), len(b)
while j0 > i and j1 > i and a[j0 - 1] == b[j1 - 1]:
    j0 -= 1
    j1 -= 1
out = a[:i] + ["<<<<<<< HEAD"] + a[i:j0] + ["======="] + b[i:j1] + [">>>>>>> branch"] + a[j0:]
open(sys.argv[3], "w").write("\r\n".join(out))
PYEOF
out="$(cd "$T85" && "$PROJENY" setup w.projeny 2>&1)"
if [ $? -eq 0 ]; then
    ok "CRLF conflicted setup exits 0"
else
    fail "CRLF conflicted setup exits 0" "out: $out"
fi
if echo "$out" | grep -qi "CRLF"; then
    ok "CRLF setup warns about line endings"
else
    fail "CRLF setup warns about line endings" "out: $out"
fi
expect_file_contains "CRLF setup marks conflicts" "$T85/w/a.c" "<<<<<<<"
# ----------------------------------------- 82. git-merge conflict via setup
if command -v git >/dev/null 2>&1; then
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_EDITOR=true
    G86="$ROOT/t86"
    mkdir -p "$G86/repo"
    (cd "$G86/repo" && git init -q -b master . && mkdir w-1.0 && printf 'alpha 1\nbeta 1\ngamma 1\ndelta 1\n' > w-1.0/a.c && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0 && printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    G.\n' > w.projeny && "$PROJENY" setup w.projeny >/dev/null 2>&1 && git add w-1.0.tar.gz w.projeny && git commit -qm base)
    # upstream branch: beta -> UPSTREAM, committed to git.
    (cd "$G86/repo" && git checkout -qb upstream && python3 - w/a.c <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("beta 1", "beta UPSTREAM")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git commit -qm upstream w.projeny)
    cp "$G86/repo/w.projeny" "$ROOT/t86-up.projeny"
    # local branch off base: beta -> LOCAL, committed to git.
    (cd "$G86/repo" && git checkout -q master && rm -rf w w.projeny.status && "$PROJENY" setup w.projeny >/dev/null 2>&1 && python3 - w/a.c <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("beta 1", "beta LOCAL")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git checkout -qb local && git commit -qm local w.projeny)
    # merge upstream into local: git conflicts on w.projeny.
    (cd "$G86/repo" && git merge -q upstream >/dev/null 2>&1)
    if [ $? -ne 0 ] && grep -q "<<<<<<<" "$G86/repo/w.projeny"; then
        ok "git merge conflicts the .projeny file"
    else
        fail "git merge conflicts the .projeny file" "$(cat "$G86/repo/w.projeny" 2>&1 | head -20)"
    fi
    # harder case: uncommitted disjoint edit before projeny takes over.
    (cd "$G86/repo" && python3 - w/a.c <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("delta 1", "delta UNCOMMITTED")
open(p, "w").write(s)
PYEOF
)
    out="$(cd "$G86/repo" && "$PROJENY" setup w.projeny 2>&1)"
    if [ $? -eq 0 ]; then
        ok "setup resolves git conflict markers"
    else
        fail "setup resolves git conflict markers" "out: $out"
    fi
    if cmp -s "$G86/repo/w.projeny" "$ROOT/t86-up.projeny"; then
        ok "git conflict takes upstream bytes"
    else
        fail "git conflict takes upstream bytes" "$(cat "$G86/repo/w.projeny")"
    fi
    expect_file_contains "git setup keeps uncommitted edit" "$G86/repo/w/a.c" "delta UNCOMMITTED"
    expect_file_contains "git setup marks beta conflict" "$G86/repo/w/a.c" "<<<<<<<"
    expect_file_contains "git setup records conflict" "$G86/repo/w.projeny.status" "Conflict: a.c"
    if echo "$out" | grep -q "a.c"; then
        ok "git setup lists conflicted files"
    else
        fail "git setup lists conflicted files" "out: $out"
    fi
    # finish the merge by hand: fix, resolve, commit, keep git history sane.
    (cd "$G86/repo" && printf 'alpha 1\nbeta MERGED\ngamma 1\ndelta UNCOMMITTED\n' > w/a.c && "$PROJENY" resolve w.projeny w/a.c >/dev/null 2>&1 && "$PROJENY" commit w.projeny >/dev/null 2>&1 && git add w.projeny && git -c core.editor=true commit -qm resolved)
    if [ $? -eq 0 ]; then
        ok "resolve+commit finishes the git merge"
    else
        fail "resolve+commit finishes the git merge"
    fi
    # stash-pop flavor: conflicting uncommitted edit reapplied over a move.
    (cd "$G86/repo" && git checkout -qb spop && python3 - w/a.c <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("gamma 1", "gamma STASHED")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git stash push -q -- w.projeny && "$PROJENY" setup w.projeny >/dev/null 2>&1 && python3 - w/a.c <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("gamma 1", "gamma OTHER")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git commit -qm other w.projeny && git stash pop >/dev/null 2>&1; true)
    if grep -q "<<<<<<<" "$G86/repo/w.projeny"; then
        ok "stash pop conflicts the .projeny file"
    else
        fail "stash pop conflicts the .projeny file" "$(head -20 "$G86/repo/w.projeny")"
    fi
    out="$(cd "$G86/repo" && "$PROJENY" setup w.projeny 2>&1)"
    if [ $? -eq 0 ] && grep -q "<<<<<<<" "$G86/repo/w/a.c"; then
        ok "setup resolves stash-pop markers into workdir conflicts"
    else
        fail "setup resolves stash-pop markers into workdir conflicts" "out: $out"
    fi
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_EDITOR
else
    ok "git conflict tests (skipped: no git)"
fi

# ----------------------------------------- 84. rebase-direction conflicted .projeny
# `git pull --rebase` swaps the sides: <<<<<<< HEAD holds upstream, >>>>>>>
# names the local commit. setup must still take the upstream side (the old
# code force-took the second side and kept the local file instead).
T88="$ROOT/t88"
mkdir -p "$T88"
cp "$T81/w-1.0.tar.gz" "$T88/"
cp "$ROOT/t81-local.projeny" "$T88/w.projeny"
(cd "$T88" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T88/w.projeny" <<'PYEOF'
import sys
local = open(sys.argv[1]).read().split("\n")
up = open(sys.argv[2]).read().split("\n")
n = min(len(local), len(up))
i = 0
while i < n and local[i] == up[i]:
    i += 1
j0, j1 = len(local), len(up)
while j0 > i and j1 > i and local[j0 - 1] == up[j1 - 1]:
    j0 -= 1
    j1 -= 1
# rebase order: upstream content first (HEAD side), local content second.
blk = ["<<<<<<< HEAD"] + up[i:j1] + ["======="] + local[i:j0] + [">>>>>>> pick deadbeef local beta work"]
open(sys.argv[3], "w").write("\n".join(local[:i] + blk + local[j0:]))
PYEOF
out="$(cd "$T88" && "$PROJENY" setup w.projeny 2>&1)"
if [ $? -eq 0 ]; then
    ok "conflicted setup (rebase order) exits 0"
else
    fail "conflicted setup (rebase order) exits 0" "out: $out"
fi
if cmp -s "$T88/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "rebase-order markers still take upstream"
else
    fail "rebase-order markers still take upstream" "$(cat "$T88/w.projeny")"
fi
if cmp -s <(sed -n '/^--- projeny content ---$/,$p' "$T88/w.projeny.status" | tail -n +2) "$ROOT/t81-up.projeny" 2>/dev/null || cmp -s "$T88/w.projeny" <(sed -n '/^--- projeny content ---$/,$p' "$T88/w.projeny.status" | tail -n +2); then
    ok "rebase-order status embeds the upstream copy"
else
    fail "rebase-order status embeds the upstream copy" "$(head -8 "$T88/w.projeny.status")"
fi
expect_file_contains "rebase-order checkout has workdir markers" "$T88/w/a.c" "<<<<<<<"
expect_file_contains "rebase-order checkout keeps local side" "$T88/w/a.c" "beta LOCAL"
expect_file_contains "rebase-order checkout keeps upstream side" "$T88/w/a.c" "beta UPSTREAM"
expect_file_contains "rebase-order checkout records conflict" "$T88/w.projeny.status" "Conflict: a.c"
if echo "$out" | grep -qi "rebase"; then
    ok "rebase-order setup says which side it took"
else
    fail "rebase-order setup says which side it took" "out: $out"
fi
printf 'alpha 1\nbeta FIXED\ngamma 1\ndelta 1\n' > "$T88/w/a.c"
run_in "$T88" expect_ok "resolve after rebase-order setup" "$PROJENY" resolve w.projeny w/a.c
run_in "$T88" expect_ok "commit after rebase-order setup" "$PROJENY" commit w.projeny
expect_file_contains "rebase-order commit stores the fix" "$T88/w.projeny" "beta FIXED"

# ----------------------------------------- 85. stash-direction conflicted .projeny
# `git stash pop` labels the sides "Updated upstream" (checkout) and
# "Stashed changes" (local change); setup must take the checkout side.
T89="$ROOT/t89"
mkdir -p "$T89"
cp "$T81/w-1.0.tar.gz" "$T89/"
cp "$ROOT/t81-local.projeny" "$T89/w.projeny"
(cd "$T89" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T89/w.projeny" <<'PYEOF'
import sys
local = open(sys.argv[1]).read().split("\n")
up = open(sys.argv[2]).read().split("\n")
n = min(len(local), len(up))
i = 0
while i < n and local[i] == up[i]:
    i += 1
j0, j1 = len(local), len(up)
while j0 > i and j1 > i and local[j0 - 1] == up[j1 - 1]:
    j0 -= 1
    j1 -= 1
blk = ["<<<<<<< Updated upstream"] + up[i:j1] + ["======="] + local[i:j0] + [">>>>>>> Stashed changes"]
open(sys.argv[3], "w").write("\n".join(local[:i] + blk + local[j0:]))
PYEOF
out="$(cd "$T89" && "$PROJENY" setup w.projeny 2>&1)"
if [ $? -eq 0 ]; then
    ok "conflicted setup (stash labels) exits 0"
else
    fail "conflicted setup (stash labels) exits 0" "out: $out"
fi
if cmp -s "$T89/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "stash labels take the checkout (upstream) side"
else
    fail "stash labels take the checkout (upstream) side" "$(cat "$T89/w.projeny")"
fi
expect_file_contains "stash-label checkout has workdir markers" "$T89/w/a.c" "<<<<<<<"
expect_file_contains "stash-label checkout records conflict" "$T89/w.projeny.status" "Conflict: a.c"

# ----------------------------------------- 86. patch path traversal refused
# Patch member paths must never escape the tree (like tar members): absolute
# labels and any ".." component — including ones only visible after the
# a/b + workdir prefix strip (a/w/../../evil with wid w -> ../../evil) —
# are hard errors, refused before anything is written.
T90="$ROOT/t90"
mkdir -p "$T90/w-1.0"
printf 'hello\n' > "$T90/w-1.0/f.c"
(cd "$T90" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Traversal.\n' > "$T90/base.projeny"
cat >> "$T90/base.projeny" <<'EOF'

diff --git a/w/f.c b/w/f.c
--- a/w/f.c
+++ b/w/f.c
@@ -1 +1 @@
-hello
+hello world
EOF
make_traversal_projeny() {
    # $1=out, $2=plusplus-label: copy the benign patch, swap the +++ label.
    python3 - "$T90/base.projeny" "$1" "$2" <<'PYEOF'
import sys
s = open(sys.argv[1]).read().replace("+++ b/w/f.c", "+++ " + sys.argv[3])
open(sys.argv[2], "w").write(s)
PYEOF
}
make_traversal_projeny "$T90/widstrip.projeny" "b/w/../../escape1"
run_in "$T90" expect_fail "patch wid-strip ../ refused" "$PROJENY" setup widstrip.projeny
out="$(cd "$T90" && "$PROJENY" setup widstrip.projeny 2>&1 || true)"
case "$out" in
*traversal*)
    ok "wid-strip error names traversal"
    ;;
*)
    fail "wid-strip error names traversal" "out: $out"
    ;;
esac
make_traversal_projeny "$T90/abs.projeny" "b//etc/abs-escape"
run_in "$T90" expect_fail "patch absolute member refused" "$PROJENY" setup abs.projeny
make_traversal_projeny "$T90/plain.projeny" "../plain-escape"
run_in "$T90" expect_fail "patch plain ../ refused" "$PROJENY" setup plain.projeny
# rename traversal.
python3 - "$T90/base.projeny" "$T90/rename.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
s = s.replace("+++ b/w/f.c", "+++ b/w/g.c")
s = s.replace("diff --git a/w/f.c b/w/f.c", "diff --git a/w/f.c b/w/g.c\nrename from w/f.c\nrename to w/../../rename-escape")
open(sys.argv[2], "w").write(s)
PYEOF
run_in "$T90" expect_fail "patch rename ../ refused" "$PROJENY" setup rename.projeny
# direct `projeny patch` traversal (same parser, refused before applying).
mkdir -p "$T90/dir"
printf 'hello\n' > "$T90/dir/f.c"
cat > "$T90/evil.diff" <<'EOF'
diff --git a/dir/f.c b/dir/f.c
--- a/dir/f.c
+++ b/dir/../../patched-escape
@@ -1 +1 @@
-hello
+bye
EOF
run_in "$T90" expect_fail "projeny patch ../ refused" "$PROJENY" patch dir evil.diff
expect_file_contains "refused patch leaves the tree untouched" "$T90/dir/f.c" "hello"
if [ -e "$T90/escape1" ] || [ -e "$T90/../escape1" ] || [ -e "$T90/patched-escape" ] || [ -e "$ROOT/escape1" ] || [ -e "/tmp/escape1" ]; then
    fail "traversal planted no files outside the tree" "$(ls "$T90" 2>&1)"
else
    ok "traversal planted no files outside the tree"
fi
if [ -d "$T90/w" ]; then
    fail "refused setup creates no workdir" "$(ls "$T90/w" 2>&1)"
else
    ok "refused setup creates no workdir"
fi

# ----------------------------------------- 87. conflicted setup keeps state
# Previously recorded (unresolved) status conflicts are unioned into the new
# list, never silently dropped. A .projeny deleted on one side of the git
# conflict (and a missing .projeny file) gets recovery guidance, not a bare
# ENOENT/missing-header error.
T91="$ROOT/t91"
mkdir -p "$T91"
cp "$T81/w-1.0.tar.gz" "$T91/"
cp "$ROOT/t81-local.projeny" "$T91/w.projeny"
(cd "$T91" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$T91/w.projeny.status" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("Status: setup\n", "Status: setup\nConflict: stale/old.c\n")
open(p, "w").write(s)
PYEOF
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T91/w.projeny"
run_in "$T91" expect_ok "conflicted setup with stale conflicts exits 0" "$PROJENY" setup w.projeny
expect_file_contains "new conflict recorded" "$T91/w.projeny.status" "Conflict: a.c"
expect_file_contains "stale conflict kept (union)" "$T91/w.projeny.status" "Conflict: stale/old.c"
# deletion on one side: empty first side.
T92="$ROOT/t92"
mkdir -p "$T92"
cp "$T81/w-1.0.tar.gz" "$T92/"
python3 - "$ROOT/t81-local.projeny" "$T92/w.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
open(sys.argv[2], "w").write("<<<<<<< HEAD\n=======\n" + s + ">>>>>>> branch\n")
PYEOF
run_in "$T92" expect_fail "deleted-side conflict fails setup" "$PROJENY" setup w.projeny
out="$(cd "$T92" && "$PROJENY" setup w.projeny 2>&1 || true)"
case "$out" in
*deleted*checkout*)
    ok "deleted-side error guides recovery"
    ;;
*)
    fail "deleted-side error guides recovery" "out: $out"
    ;;
esac
# deletion on the other side: empty second side.
python3 - "$ROOT/t81-local.projeny" "$T92/w.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
open(sys.argv[2], "w").write("<<<<<<< HEAD\n" + s + "=======\n>>>>>>> branch\n")
PYEOF
run_in "$T92" expect_fail "other-side deletion fails setup" "$PROJENY" setup w.projeny
# missing .projeny file: recovery guidance, not bare ENOENT.
T93="$ROOT/t93"
mkdir -p "$T93"
run_in "$T93" expect_fail "missing .projeny fails setup" "$PROJENY" setup gone.projeny
out="$(cd "$T93" && "$PROJENY" setup gone.projeny 2>&1 || true)"
case "$out" in
*checkout*)
    ok "missing-file error guides recovery"
    ;;
*)
    fail "missing-file error guides recovery" "out: $out"
    ;;
esac

# ----------------------------------------- 88. prose/marker ambiguity
# Tool-written files never contain a column-0 prose line (commit prepends a
# single space when missing), so column-0 marker-shaped lines are always
# genuine git conflicts: indented marker-like prose roundtrips, a column-0
# marker-shaped prose line is refused with an indent hint, and column-0
# non-marker prose migrates on commit.
T94="$ROOT/t94"
mkdir -p "$T94"
cp "$T81/w-1.0.tar.gz" "$T94/"
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Prose with indented markers:\n     =======\n     <<<<<<< not a conflict\n     >>>>>>> nope\n' > "$T94/w.projeny"
run_in "$T94" expect_ok "indented marker-like prose sets up" "$PROJENY" setup w.projeny
python3 - "$T94/w/a.c" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("beta 1", "beta EDIT")
open(p, "w").write(s)
PYEOF
run_in "$T94" expect_ok "indented marker-like prose commits" "$PROJENY" commit w.projeny
expect_file_contains "indented prose survives commit" "$T94/w.projeny" "======="
run_in "$T94" expect_ok "indented prose still sets up" "$PROJENY" setup w.projeny
T95="$ROOT/t95"
mkdir -p "$T95"
cp "$T81/w-1.0.tar.gz" "$T95/"
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Prose then a trap:\n=======\n' > "$T95/w.projeny"
run_in "$T95" expect_fail "column-0 marker prose fails setup" "$PROJENY" setup w.projeny
out="$(cd "$T95" && "$PROJENY" setup w.projeny 2>&1 || true)"
case "$out" in
*indent*)
    ok "column-0 prose error hints at indenting"
    ;;
*)
    fail "column-0 prose error hints at indenting" "out: $out"
    ;;
esac
T96="$ROOT/t96"
mkdir -p "$T96"
cp "$T81/w-1.0.tar.gz" "$T96/"
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\ncol0 prose line\n' > "$T96/w.projeny"
run_in "$T96" expect_ok "column-0 non-marker prose sets up" "$PROJENY" setup w.projeny
run_in "$T96" expect_ok "column-0 non-marker prose commits" "$PROJENY" commit w.projeny
if grep -q "^ col0 prose line" "$T96/w.projeny"; then
    ok "commit migrates prose to leading-space indent"
else
    fail "commit migrates prose to leading-space indent" "$(cat "$T96/w.projeny")"
fi
run_in "$T96" expect_ok "migrated prose still sets up" "$PROJENY" setup w.projeny

# ----------------------------------------- 83. help topics
T87="$ROOT/t87"
mkdir -p "$T87"
for t in setup commit add rm mv resolve rebase status diff patch help; do
    out="$(cd "$T87" && "$PROJENY" help "$t" 2>&1)"
    if [ $? -eq 0 ] && [ -n "$out" ]; then
        ok "help $t exits 0 with text"
    else
        fail "help $t exits 0 with text" "out: $out"
    fi
done
for t in "setup:setup" "commit:commit" "patch:patch" "diff:diff" "rebase:rebase" "resolve:resolve" "status:status"; do
    topic="${t%%:*}"
    want="${t##*:}"
    if "$PROJENY" help "$topic" 2>&1 | grep -qi "$want"; then
        ok "help $topic mentions $want"
    else
        fail "help $topic mentions $want"
    fi
done
if "$PROJENY" help setup 2>&1 | grep -q "conflict"; then
    ok "help setup explains conflicts"
else
    fail "help setup explains conflicts"
fi
if "$PROJENY" help patch 2>&1 | grep -q "<<<<<<<"; then
    ok "help patch documents markers"
else
    fail "help patch documents markers"
fi
run_in "$T87" expect_fail "help bogus fails" "$PROJENY" help bogus
run_in "$T87" expect_ok "bare help still works" "$PROJENY" help

# ----------------------------------------- 89. rebase order without status
# Rebase-order markers (upstream first, local second) with no status file:
# the old code fell through to the merge default and kept the local file.
# The closer below is a realistic rebase label ("<sha> (<subject>)") whose
# subject contains "original" — a substring trap for naive matching
# ("origin" inside "original" would vote the wrong side; token matching
# must not fire there, while the commit-hash shape must vote rebase).
T97="$ROOT/t97"
mkdir -p "$T97"
cp "$T81/w-1.0.tar.gz" "$T97/"
cp "$ROOT/t81-local.projeny" "$T97/w.projeny"
(cd "$T97" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
rm -f "$T97/w.projeny.status"
python3 - "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T97/w.projeny" <<'PYEOF'
import sys
local = open(sys.argv[1]).read().split("\n")
up = open(sys.argv[2]).read().split("\n")
n = min(len(local), len(up))
i = 0
while i < n and local[i] == up[i]:
    i += 1
j0, j1 = len(local), len(up)
while j0 > i and j1 > i and local[j0 - 1] == up[j1 - 1]:
    j0 -= 1
    j1 -= 1
# rebase order: upstream content first (HEAD side), local content second,
# with a commit-hash closer whose subject hides an "origin" substring.
blk = ["<<<<<<< HEAD"] + up[i:j1] + ["======="] + local[i:j0] + [">>>>>>> 99d93bd (original work)"]
open(sys.argv[3], "w").write("\n".join(local[:i] + blk + local[j0:]))
PYEOF
out="$(cd "$T97" && "$PROJENY" setup w.projeny 2>&1)"
if [ $? -eq 0 ]; then
    ok "rebase-order setup without status exits 0"
else
    fail "rebase-order setup without status exits 0" "out: $out"
fi
if cmp -s "$T97/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "no-status rebase markers still take upstream"
else
    fail "no-status rebase markers still take upstream" "$(cat "$T97/w.projeny")"
fi
expect_file_contains "no-status rebase checkout has workdir markers" "$T97/w/a.c" "<<<<<<<"
expect_file_contains "no-status rebase checkout keeps local side" "$T97/w/a.c" "beta LOCAL"
expect_file_contains "no-status rebase checkout keeps upstream side" "$T97/w/a.c" "beta UPSTREAM"
expect_file_contains "no-status rebase checkout records conflict" "$T97/w.projeny.status" "Conflict: a.c"
if echo "$out" | grep -qi "rebase"; then
    ok "no-status rebase setup says which side it took"
else
    fail "no-status rebase setup says which side it took" "out: $out"
fi
# Stale status (embeds a lineage matching neither side) must not hijack
# the direction either: labels still decide.
T97S="$ROOT/t97s"
mkdir -p "$T97S"
cp "$T81/w-1.0.tar.gz" "$T97S/"
cp "$T97/w.projeny" "$T97S/w.projeny"
cp "$T97/w.projeny.status" "$T97S/w.projeny.status"
cp -r "$T97/w" "$T97S/w"
python3 - "$T97S/w.projeny.status" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read().replace("    G.\n", "    Stale lineage.\n")
open(p, "w").write(s)
PYEOF
run_in "$T97S" expect_ok "rebase-order setup with stale status exits 0" "$PROJENY" setup w.projeny
if cmp -s "$T97S/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "stale-status rebase markers still take upstream"
else
    fail "stale-status rebase markers still take upstream" "$(cat "$T97S/w.projeny")"
fi
# Merge order with a substring-trap branch name ("original-work" contains
# "origin" but its tokens are "original"/"work"): the label casts no vote,
# and the status copy breaks the tie, so the second side is still taken as
# upstream. (Without the status copy this shape must die as ambiguous.)
T97M="$ROOT/t97m"
mkdir -p "$T97M"
cp "$T81/w-1.0.tar.gz" "$T97M/"
cp "$ROOT/t81-local.projeny" "$T97M/w.projeny"
(cd "$T97M" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T97M/w.projeny" <<'PYEOF'
import sys
local = open(sys.argv[1]).read().split("\n")
up = open(sys.argv[2]).read().split("\n")
n = min(len(local), len(up))
i = 0
while i < n and local[i] == up[i]:
    i += 1
j0, j1 = len(local), len(up)
while j0 > i and j1 > i and local[j0 - 1] == up[j1 - 1]:
    j0 -= 1
    j1 -= 1
# merge order: local first, upstream second, closer is a branch name.
blk = ["<<<<<<< HEAD"] + local[i:j0] + ["======="] + up[i:j1] + [">>>>>>> original-work"]
open(sys.argv[3], "w").write("\n".join(local[:i] + blk + local[j0:]))
PYEOF
run_in "$T97M" expect_ok "substring-trap merge setup exits 0" "$PROJENY" setup w.projeny
if cmp -s "$T97M/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "substring-trap branch still takes upstream"
else
    fail "substring-trap branch still takes upstream" "$(cat "$T97M/w.projeny")"
fi

# ----------------------------------------- 89b. direction false-positive guards
# Voteless labels must never pick the swapped side on a normal merge: a
# 4-char hex closer ("cafe ...", "beef" — below git's 7+ short-SHA length),
# a stash-mentioning branch ("stash-cleanup" — no "stashed changes" phrase
# or stash pair), and a ref closer ("origin/master") must not vote swapped.
# With the status copy present the merge still resolves to the upstream
# side via the status tiebreak.
T97X="$ROOT/t97x"
mkdir -p "$T97X"
cp "$T81/w-1.0.tar.gz" "$T97X/"
for closer in "cafe (my feature)" "beef" "stash-cleanup" "origin/master"; do
    rm -rf "$T97X/w" "$T97X/w.projeny" "$T97X/w.projeny.status"
    cp "$ROOT/t81-local.projeny" "$T97X/w.projeny"
    (cd "$T97X" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
    python3 - "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T97X/w.projeny" "$closer" <<'PYEOF'
import sys
local = open(sys.argv[1]).read().split("\n")
up = open(sys.argv[2]).read().split("\n")
n = min(len(local), len(up))
i = 0
while i < n and local[i] == up[i]:
    i += 1
j0, j1 = len(local), len(up)
while j0 > i and j1 > i and local[j0 - 1] == up[j1 - 1]:
    j0 -= 1
    j1 -= 1
# merge order: local first, upstream second, closer carries no real signal.
blk = ["<<<<<<< HEAD"] + local[i:j0] + ["======="] + up[i:j1] + [">>>>>>> " + sys.argv[4]]
open(sys.argv[3], "w").write("\n".join(local[:i] + blk + local[j0:]))
PYEOF
    out="$(cd "$T97X" && "$PROJENY" setup w.projeny 2>&1)"
    if [ $? -eq 0 ]; then
        ok "merge with closer '$closer' exits 0"
    else
        fail "merge with closer '$closer' exits 0" "out: $out"
    fi
    if cmp -s "$T97X/w.projeny" "$ROOT/t81-up.projeny"; then
        ok "closer '$closer' still takes upstream"
    else
        fail "closer '$closer' still takes upstream" "$(cat "$T97X/w.projeny")"
    fi
    expect_file_contains "closer '$closer' records conflict" "$T97X/w.projeny.status" "Conflict: a.c"
done
# Truly ambiguous with no status and no deciding label: setup must die
# instead of silently defaulting to the merge side, leaving everything
# untouched.
T97Y="$ROOT/t97y"
mkdir -p "$T97Y"
cp "$T81/w-1.0.tar.gz" "$T97Y/"
cp "$ROOT/t81-local.projeny" "$T97Y/w.projeny"
(cd "$T97Y" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
cp "$T97Y/w/a.c" "$ROOT/t97y-a-before.c"
rm -f "$T97Y/w.projeny.status"
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T97Y/w.projeny"
run_in "$T97Y" expect_fail "ambiguous no-status conflict fails setup" "$PROJENY" setup w.projeny
out="$(cd "$T97Y" && "$PROJENY" setup w.projeny 2>&1 || true)"
case "$out" in
*ambiguous*)
    ok "ambiguous-direction error says ambiguous"
    ;;
*)
    fail "ambiguous-direction error says ambiguous" "out: $out"
    ;;
esac
if cmp -s "$T97Y/w/a.c" "$ROOT/t97y-a-before.c"; then
    ok "ambiguous setup leaves workdir untouched"
else
    fail "ambiguous setup leaves workdir untouched"
fi

# ----------------------------------------- 90. real git rebase / pull --rebase
if command -v git >/dev/null 2>&1; then
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_EDITOR=true
    # git rebase: local commit replayed onto upstream conflicts w.projeny.
    G98="$ROOT/t98"
    mkdir -p "$G98/repo"
    (cd "$G98/repo" && git init -q -b master . && mkdir w-1.0 && printf 'alpha 1\nbeta 1\ngamma 1\ndelta 1\n' > w-1.0/a.c && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0 && printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    G.\n' > w.projeny && "$PROJENY" setup w.projeny >/dev/null 2>&1 && git add w-1.0.tar.gz w.projeny && git commit -qm base)
    (cd "$G98/repo" && git checkout -qb upstream && python3 - w/a.c <<'PYEOF'
import sys
p = 'w/a.c'
s = open(p).read().replace("beta 1", "beta UPSTREAM")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git commit -qm upstream w.projeny)
    cp "$G98/repo/w.projeny" "$ROOT/t98-up.projeny"
    (cd "$G98/repo" && git checkout -q master && rm -rf w w.projeny.status && "$PROJENY" setup w.projeny >/dev/null 2>&1 && python3 - w/a.c <<'PYEOF'
import sys
p = 'w/a.c'
s = open(p).read().replace("beta 1", "beta LOCAL")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git commit -qm "local beta work" w.projeny)
    (cd "$G98/repo" && git rebase upstream >/dev/null 2>&1)
    if [ $? -ne 0 ] && grep -q "<<<<<<<" "$G98/repo/w.projeny"; then
        ok "git rebase conflicts the .projeny file"
    else
        fail "git rebase conflicts the .projeny file" "$(head -20 "$G98/repo/w.projeny" 2>&1)"
    fi
    out="$(cd "$G98/repo" && "$PROJENY" setup w.projeny 2>&1)"
    if [ $? -eq 0 ]; then
        ok "setup resolves real rebase markers"
    else
        fail "setup resolves real rebase markers" "out: $out"
    fi
    if cmp -s "$G98/repo/w.projeny" "$ROOT/t98-up.projeny"; then
        ok "real rebase takes upstream bytes"
    else
        fail "real rebase takes upstream bytes" "$(cat "$G98/repo/w.projeny")"
    fi
    expect_file_contains "real rebase marks beta conflict" "$G98/repo/w/a.c" "<<<<<<<"
    expect_file_contains "real rebase keeps local side" "$G98/repo/w/a.c" "beta LOCAL"
    expect_file_contains "real rebase keeps upstream side" "$G98/repo/w/a.c" "beta UPSTREAM"
    expect_file_contains "real rebase records conflict" "$G98/repo/w.projeny.status" "Conflict: a.c"
    (cd "$G98/repo" && printf 'alpha 1\nbeta MERGED\ngamma 1\ndelta 1\n' > w/a.c && "$PROJENY" resolve w.projeny w/a.c >/dev/null 2>&1 && "$PROJENY" commit w.projeny >/dev/null 2>&1 && git add w.projeny && git -c core.editor=true rebase --continue >/dev/null 2>&1)
    if [ $? -eq 0 ]; then
        ok "resolve+commit finishes the real rebase"
    else
        fail "resolve+commit finishes the real rebase"
    fi
    # git pull --rebase across a file remote: same marker family.
    R98="$ROOT/t98r"
    mkdir -p "$R98"
    (cd "$R98" && git init -q --bare remote.git && git clone -q remote.git local 2>/dev/null && cd local && mkdir w-1.0 && printf 'alpha 1\nbeta 1\ngamma 1\ndelta 1\n' > w-1.0/a.c && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0 && printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    G.\n' > w.projeny && "$PROJENY" setup w.projeny >/dev/null 2>&1 && git add w-1.0.tar.gz w.projeny && git commit -qm base && git push -q origin master)
    (cd "$R98" && git clone -q remote.git up 2>/dev/null && cd up && "$PROJENY" setup w.projeny >/dev/null 2>&1 && python3 - w/a.c <<'PYEOF'
import sys
p = 'w/a.c'
s = open(p).read().replace("beta 1", "beta UPSTREAM")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git commit -qam upstream && git push -q origin master)
    cp "$R98/up/w.projeny" "$ROOT/t98r-up.projeny"
    (cd "$R98/local" && python3 - w/a.c <<'PYEOF'
import sys
p = 'w/a.c'
s = open(p).read().replace("beta 1", "beta LOCAL")
open(p, "w").write(s)
PYEOF
    "$PROJENY" commit w.projeny >/dev/null 2>&1 && git commit -qam "my local work" && git pull --rebase -q origin master >/dev/null 2>&1)
    if grep -q "<<<<<<<" "$R98/local/w.projeny"; then
        ok "git pull --rebase conflicts the .projeny file"
    else
        fail "git pull --rebase conflicts the .projeny file" "$(head -20 "$R98/local/w.projeny" 2>&1)"
    fi
    out="$(cd "$R98/local" && "$PROJENY" setup w.projeny 2>&1)"
    if [ $? -eq 0 ]; then
        ok "setup resolves real pull --rebase markers"
    else
        fail "setup resolves real pull --rebase markers" "out: $out"
    fi
    if cmp -s "$R98/local/w.projeny" "$ROOT/t98r-up.projeny"; then
        ok "real pull --rebase takes upstream bytes"
    else
        fail "real pull --rebase takes upstream bytes" "$(cat "$R98/local/w.projeny")"
    fi
    expect_file_contains "real pull --rebase marks beta conflict" "$R98/local/w/a.c" "<<<<<<<"
    expect_file_contains "real pull --rebase records conflict" "$R98/local/w.projeny.status" "Conflict: a.c"
    (cd "$R98/local" && printf 'alpha 1\nbeta MERGED\ngamma 1\ndelta 1\n' > w/a.c && "$PROJENY" resolve w.projeny w/a.c >/dev/null 2>&1 && "$PROJENY" commit w.projeny >/dev/null 2>&1 && git add w.projeny && git -c core.editor=true rebase --continue >/dev/null 2>&1)
    if [ $? -eq 0 ]; then
        ok "resolve+commit finishes the real pull --rebase"
    else
        fail "resolve+commit finishes the real pull --rebase"
    fi
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_EDITOR
else
    ok "real rebase tests (skipped: no git)"
fi

# ----------------------------------------- 91. patch path traversal extras
# Wid-strip to the tree root itself ("b/w" with wid w, or "b/w/.") must be
# refused as traversal (it would otherwise target the tree directory), as
# must C-quoted rename escapes. Symlink ancestors must not be followed:
# with "link -> outside" in the target, a failing block for "link/evil"
# must stay a recorded conflict and plant nothing outside.
T99="$ROOT/t99"
mkdir -p "$T99/w-1.0"
printf 'hello\n' > "$T99/w-1.0/f.c"
(cd "$T99" && tar -czf w-1.0.tar.gz w-1.0 && rm -rf w-1.0)
printf 'Archive: w-1.0.tar.gz\nOrigname: w-1.0\nName: w\n\n    Traversal.\n' > "$T99/base.projeny"
cat >> "$T99/base.projeny" <<'EOF'

diff --git a/w/f.c b/w/f.c
--- a/w/f.c
+++ b/w/f.c
@@ -1 +1 @@
-hello
+hello world
EOF
python3 - "$T99/base.projeny" "$T99/empty.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read().replace("+++ b/w/f.c", "+++ b/w")
open(sys.argv[2], "w").write(s)
PYEOF
run_in "$T99" expect_fail "patch wid-strip-to-empty refused" "$PROJENY" setup empty.projeny
out="$(cd "$T99" && "$PROJENY" setup empty.projeny 2>&1 || true)"
case "$out" in
*traversal*)
    ok "wid-strip-to-empty error names traversal"
    ;;
*)
    fail "wid-strip-to-empty error names traversal" "out: $out"
    ;;
esac
python3 - "$T99/base.projeny" "$T99/dot.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read().replace("+++ b/w/f.c", "+++ b/w/.")
open(sys.argv[2], "w").write(s)
PYEOF
run_in "$T99" expect_fail "patch wid-strip-to-dot refused" "$PROJENY" setup dot.projeny
out="$(cd "$T99" && "$PROJENY" setup dot.projeny 2>&1 || true)"
case "$out" in
*traversal*)
    ok "wid-strip-to-dot error names traversal"
    ;;
*)
    fail "wid-strip-to-dot error names traversal" "out: $out"
    ;;
esac
# C-quoted rename escape ("w/../../rename-quoted" quoted git-style).
python3 - "$T99/base.projeny" "$T99/renameq.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
s = s.replace("+++ b/w/f.c", "+++ b/w/g.c")
s = s.replace("diff --git a/w/f.c b/w/f.c", "diff --git a/w/f.c b/w/g.c\nrename from w/f.c\nrename to \"w/../../rename-quoted\"")
open(sys.argv[2], "w").write(s)
PYEOF
run_in "$T99" expect_fail "patch quoted rename ../ refused" "$PROJENY" setup renameq.projeny
out="$(cd "$T99" && "$PROJENY" setup renameq.projeny 2>&1 || true)"
case "$out" in
*traversal*)
    ok "quoted-rename error names traversal"
    ;;
*)
    fail "quoted-rename error names traversal" "out: $out"
    ;;
esac
# Symlink ancestor: `projeny patch` on a dir holding "link -> outside".
mkdir -p "$T99/sym" "$T99/outside"
printf 'hello\n' > "$T99/sym/f.c"
ln -s "$T99/outside" "$T99/sym/link"
cat > "$T99/symlink.diff" <<'EOF'
diff --git a/sym/link/evil b/sym/link/evil
--- a/sym/link/evil
+++ b/sym/link/evil
@@ -1 +1 @@
-hello
+bye
EOF
out="$(cd "$T99" && "$PROJENY" patch sym symlink.diff 2>&1)"
if echo "$out" | grep -qi "conflict"; then
    ok "symlink-ancestor patch reports a conflict"
else
    fail "symlink-ancestor patch reports a conflict" "out: $out"
fi
if [ -e "$T99/outside/evil" ] || [ -e "$T99/sym/link/evil" ]; then
    fail "symlink-ancestor patch plants no files" "$(ls -la "$T99/outside" 2>&1)"
else
    ok "symlink-ancestor patch plants no files"
fi
expect_file_contains "symlink-ancestor patch leaves the tree untouched" "$T99/sym/f.c" "hello"
# Same, but the through-link file exists (failing hunk splice path): the
# outside file must keep its bytes instead of gaining markers.
printf 'outside bytes\n' > "$T99/outside/base.c"
cat > "$T99/symlink2.diff" <<'EOF'
diff --git a/sym/link/base.c b/sym/link/base.c
--- a/sym/link/base.c
+++ b/sym/link/base.c
@@ -1 +1 @@
-something else entirely
+changed
EOF
out="$(cd "$T99" && "$PROJENY" patch sym symlink2.diff 2>&1)"
if echo "$out" | grep -qi "conflict"; then
    ok "through-link failing hunk reports a conflict"
else
    fail "through-link failing hunk reports a conflict" "out: $out"
fi
expect_file_contains "through-link conflict leaves outside bytes alone" "$T99/outside/base.c" "outside bytes"
if grep -q "<<<<<<<" "$T99/outside/base.c"; then
    fail "through-link conflict writes no markers outside" "$(cat "$T99/outside/base.c")"
else
    ok "through-link conflict writes no markers outside"
fi

# ----------------------------------------- 91b. through-link non-create ops
# Delete/modify/chmod/rename patches touching link/evil (link -> outside)
# must fail as conflicts without touching anything outside the tree. Each
# patch below matches the outside bytes, so without the ancestor gate the
# op would apply cleanly straight through the link.
T99B="$ROOT/t99b"
mkdir -p "$T99B/sym" "$T99B/outside"
printf 'hello\n' > "$T99B/sym/f.c"
ln -s "$T99B/outside" "$T99B/sym/link"
printf 'doomed\n' > "$T99B/outside/evil"
printf 'keep me\n' > "$T99B/outside/cm"
chmod 644 "$T99B/outside/cm"
printf 'oldbytes\n' > "$T99B/outside/mv"
# delete with matching hunks: without the gate this unlinks outside/evil.
cat > "$T99B/del.diff" <<'EOF'
diff --git a/sym/link/evil b/sym/link/evil
deleted file mode 100644
--- a/sym/link/evil
+++ /dev/null
@@ -1 +0,0 @@
-doomed
EOF
out="$(cd "$T99B" && "$PROJENY" patch sym del.diff 2>&1)"
if echo "$out" | grep -qi "conflict"; then
    ok "through-link delete reports a conflict"
else
    fail "through-link delete reports a conflict" "out: $out"
fi
expect_file_contains "through-link delete leaves outside bytes alone" "$T99B/outside/evil" "doomed"
# modify with matching hunks: without the gate this rewrites outside/evil.
cat > "$T99B/mod.diff" <<'EOF'
diff --git a/sym/link/evil b/sym/link/evil
--- a/sym/link/evil
+++ b/sym/link/evil
@@ -1 +1 @@
-doomed
+changed
EOF
out="$(cd "$T99B" && "$PROJENY" patch sym mod.diff 2>&1)"
if echo "$out" | grep -qi "conflict"; then
    ok "through-link modify reports a conflict"
else
    fail "through-link modify reports a conflict" "out: $out"
fi
expect_file_contains "through-link modify leaves outside bytes alone" "$T99B/outside/evil" "doomed"
if grep -q "<<<<<<<" "$T99B/outside/evil"; then
    fail "through-link modify writes no markers outside" "$(cat "$T99B/outside/evil")"
else
    ok "through-link modify writes no markers outside"
fi
# chmod-only: without the gate this chmods outside/cm.
cat > "$T99B/chmod.diff" <<'EOF'
diff --git a/sym/link/cm b/sym/link/cm
old mode 100644
new mode 100755
--- a/sym/link/cm
+++ b/sym/link/cm
EOF
out="$(cd "$T99B" && "$PROJENY" patch sym chmod.diff 2>&1)"
if echo "$out" | grep -qi "conflict"; then
    ok "through-link chmod reports a conflict"
else
    fail "through-link chmod reports a conflict" "out: $out"
fi
expect_file_contains "through-link chmod leaves outside bytes alone" "$T99B/outside/cm" "keep me"
if [ -x "$T99B/outside/cm" ]; then
    fail "through-link chmod leaves outside mode alone" "$(stat -c %a "$T99B/outside/cm" 2>&1)"
else
    ok "through-link chmod leaves outside mode alone"
fi
# rename with hunks: without the gate this moves outside/mv to outside/mv2.
cat > "$T99B/mv.diff" <<'EOF'
diff --git a/sym/link/mv b/sym/link/mv2
similarity index 90%
rename from sym/link/mv
rename to sym/link/mv2
--- a/sym/link/mv
+++ b/sym/link/mv2
@@ -1 +1 @@
-oldbytes
+newbytes
EOF
out="$(cd "$T99B" && "$PROJENY" patch sym mv.diff 2>&1)"
if echo "$out" | grep -qi "conflict"; then
    ok "through-link rename reports a conflict"
else
    fail "through-link rename reports a conflict" "out: $out"
fi
expect_file_contains "through-link rename leaves outside bytes alone" "$T99B/outside/mv" "oldbytes"
if [ -e "$T99B/outside/mv2" ]; then
    fail "through-link rename plants no files outside" "$(ls -la "$T99B/outside" 2>&1)"
else
    ok "through-link rename plants no files outside"
fi
# pure rename: also a conflict, nothing planted outside, link intact.
cat > "$T99B/mvpure.diff" <<'EOF'
diff --git a/sym/link/mv b/sym/link/mv2
similarity index 100%
rename from sym/link/mv
rename to sym/link/mv2
EOF
out="$(cd "$T99B" && "$PROJENY" patch sym mvpure.diff 2>&1)"
if echo "$out" | grep -qi "conflict"; then
    ok "through-link pure rename reports a conflict"
else
    fail "through-link pure rename reports a conflict" "out: $out"
fi
expect_file_contains "through-link pure rename leaves outside bytes alone" "$T99B/outside/mv" "oldbytes"
if [ -e "$T99B/outside/mv2" ]; then
    fail "through-link pure rename plants no files outside" "$(ls -la "$T99B/outside" 2>&1)"
else
    ok "through-link pure rename plants no files outside"
fi
expect_file_contains "through-link ops leave the tree untouched" "$T99B/sym/f.c" "hello"
if [ -L "$T99B/sym/link" ]; then
    ok "through-link ops leave the link itself alone"
else
    fail "through-link ops leave the link itself alone" "$(ls -la "$T99B/sym" 2>&1)"
fi

# ----------------------------------------- 92. interrupted conflicted setup
# A crash between the conflicted-setup renames leaves a split brain (here:
# new .projeny + new .status with the markers gone, workdir missing). The
# setup journal makes it recoverable: rerunning setup must rebuild the
# conflicted checkout (not take the fresh path and discard the patch).
T100="$ROOT/t100"
mkdir -p "$T100"
cp "$T81/w-1.0.tar.gz" "$T100/"
cp "$ROOT/t81-local.projeny" "$T100/w.projeny"
(cd "$T100" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T100/w.projeny"
python3 - "$T100/w.projeny" "$T100/w.projeny.setup-journal" <<'PYEOF'
import sys
raw = open(sys.argv[1]).read()
journal = "projeny setup journal v1\nupstream: theirs\n--- conflicted .projeny ---\n" + raw
open(sys.argv[2], "w").write(journal)
PYEOF
# Simulate the crash: .projeny + .status already flipped to upstream, the
# merged workdir never landed.
cp "$ROOT/t81-up.projeny" "$T100/w.projeny"
python3 - "$ROOT/t81-up.projeny" "$T100/w.projeny.status" <<'PYEOF'
import sys
up = open(sys.argv[1]).read()
open(sys.argv[2], "w").write("Status: setup\nConflict: a.c\n--- projeny content ---\n" + up)
PYEOF
rm -rf "$T100/w"
out="$(cd "$T100" && "$PROJENY" setup w.projeny 2>&1)"
if [ $? -eq 0 ]; then
    ok "split-brain setup recovers exits 0"
else
    fail "split-brain setup recovers exits 0" "out: $out"
fi
if cmp -s "$T100/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "recovered setup keeps upstream bytes"
else
    fail "recovered setup keeps upstream bytes" "$(cat "$T100/w.projeny")"
fi
expect_file_contains "recovered checkout has workdir markers" "$T100/w/a.c" "<<<<<<<"
expect_file_contains "recovered checkout keeps local side" "$T100/w/a.c" "beta LOCAL"
expect_file_contains "recovered checkout keeps upstream side" "$T100/w/a.c" "beta UPSTREAM"
expect_file_contains "recovered checkout records conflict" "$T100/w.projeny.status" "Conflict: a.c"
if [ -e "$T100/w.projeny.setup-journal" ]; then
    fail "recovery removes the journal" "$(ls "$T100" 2>&1)"
else
    ok "recovery removes the journal"
fi
if echo "$out" | grep -qi "recover"; then
    ok "recovery says it recovered"
else
    fail "recovery says it recovered" "out: $out"
fi
if echo "$out" | grep -qi "rebase/stash-style"; then
    fail "merge-order recovery claims no rebase swap" "out: $out"
else
    ok "merge-order recovery claims no rebase swap"
fi
# Split brain plus drift: clean .projeny matching neither recorded side
# must fail loudly, never silently pick one.
T100B="$ROOT/t100b"
mkdir -p "$T100B"
cp "$T81/w-1.0.tar.gz" "$T100B/"
cp "$ROOT/t81-local.projeny" "$T100B/w.projeny"
(cd "$T100B" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
make_conflicted "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T100B/w.projeny"
python3 - "$T100B/w.projeny" "$T100B/w.projeny.setup-journal" <<'PYEOF'
import sys
raw = open(sys.argv[1]).read()
journal = "projeny setup journal v1\nupstream: theirs\n--- conflicted .projeny ---\n" + raw
open(sys.argv[2], "w").write(journal)
PYEOF
python3 - "$ROOT/t81-up.projeny" "$T100B/w.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read().replace("beta UPSTREAM", "beta DRIFTED")
open(sys.argv[2], "w").write(s)
PYEOF
run_in "$T100B" expect_fail "drifted split-brain fails setup" "$PROJENY" setup w.projeny
out="$(cd "$T100B" && "$PROJENY" setup w.projeny 2>&1 || true)"
case "$out" in
*journal*)
    ok "drifted split-brain error names the journal"
    ;;
*)
    fail "drifted split-brain error names the journal" "out: $out"
    ;;
esac

# ----------------------------------------- 93. extended conflict markers
# Nested-conflict style markers (8+ characters) must be detected like the
# plain 7-char form: an all-extended block resolves, while a genuinely
# nested block (outer 8 + inner 7) fails loudly instead of being silently
# treated as clean.
T101="$ROOT/t101"
mkdir -p "$T101"
cp "$T81/w-1.0.tar.gz" "$T101/"
cp "$ROOT/t81-local.projeny" "$T101/w.projeny"
(cd "$T101" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$ROOT/t81-local.projeny" "$ROOT/t81-up.projeny" "$T101/w.projeny" <<'PYEOF'
import sys
local = open(sys.argv[1]).read().split("\n")
up = open(sys.argv[2]).read().split("\n")
n = min(len(local), len(up))
i = 0
while i < n and local[i] == up[i]:
    i += 1
j0, j1 = len(local), len(up)
while j0 > i and j1 > i and local[j0 - 1] == up[j1 - 1]:
    j0 -= 1
    j1 -= 1
# merge order with 8-char markers throughout.
blk = ["<<<<<<<< HEAD"] + local[i:j0] + ["========"] + up[i:j1] + [">>>>>>>> branch"]
open(sys.argv[3], "w").write("\n".join(local[:i] + blk + local[j0:]))
PYEOF
run_in "$T101" expect_ok "extended-marker setup exits 0" "$PROJENY" setup w.projeny
if cmp -s "$T101/w.projeny" "$ROOT/t81-up.projeny"; then
    ok "extended markers still take upstream"
else
    fail "extended markers still take upstream" "$(cat "$T101/w.projeny")"
fi
expect_file_contains "extended-marker checkout has workdir markers" "$T101/w/a.c" "<<<<<<<"
expect_file_contains "extended-marker checkout records conflict" "$T101/w.projeny.status" "Conflict: a.c"
# Nested markers cannot be split: refuse with guidance, never silently.
T101N="$ROOT/t101n"
mkdir -p "$T101N"
cp "$T81/w-1.0.tar.gz" "$T101N/"
cp "$ROOT/t81-local.projeny" "$T101N/w.projeny"
(cd "$T101N" && "$PROJENY" setup w.projeny >/dev/null 2>&1)
python3 - "$ROOT/t81-local.projeny" "$T101N/w.projeny" <<'PYEOF'
import sys
s = open(sys.argv[1]).read()
trap = "<<<<<<<< outer\nlocal line\n<<<<<<< inner\ninner ours\n=======\ninner theirs\n>>>>>>> inner\n========\nupstream line\n>>>>>>>> outer\n"
open(sys.argv[2], "w").write(s + trap)
PYEOF
run_in "$T101N" expect_fail "nested markers fail setup" "$PROJENY" setup w.projeny
out="$(cd "$T101N" && "$PROJENY" setup w.projeny 2>&1 || true)"
case "$out" in
*nested*)
    ok "nested-marker error names nesting"
    ;;
*)
    fail "nested-marker error names nesting" "out: $out"
    ;;
esac

# ------------------------------------------------------------- summary
echo "---"
echo "passed: $PASS, failed: $FAIL"
rm -rf "$ROOT"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
exit 0
