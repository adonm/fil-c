#!/bin/sh
# Full x86_64 verification (mirrors tests/verify.sh for ARM64, and then some). Run from the
# repo root on the host: sarcasm runs via lute here, and the Fil-C x86_64 clang assembles /
# links / runs via the x86_64 docker container. Because x86 has two input syntaxes, every
# behavioral case is exercised in BOTH AT&T and Intel — so this suite is strictly larger
# than the ARM64 one. Covers: auto-detection, dual-syntax parsing, behavioral correctness,
# memory-safety traps, inserted-check presence (structural), and compile-time rejections.
CC=./filc-0.683-linux-x86_64/build/bin/clang
DOCKER="docker exec 0a4cf2979a2d"
mkdir -p tests/genx
pass=0; fail=0

gen() { ./sarcasm.sh $3 -S -o "tests/genx/$2" "$1" || { echo "  FAIL: sarcasm $1"; fail=$((fail+1)); }; }
# has FILE PATTERN LABEL : generated tests/genx/FILE must contain PATTERN
has() { if grep -qE "$2" "tests/genx/$1"; then echo "  ok: $3"; pass=$((pass+1));
  else echo "  FAIL: $3 (/$2/ not in $1)"; fail=$((fail+1)); fi; }
# reject FILE SUBSTR : sarcasm must reject FILE with a clean message containing SUBSTR
reject() { out="$(./sarcasm.sh -S -o /dev/null "$1" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then echo "  FAIL: $1 not rejected"; fail=$((fail+1));
  elif echo "$out" | grep -q "sarcasm:.*$2"; then echo "  ok: rejects $(basename $1) ($2)"; pass=$((pass+1));
  else echo "  FAIL: $1 lacked '$2': $out"; fail=$((fail+1)); fi; }
# ckrun NAME ASM EXPECT MAINS... : assemble+link+run, expect EXPECT as a substring of output
ckrun() { name="$1"; asm="$2"; want="$3"; shift 3
  $DOCKER sh -c "cd $(pwd); $CC -c tests/genx/$asm -o tests/genx/$name.o 2>&1|head -2; $CC -o tests/genx/$name tests/genx/$name.o $* 2>&1|head -2; tests/genx/$name 2>&1" > tests/genx/o.$name 2>&1
  if grep -q "$want" tests/genx/o.$name; then echo "  ok: $name ($want)"; pass=$((pass+1));
  else echo "  FAIL: $name wanted '$want':"; sed 's/^/     /' tests/genx/o.$name|head -3; fail=$((fail+1)); fi; }
# cktrap NAME ASM MAINS... : must trap (Fil-C safety error / non-zero), not print the guard line
cktrap() { name="$1"; asm="$2"; shift 2
  $DOCKER sh -c "cd $(pwd); $CC -c tests/genx/$asm -o tests/genx/$name.o 2>&1|head -2; $CC -o tests/genx/$name tests/genx/$name.o $* 2>&1|head -2; tests/genx/$name 2>&1" > tests/genx/o.$name 2>&1
  if grep -qiE 'filc safety error|SHOULD NOT PRINT' tests/genx/o.$name && ! grep -q 'SHOULD NOT PRINT' tests/genx/o.$name; then
    echo "  ok: $name traps"; pass=$((pass+1))
  elif grep -qi 'filc safety error' tests/genx/o.$name; then echo "  ok: $name traps"; pass=$((pass+1))
  else echo "  FAIL: $name did not trap:"; sed 's/^/     /' tests/genx/o.$name|head -3; fail=$((fail+1)); fi; }

echo "== generating (sarcasm, x86 — AT&T and Intel) =="
gen tests/test-spasm-x86.s        hash-att.s
gen tests/test-spasm-x86-intel.s  hash-int.s
gen tests/test2-x86-att.s         t2-att.s
gen tests/test2-x86-intel.s       t2-int.s
gen tests/test3-spasm-x86.s       t3-att.s
gen tests/test3-x86-intel.s       t3-int.s
gen tests/regidx-x86-att.s        regidx-att.s
gen tests/regidx-x86-intel.s      regidx-int.s
gen tests/store-spasm-x86.s       store-att.s
gen tests/store-x86-intel.s       store-int.s
gen tests/ptrret-spasm-x86.s      ptrret-att.s
gen tests/ptrret-x86-intel.s      ptrret-int.s
gen tests/nullcap-spasm-x86.s     nullcap-att.s
gen tests/nullcap-x86-intel.s     nullcap-int.s
gen tests/nullret-x86-att.s       nullret-att.s
gen tests/nullret-x86-intel.s     nullret-int.s
gen tests/recurse-x86-att.s       recurse-att.s
gen tests/recurse-x86-intel.s     recurse-int.s
gen tests/spill-spasm-x86.s       spill-att.s
gen tests/spill-x86-intel.s       spill-int.s
gen tests/alloca-spasm-x86.s      alloca-att.s
gen tests/alloca-x86-intel.s      alloca-int.s
gen tests/stackbuf-x86-att.s      sbuf-att.s
gen tests/stackbuf-x86-intel.s    sbuf-int.s
# regression: non-`mov` stack-slot reload (movzwl) + rbp used as a general GPR (no frame
# pointer) — both used to make frame_x86 error on medium-x86_64.s.
gen tests/slotw-x86-att.s         slotw-att.s
gen tests/slotw-x86-intel.s       slotw-int.s
gen tests/zeroext-x86-att.s       zx-att.s
gen tests/zeroext-x86-intel.s     zx-int.s
gen tests/medium-x86.s            med-x86.s
gen tests/large-x86.s             big-x86.s
gen tests/rbpgpr-x86-att.s        rbpgpr-att.s
gen tests/rbpgpr-x86-intel.s      rbpgpr-int.s

