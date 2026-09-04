#!/bin/sh
# projeny test suite: fixture-based shell tests over tiny fake-project
# tarballs v1/v2. Covers fresh setup, edit+commit roundtrips, setup-again
# noops, divergent merges (clean + conflicting), add/rm/mv + commit,
# rebase (clean + conflict), and the hard-error paths.
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


# ------------------------------------------------------------- summary
echo "---"
echo "passed: $PASS, failed: $FAIL"
rm -rf "$ROOT"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
exit 0
