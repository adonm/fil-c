#!/bin/sh
# Docker-side: assemble sarcasm output (tests/gen/*.s) and run behavioral + safety checks.
B=../../build/bin/clang
$B -O2 -c tests/foo.c -o tests/gen/foo.o
ck() { if [ "$2" = "$3" ]; then echo "  ok: $1"; else echo "  FAIL: $1 (want '$2' got '$3')"; fi; }
traps() { L="$1"; shift; if "$@" >/dev/null 2>&1; then echo "  FAIL: $L (no trap)"; else echo "  ok: $L traps"; fi; }
A() { as "tests/gen/$1.s" -o "tests/gen/$1.o"; }

A t1;  $B -o tests/gen/e tests/mainhash.c tests/gen/t1.o
ck "t1 hash(hello)" "210714636441" "$(tests/gen/e | sed -n 1p)"
ck "t1 hash(empty)" "5381" "$(tests/gen/e | sed -n 2p)"
A t2;  $B -o tests/gen/e tests/mh2b.c tests/gen/t2.o
ck "t2 hi/2" "hi/2    = 5863446" "$(tests/gen/e | sed -n 2p)"
A t3;  $B -o tests/gen/e tests/mainhash3.c tests/gen/t3.o tests/gen/foo.o
ck "t3 hello/5" "hello/5 = 210714636441" "$(tests/gen/e | sed -n 1p)"
A t30; $B -o tests/gen/e tests/mainhash3.c tests/gen/t30.o tests/gen/foo.o
ck "t30 hello/5" "hello/5 = 210714636441" "$(tests/gen/e | sed -n 1p)"

echo "-- new features --"
A store;   $B -o tests/gen/e tests/store-main.c tests/gen/store.o
ck "store_ptr round-trips capability" "12345" "$(tests/gen/e | sed -n 1p)"
A regidx;  $B -o tests/gen/e tests/regidx-main.c tests/gen/regidx.o
ck "register-indexed get" "104 101 111" "$(tests/gen/e | sed -n 1p)"
A nullcap; $B -o tests/gen/e tests/nullcap-main.c tests/gen/nullcap.o
A ptrret;  $B -o tests/gen/e tests/ptrret-main.c tests/gen/ptrret.o
ck "pointer return preserves capability" "42" "$(tests/gen/e | sed -n 1p)"

echo "-- memory-safety traps --"
$B -o tests/gen/e tests/regidx-oob.c tests/gen/regidx.o; traps "access bounds check (regidx OOB)" tests/gen/e
$B -o tests/gen/e tests/nullcap-main.c tests/gen/nullcap.o; traps "null-capability deref" tests/gen/e
A nullret; $B -o tests/gen/e tests/nullret-main.c tests/gen/nullret.o; traps "null-cap pointer return deref" tests/gen/e

echo "-- inserted runtime calls fire (behavioral) --"
A recurse; $B -o tests/gen/e tests/recurse-main.c tests/gen/recurse.o; traps "stack-overflow check (deep recursion)" tests/gen/e
$B -o tests/gen/e tests/ro-store-main.c tests/gen/store.o; traps "read-only object store reject" tests/gen/e

echo "-- operand-rendering regressions --"
A mk; $B -o tests/gen/e tests/mk-main.c tests/gen/mk.o
ck "movk shifted-immediate constant preserved" "198503143" "$(tests/gen/e | sed -n 1p)"
A zx; $B -o tests/gen/e tests/zx-main.c tests/gen/zx.o
ck "32-bit self-move keeps zero-extension" "0" "$(tests/gen/e | sed -n 1p)"
# large/complex leaf functions: gcc reuses x30 (lr) as a GPR and spills it to the stack;
# those spills must be virtualized, not dropped as fp/lr saves.
A med; $B -o tests/gen/e tests/medium-main.c tests/gen/med.o
ck "medium (700-line leaf, heavy spilling)" "16197551685056770395" "$(tests/gen/e | sed -n 1p)"
A big; $B -o tests/gen/e tests/big-main.c tests/gen/big.o
ck "large (2600-line leaf, x30-as-GPR spills)" "2371022172632653116" "$(tests/gen/e | sed -n 1p)"

echo "-- register spilling --"
A spill; $B -o tests/gen/e tests/spill-main.c tests/gen/spill.o
ck "spilled function computes correctly" "351" "$(tests/gen/e | sed -n 1p)"
$B -o tests/gen/e tests/spill-oob-main.c tests/gen/spill.o; traps "access check still enforced in spilled code" tests/gen/e

echo "-- stack allocations (alloca -> filc_allocate) --"
for a in alloca-spasm alloca-O0-spasm stackbuf-spasm stackbuf-O0-spasm stackbufs-spasm stackbufs-O0-spasm; do
  A "$a"
  $B -o tests/gen/e tests/copy-ok-main.c tests/gen/$a.o
  ck "$a: copy through allocation" "ok" "$(tests/gen/e | sed -n 1p)"
  $B -o tests/gen/e tests/copy-oob-main.c tests/gen/$a.o; traps "$a: allocation access bounds-checked" tests/gen/e
done

echo "-- debug info (-g) --"
# with -g, a runtime trap reports the input .s source location; without -g it does not.
A t2g;   $B -o tests/gen/eg  tests/hash-oob-main.c tests/gen/t2g.o
A t2nog; $B -o tests/gen/eng tests/hash-oob-main.c tests/gen/t2nog.o
gloc="$(tests/gen/eg 2>&1 | grep -o 'test2-spasm\.s:[0-9]*' | head -1)"
if [ -n "$gloc" ]; then echo "  ok: -g trap reports source location ($gloc)"; else echo "  FAIL: -g trap has no source location"; fi
if tests/gen/eng 2>&1 | grep -q 'test2-spasm\.s:[0-9]'; then echo "  FAIL: non-g trap unexpectedly has a source location"; else echo "  ok: non-g trap has no source location"; fi
$B -o tests/gen/e tests/oob3.c tests/gen/t3.o tests/gen/foo.o; traps "t3 call OOB" tests/gen/e
as tests/gen/t3.s -o tests/gen/t3.o
$B -O2 -c tests/foo.c -o tests/gen/foo2.o
objcopy --localize-symbol pizlonatedFI2529_foo tests/gen/foo2.o tests/gen/foo2L.o
$B -o tests/gen/er tests/mainhash3.c tests/gen/t3.o tests/gen/foo2L.o
ck "callsite resolver direct-calls" "hello/5 = 210714636441" "$(tests/gen/er | sed -n 1p)"
