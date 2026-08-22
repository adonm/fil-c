#!/bin/sh
# Assemble sarcasm output (tests/gen/*.s) with GNU `as`, link with Fil-C mains, run,
# and verify results + OOB traps. Run inside the docker container from the repo dir.
B=../../build/bin/clang
$B -O2 -c tests/foo.c -o tests/gen/foo.o
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "  ok: $1"; pass=$((pass+1)); else echo "  FAIL: $1 (want '$2' got '$3')"; fail=$((fail+1)); fi; }
asm() { as "tests/gen/$1.s" -o "tests/gen/$1.o" && echo "  assembled $1 with GNU as"; }

asm t1;  $B -o tests/gen/e1 tests/mainhash.c tests/gen/t1.o
check "t1 hash(hello)" "210714636441" "$(tests/gen/e1 | sed -n 1p)"
check "t1 hash(empty)" "5381" "$(tests/gen/e1 | sed -n 2p)"

asm t2;  $B -o tests/gen/e2 tests/mh2b.c tests/gen/t2.o
check "t2 hello/5" "hello/5 = 210714636441" "$(tests/gen/e2 | sed -n 1p)"
check "t2 hi/2"    "hi/2    = 5863446"      "$(tests/gen/e2 | sed -n 2p)"
check "t2 empty/0" "empty/0 = 5381"         "$(tests/gen/e2 | sed -n 3p)"

asm t3;  $B -o tests/gen/e3 tests/mainhash3.c tests/gen/t3.o tests/gen/foo.o
check "t3 hello/5" "hello/5 = 210714636441" "$(tests/gen/e3 | sed -n 1p)"
check "t3 empty/0" "empty/0 = 5381"         "$(tests/gen/e3 | sed -n 2p)"

asm t30; $B -o tests/gen/e30 tests/mainhash3.c tests/gen/t30.o tests/gen/foo.o
check "t30 hello/5" "hello/5 = 210714636441" "$(tests/gen/e30 | sed -n 1p)"
check "t30 empty/0" "empty/0 = 5381"         "$(tests/gen/e30 | sed -n 2p)"

echo "OOB safety (must trap):"
for t in t3 t30; do
  $B -o tests/gen/eoob tests/oob3.c tests/gen/$t.o tests/gen/foo.o
  if tests/gen/eoob >/dev/null 2>&1; then echo "  FAIL: $t no trap"; fail=$((fail+1)); else echo "  ok: $t traps on OOB"; pass=$((pass+1)); fi
done
echo "RESULT: $pass passed, $fail failed"
rm -f tests/gen/e1 tests/gen/e2 tests/gen/e3 tests/gen/e30 tests/gen/eoob