echo "== unit: auto-detection + dual-syntax parser =="
dout="$(lute tests/detect-test.luau 2>&1)"; echo "$dout" | grep -E '^  (ok|FAIL):'
pass=$((pass + $(echo "$dout" | grep -c '^  ok:'))); fail=$((fail + $(echo "$dout" | grep -c '^  FAIL:')))
echo "== unit: spill reload-elimination cleanup =="
cout="$(lute tests/cleanup-test.luau 2>&1)"; echo "$cout" | grep -E '^  (ok|FAIL):'
pass=$((pass + $(echo "$cout" | grep -c '^  ok:'))); fail=$((fail + $(echo "$cout" | grep -c '^  FAIL:')))

echo "== inserted checks / runtime calls present (structural, AT&T output) =="
has hash-att.s "cmpq\t%rsp, \(%rdi\)"                  "stack-overflow compare inserted"
has hash-att.s "jae\tfilc_stack_overflow_failure"      "stack-overflow branch inserted"
has hash-att.s "filc_optimized_access_check_fail"      "bounds/null access check inserted"
has hash-att.s "movzbl\t8\("                           "pollcheck flag load inserted (loop)"
has hash-att.s "testl\t\\\$14, %e"                       "pollcheck flag test inserted (loop)"
has hash-att.s "filc_pollcheck_slow"                   "pollcheck slow-call inserted (loop)"
has hash-att.s "filc_cc_args_check_failure"            "generic-thunk arg-size check inserted"
echo "== structural on Intel-derived output (proves syntax-independent instrumentation) =="
has hash-int.s "filc_optimized_access_check_fail"      "access check inserted (from Intel input)"
has hash-int.s "filc_pollcheck_slow"                   "pollcheck inserted (from Intel input)"
has store-att.s "filc_current_marking_state@GOTPCREL"  "store barrier marking-state load inserted"
has store-att.s "filc_store_barrier_for_lower_slow"    "store barrier slow-call inserted"
has store-att.s "filc_object_ensure_aux_ptr_outline"   "aux-array allocation call inserted"
has store-att.s "0x6000000000000"                      "read-only/special object reject inserted"
has t3-att.s   "testb\t\\\$1, %al"                       "call exception-propagation check inserted"
has t3-att.s   "filc_check_function_call_fail"         "callsite resolver function-check fail inserted"
has t3-att.s   "filc_cc_rets_check_failure"            "callsite resolver return-size check inserted"
has spill-att.s "[0-9]+\(%rsp\), %r"                   "register spilling engaged (reloads from stack slots)"
has alloca-att.s "filc_allocate"                       "alloca lowered to a filc_allocate GC allocation"
has sbuf-att.s "\\\$400, %rsi"                          "fixed-size alloca uses its declared byte size"
# spill-slot packing: the 13-value sum spills ~16 temps, but their live ranges are colored
# so non-overlapping slots share offsets. A regression to unique-slot-per-spill would grow
# the frame well past this (offsets ran to 144 before packing); packed it stays compact.
spframe=$(grep -oE "subq	\\\$[0-9]+, %rsp" tests/genx/spill-att.s | grep -oE "[0-9]+" | head -1)
if [ -n "$spframe" ] && [ "$spframe" -le 128 ]; then
  echo "  ok: spill slots packed by liveness (frame ${spframe}B <= 128)"; pass=$((pass+1))
else echo "  FAIL: spill slots not packed (frame ${spframe}B)"; fail=$((fail+1)); fi

