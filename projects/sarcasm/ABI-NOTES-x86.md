# Fil-C 0.683 x86_64 ABI notes (decoded from clang output)

The ABI *concepts* are identical to ARM64 (see ABI-NOTES.md): invisicap (intval,lower),
object header at [lower-16]=upper / [lower-8]=aux, myth offsets ([+0]=stack limit,
[+8]=flags, [+16]=top frame, [+128]=CC payload buffer, [+384]=CC aux buffer), filc_frame
{prev, origin, roots}, signature encoding, FO layout, 0x83<<48 function flags. Only the
registers and instructions differ.

## Register calling convention (fast entrypoint / direct call)
- `%rdi` = myth, `%rsi` = function object (FO payload ptr).
- args: packed DENSELY into `%rdx`,`%rcx`,`%r8`,`%r9` — a pointer-class arg occupies two
  consecutive registers (intval, lower), a scalar-class arg one (intval only). E.g.
  `(ptr, size_t, size_t)` = arg0 in rdx/rcx, arg1 in r8, arg2 in r9. Arguments beyond
  the fourth word are passed on the stack (verified against clang output: a 3rd pointer
  arg arrives at 8+16N(%rsp) after the callee's frame). sarcasm does not marshal stack
  arguments and rejects signatures needing more than 4 register argument words.
- return: `%al` bit0 = exception flag; `%rdx` = ret intval; `%rcx` = ret lower.

## Floating-point ABI (decoded from `build/bin/clang -S` output)
FP-class arguments travel in a SEPARATE xmm sequence, independent of the dense GPR
packing: the first float/double arg goes in `%xmm0`, the second in `%xmm1`, and so
on, while int/pointer args pack densely into `%rdx`,`%rcx`,`%r8`,`%r9` as above.
Verified with `double(double,double,long,double,ptr,float)`: the four FP args land
in xmm0..xmm3 while the long goes to rdx and the pointer to rcx/r8. A float/double
result is returned in `%xmm0`. `long double` (x87 80-bit) never touches xmm: it is
passed ON THE STACK (the callee does `fldt 8(%rsp)` / `fldt 24(%rsp)`) and returned
in `st(0)`.

In the generic (buffer) calling convention every argument occupies one 8-byte word
at `myth+128+8*i` regardless of class — float/double args included (loaded/stored
with `movss`/`movsd`; pointer args keep their lower in the aux buffer at
`myth+384+8*i` as usual). Exception: a `long double` argument occupies a 16-byte
slot (loaded with `fldt`; the 2ET thunk re-marshals it onto the stack for the fast
entrypoint with `fstpt`). The FP result is stored to `128(%rbx)` with a zero lower
word at `384(%rbx)` — `movsd %xmm0, 128(%rbx); movq $0, 384(%rbx)` for double;
`fstpt 128(%rbx)` plus zeroed padding and a zeroed 16-byte aux word for
`long double`.

sarcasm still REJECTS FP/vector type classes in `;!` signatures (entry and
callsite alike) — this decode is the groundwork for future FP-signature support;
the remaining work is the marshalling (entry/callsite glue + buffer-CC packing).

## Runtime-call argument registers (SysV: rdi, rsi, rdx, rcx, r8, r9)
- `filc_optimized_access_check_fail(rdi=intval, rsi=lower, rdx=&origin)`
- `filc_pollcheck_slow(rdi=myth, rsi=&origin)`
- `filc_allocate(rdi=myth, rsi=sizeBytes)` -> `%rax`; usable payload = `%rax + 16`
- `filc_object_ensure_aux_ptr_outline(rdi=myth, rsi=lower-16)` -> `%rax`
- `filc_store_barrier_for_lower_slow(rdi=myth, rsi=lower)` — non-null lower
  only (the inline form guards `marking && lower`; the _slow entrypoint
  asserts non-null)
- `filc_cc_args_check_failure(rdi=size, rsi=expected, rdx=0)` / `filc_cc_rets_check_failure`
- calls use `@PLT`; globals via `leaq sym(%rip), %reg`; return `retq`; indirect `callq *(%rsi)` / `jmpq *%rax`

## Atomic pointer runtime functions (decoded from build/bin/clang -S output)
The C11 `_Atomic` pointer operations compile to these extern-"C" libpizlo
entrypoints — plain SysV (NOT the Fil-C dense convention), `nounwind`
(failures are fatal filc panics: NO exception-flag check after the call,
unlike pizlonated-function calls). A `filc_ptr` argument is two consecutive
argument words, **intval first, then lower**; past the sixth integer register
the remaining words go on the stack in declaration order. A `filc_ptr` result
comes back as **rax=intval, rdx=lower**. The runtime re-checks every access
internally (`filc_check_native_access`: null/align8/bounds, +READONLY for
writes); the compiler (and sarcasm) still emit the inline checks first for
good trap origins. Pointer ARGUMENTS need no caller GC rooting (the runtime
protects them itself); a RETURNED lower is rooted into the frame's root slots
immediately (the allocating calls are GC safepoints).
- `filc_ptr filc_load_ptr_atomic_with_manual_tracking_outline(filc_ptr slot)`:
  `rdi=slot.iv, rsi=slot.lower` -> `rax=old.iv, rdx=old.lower`. No myth arg,
  does not allocate, can only panic. (Internally: check, non-atomic raw-word
  read, load-load fence, SEQ_CST aux-word read; boxed slots get a 128-bit box
  load via `lock cmpxchg16b`.)
- `void filc_store_ptr_atomic_outline(filc_thread* myth, filc_ptr slot,
  filc_ptr value)`: `rdi=myth, rsi=slot.iv, rdx=slot.lower, rcx=value.iv,
  r8=value.lower`. Can allocate (creates the 16-byte atomic box / ensures
  aux) => GC safepoint; runs the store barrier on value internally.
- `filc_ptr filc_strong_cas_ptr_with_manual_tracking(filc_thread* myth,
  filc_ptr slot, ptrdiff_t offset, filc_ptr expected, filc_ptr new_value)`:
  `rdi=myth, rsi=slot.iv, rdx=slot.lower, rcx=offset, r8=expected.iv,
  r9=expected.lower`, and **`new_value` on the stack: `[rsp]=new.iv,
  `[rsp+8]=new.lower` at the call** (clang: `pushq new.lower; pushq new.iv;
  callq; addq $16, %rsp`) -> old value in `rax/rdx`. Can allocate (box
  creation) => GC safepoint. **Success <=> `old.iv == expected.iv`** — a raw
  intval comparison (clang: `cmpq expected.iv, old.iv; sete`); the expected's
  lower is ignored by the comparison, so a null-lower expected is a
  legitimate "integer guess". The returned old value carries the slot's real
  lower.
- (`filc_ptr filc_xchg_ptr_with_manual_tracking(myth, slot, offset, new)`
  exists too — six register words — but xchg-on-pointers is not currently
  emitted by sarcasm.)

## Registers
16 GPRs, encoding order: rax=0 rcx=1 rdx=2 rbx=3 rsp=4 rbp=5 rsi=6 rdi=7 r8..r15=8..15.
Sub-registers: e** (32), ** (16), *l/**l/r*b (8). Callee-saved: rbx, rbp, r12-r15.
Caller-saved: rax, rcx, rdx, rsi, rdi, r8-r11. Reserved: rsp (stack), rbp (frame ptr).

## Prologue / SOV / frame (from pizlonatedFIP)
```
pushq %rbp ; pushq %r15 ; ... ; pushq %rbx      # save used callee-saved
subq $N, %rsp                                    # frame
cmpq %rsp, (%rdi) ; jae filc_stack_overflow_failure@PLT   # SOV (rdi=myth at entry)
movq 16(%rdi), %rax ; movq %rax, (%rsp)          # frame.prev
movq %rsp, %rax ; movq %rax, 16(%rdi)            # myth->top_frame = &frame
leaq .Lfilc_origin(%rip), %rax ; movq %rax, 8(%rsp)   # frame.origin
# roots at 16(%rsp), 24(%rsp), ...
```
Epilogue: `movq (%rsp), %rax ; movq %rax, 16(%rdi)` (pop frame) ; restore ; `addq $N,%rsp` ;
`popq` in reverse ; `xorl %eax,%eax` (flags) ; `movq <ret>, %rdx` ; `retq`.

## Access check for N bytes at (intval=%iv, lower=%lo)
```
testq %lo, %lo ; je FAIL                     # null cap
cmpq %lo, %iv ; jb FAIL                        # iv < lower
cmpq -16(%lo), <iv+N> ; ja FAIL   (or: iv vs upper with jae for N==1)   # iv+N > upper
testb $(align-1), %ivb ; jne FAIL              # alignment
```
FAIL: `leaq origin(%rip),%rdx ; movq %iv,%rdi ; movq %lo,%rsi ; callq filc_optimized_access_check_fail@PLT`

## Pollcheck / store barrier (same structure as ARM64, x86 encodings)
```
testb $14, 8(%rdi) ; jne slow                  # myth flags
... callq filc_pollcheck_slow@PLT ...
```
Store barrier: `movq filc_current_marking_state@GOTPCREL(%rip),%r; cmpl $0,(%r); jne slow` etc.

## Callsite resolver (pizlonatedFI<sig>_NAME, weak/hidden)
`xorl %esi,%esi; callq pizlonated_NAME@PLT` -> rax=iv, rdx=lower of FO; validate flags
`movabsq $0x780000000000000` & `== $0x80000000000000`; intval `== [FO-8]&0xFFFFFFFFFFFF`;
signature `cmpq $SIG, 16(FO)`; direct: `movq (FO),%rax; <restore CC>; jmpq *%rax`; else
marshal to CC buffers and call generic entrypoint. Fail: filc_check_function_call_fail.

## Indirect calls (`call *%reg ;! sig(...)` — emitted by sarcasm, x86_64 only)
For a register-indirect call with a callsite signature annotation, sarcasm emits
filcc's exact indirect-call sequence for the flight pointer (P = target intval,
L = target lower — the target register's web must be a known pointer value, so
its lower is known):

```
testq L, L ; je FAIL                          # null capability
movq -8(L), %a ; movq $0x780000000000000, %b ; andq %a, %b
movq $0x80000000000000, %c ; cmpq %c, %b ; jne FAIL   # special type == FUNCTION
shlq $16, %a ; shrq $16, %a                   # a = aux & 0xFFFFFFFFFFFF
cmpq %a, P ; jne FAIL                         # ptr == canonical entrypoint
movq 16(L), %a ; cmpq $SIG, %a ; jne GENERIC  # signature dispatch
movq (L), %tgt                                # fast entrypoint
movq myth, %rdi ; movq L, %rsi ; <dense fast-CC args>
call *%tgt
jmp REJOIN
GENERIC:                                      # signature mismatch: buffer CC
<store args at 128(myth), aux/lowers at 384(myth), $0 for scalar aux>
movq $ARGBYTES, %rdx ; movq myth, %rdi ; movq L, %rsi
call *8(L)                                    # generic entrypoint
testb $1, %al ; jne EXC                       # exception flag FIRST: on the exception edge
                                              # rdx (ret_size) is undefined, so the ret-size
                                              # check must not run before this test
cmpq $RETBYTES-1, %rdx ; jbe RETFAIL          # ret_size must cover the result
movq 128(myth), %rdx ; movq 384(myth), %rcx   # unmarshal (rcx only for ptr ret)
REJOIN:
testb $1, %al ; jne EXC                       # exception flag, as for direct calls
                                              # (already known clear on the generic edge)
<result unpacking identical to a direct call; a ptr result's lower is rooted>
FAIL:    movq P, %rdi ; movq L, %rsi ; callq filc_check_function_call_fail@PLT
RETFAIL: movl $RETBYTES, %esi ; movq %rdx, %rdi ; xorl %edx, %edx
         callq filc_cc_rets_check_failure@PLT
```

The GENERIC block inlines exactly what the callsite resolver's L_generic
mismatch path does (and what filcc's weak pizlonated1ET<sig> thunk does for a
C indirect callsite), so sarcasm never references pizlonated1ET<sig> — that
weak symbol exists only when some C compilation unit in the link contains an
indirect callsite with signature SIG, so referencing it could be a link error.
No bounds check appears anywhere in the sequence: a function object's bounds
are degenerate (upper == lower). Unannotated register-indirect calls, all
memory-indirect calls (`call *mem`), and annotated calls whose target web is
not a known pointer value are compile-time errors; arm64 rejects all indirect
calls.

## Data directives
`.quad` (= .xword), `.long` (= .word), `.zero`, `.byte`, `.asciz` — same layout as ARM64.
`movabsq $imm, %reg` for 64-bit immediates; `endbr64` (CET marker; safe to keep/ignore).