echo "== compile-time rejections (x86) =="
reject tests/nosig-x86.s                "has no ;! signature annotation"
reject tests/reject-badsig-x86.s        "cannot parse function signature"
reject tests/reject-badsig-x86-intel.s  "cannot parse function signature"
reject tests/reject-too-many-args-x86.s ">3 register args"
reject tests/reject-alloca-dupsize-x86.s "duplicate .alloca size"
reject tests/reject-alloca-nosize-x86.s "has no preceding .alloca size"
reject tests/reject-stack-addr-x86.s    "taking address of stack frame"

echo "== behavioral: correctness (AT&T and Intel) =="
ckrun hash-att   hash-att.s   "210714636441" tests/mainhash.c
ckrun hash-int   hash-int.s   "210714636441" tests/mainhash.c
ckrun t2-att     t2-att.s     "hello/5 = 210714636441" tests/mh2b.c
ckrun t2-int     t2-int.s     "empty/0 = 5381"          tests/mh2b.c
ckrun t3-att     t3-att.s     "210714636441" tests/t3valid-main.c tests/foo.c
ckrun t3-int     t3-int.s     "210714636441" tests/t3valid-main.c tests/foo.c
ckrun regidx-att regidx-att.s "104 101 111" tests/regidx-main.c
ckrun regidx-int regidx-int.s "104 101 111" tests/regidx-main.c
ckrun store-att  store-att.s  "12345" tests/store-main.c
ckrun store-int  store-int.s  "12345" tests/store-main.c
ckrun ptrret-att ptrret-att.s "42" tests/ptrret-main.c
ckrun ptrret-int ptrret-int.s "42" tests/ptrret-main.c
ckrun spill-att  spill-att.s  "91" tests/spill-main-x86.c
ckrun spill-int  spill-int.s  "91" tests/spill-main-x86.c
ckrun alloca-att alloca-att.s "ok" tests/copy-ok-main.c
ckrun alloca-int alloca-int.s "ok" tests/copy-ok-main.c
ckrun sbuf-att   sbuf-att.s   "ok" tests/copy-ok-main.c
ckrun sbuf-int   sbuf-int.s   "ok" tests/copy-ok-main.c
ckrun slotw-att  slotw-att.s  "22136" tests/slotw-main.c   # 64-bit store, movzwl 16-bit reload
ckrun slotw-int  slotw-int.s  "22136" tests/slotw-main.c
ckrun zx-att     zx-att.s     "0" tests/zx-main.c           # movl %eax,%eax must zero-extend
ckrun zx-int     zx-int.s     "0" tests/zx-main.c
ckrun medium-x86 med-x86.s    "16197551685056770395" tests/medium-main.c
ckrun big-x86    big-x86.s     "2371022172632653116"  tests/big-main.c
ckrun rbpgpr-att rbpgpr-att.s "101"   tests/rbpgpr-main.c  # rbp as GPR + lea ptr arithmetic
ckrun rbpgpr-int rbpgpr-int.s "101"   tests/rbpgpr-main.c

echo "== behavioral: memory-safety traps (AT&T and Intel) =="
cktrap hashoob-att   hash-att.s   tests/oobpage-main.c
cktrap hashoob-int   hash-int.s   tests/oobpage-main.c
cktrap t3oob-att     t3-att.s     tests/t3oob-main.c tests/foo.c
cktrap t3oob-int     t3-int.s     tests/t3oob-main.c tests/foo.c
cktrap regidxoob-att regidx-att.s tests/regidx-oob.c
cktrap regidxoob-int regidx-int.s tests/regidx-oob.c
cktrap nullcap-att   nullcap-att.s tests/nullcap-main.c
cktrap nullcap-int   nullcap-int.s tests/nullcap-main.c
cktrap nullret-att   nullret-att.s tests/nullret-main.c
cktrap nullret-int   nullret-int.s tests/nullret-main.c
cktrap rostore-att   store-att.s  tests/ro-store-main.c
cktrap rostore-int   store-int.s  tests/ro-store-main.c
cktrap recurse-att   recurse-att.s tests/recurse-main.c
cktrap recurse-int   recurse-int.s tests/recurse-main.c
cktrap spilloob-att  spill-att.s  tests/spill-oob-main-x86.c
cktrap spilloob-int  spill-int.s  tests/spill-oob-main-x86.c
cktrap allocaoob-att alloca-att.s tests/copy-oob-main.c
cktrap allocaoob-int alloca-int.s tests/copy-oob-main.c
cktrap sbufoob-att   sbuf-att.s   tests/copy-oob-main.c
cktrap sbufoob-int   sbuf-int.s   tests/copy-oob-main.c

rm -rf tests/genx
echo "TOTAL(x86): $pass passed, $fail failed"
[ "$fail" = 0 ]
