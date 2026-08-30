# Fil-C 0.683 ARM64 ABI notes (decoded from clang output)

Reference files: `test-filc.s`, `test2-filc.s`, `test4-filc.s`, and `clang -S -O2 test3.c`.
(The sarcasm annotations below are spelled with the universal `;!` marker; on arm64 the
recommended `//!` spelling is equivalent — see "Annotation markers" in README.md.)

**VERIFIED**: `hash.yolo.s` (a hand transform of `test-spasm.s`, i.e. the exact shape sarcasm
must emit) assembles with filc clang, links with a Fil-C `main`, and runs correctly
(`hash("hello")=210714636441`). On a genuine OOB walk it produces the identical Fil-C
safety trap as clang's own output. So the templates below are runtime-correct.
`filc_frame` with `.word 1` root count + one root slot at `frame+16` is accepted by the runtime.

## Invisicap flight pointer

A pointer in flight = a pair **(intval, lower)**.
- `intval` = the untrusted integer address the C program manipulates.
- `lower`  = trusted capability; a pointer to the object payload base.

Object header sits **just below** `lower`:
- `[lower - 16]` = **upper** bound (exclusive).
- `[lower - 8]`  = **aux word**: low 48 bits = aux allocation ptr (parallel array of
  lowers for pointer-typed slots); high 16 bits = flags.
- `[lower ...]`  = payload (the intval range `[lower, upper)`).

`lower == 0` means null capability (no access allowed).

### Access check for N-byte access at (intval, lower)
```
cbz  lower, FAIL              ; null cap
cmp  intval, lower ; b.lo FAIL         ; intval < lower
ldur upper, [lower, #-16] ; add tmp,intval,#N ; cmp tmp,upper ; b.hi FAIL   ; intval+N > upper
; (pointer/aligned accesses also check alignment: tst intval,#(align-1); b.ne FAIL)
```
Fail path: `filc_optimized_access_check_fail(intval, lower, &origin)` (x0,x1,x2).

### Pointer LOAD  (non-atomic)  — load (vintval,vlower) from (pintval,plower)
1. access-check 8 bytes at (pintval, plower), 8-aligned.
2. `offset = pintval - plower`.
3. `aux = [plower-8] & 0xffffffffffff`. If aux==0, loaded lower is 0 (null).
4. `vintval = [pintval]`. `auxentry = [aux + offset]`.
   - if `auxentry & 1` (atomic box): `vlower = [(auxentry & ~1) + 8]`.
   - else `vlower = auxentry`.

### Pointer STORE (non-atomic) — store (vintval,vlower) to (pintval,plower)
1. access-check 8 bytes at (pintval, plower), 8-aligned; also reject if aux flags
   `& 0x6000000000000` set (readonly/special).
2. `offset = pintval - plower`.
3. `aux = [plower-8] & 0xffffffffffff`; if 0, call
   `filc_object_ensure_aux_ptr_outline(myth, plower-16)` -> new aux in x0.
   NOTE: x1 is the **object header** address (`lower-16`), NOT `lower` itself. Passing
   `lower` makes the runtime read a bogus object size and report "out of memory".
   Also reject the store if `[plower-8] & 0x6000000000000` (read-only/special object).
4. store barrier: load `filc_current_marking_state` (via GOT), if `[it] != 0` call
   `filc_store_barrier_for_lower_slow(myth, vlower)`.
5. `[aux + offset] = vlower`  (store lower); `[pintval] = vintval` (store intval).

### Atomic pointer operations (runtime calls, verified against clang aarch64 output)
Exactly the calls filcc emits for C11 `_Atomic` pointer accesses. A `filc_ptr` is two
consecutive argument words (intval, then lower); a `filc_ptr` result comes back
`x0`=intval, `x1`=lower. The callees are `nounwind` (failures are fatal filc panics),
so NO exception-flag check follows them; returned lowers are rooted immediately.
- `filc_load_ptr_atomic_with_manual_tracking_outline(slot)` — x0=slot.iv, x1=slot.lo
  (no myth; does not allocate; can only panic).
- `filc_store_ptr_atomic_outline(myth, slot, value)` — x0=myth, x1=slot.iv,
  x2=slot.lo, x3=value.iv, x4=value.lo. Can allocate (creates the 16-byte atomic
  box / ensures aux) => GC safepoint; barriers value internally.
- `filc_strong_cas_ptr_with_manual_tracking(myth, slot, 0, expected, new)` — all
  eight argument words marshal in REGISTERS: x0=myth, x1=slot.iv, x2=slot.lo,
  x3=0 (offset), x4=expected.iv, x5=expected.lo, x6=new.iv, x7=new.lo (AAPCS64 —
  no stack marshalling, unlike SysV). Returns old (x0=iv, x1=lo). Success <=>
  old.iv == expected.iv (raw-intval comparison; the runtime ignores expected's
  lower — a null-lower expected is a legitimate "integer guess").
sarcasm emits its usual inline access check (null-cap -> align 8 -> CanWrite for
writers -> lower -> upper) before each call, so a trap gets sarcasm's origin.

## Stack allocations (`filc_allocate`)
Fil-C turns stack buffers / `alloca` into GC allocations.
- `filc_allocate(myth /*x0*/, sizeBytes /*x1*/)` returns the object base in `x0`; the
  usable payload pointer is `x0 + 16` (skip the 16-byte invisicap header), and for a
  fresh allocation intval == lower == `x0 + 16`.
- It is a GC safepoint (clobbers caller-saved; may collect) — live pointers must be
  rooted across it; the allocation's own lower is rooted afterwards.
sarcasm annotations: `;! alloca size (x)` on `sub sp,sp,X` captures byte size X;
`;! alloca result (x)` / `;! alloca result size=N` replaces the instruction with the
allocation. For fixed sizes, sp-relative address math inside `[base, base+size)` (from
`add rd,sp,#off` in gcc -O0) is redirected to the allocation pointer.

## Thread object (myth), x0 in fast entrypoints
- `[myth + 0]`   = stack limit (for stack-overflow check).
- `[myth + 8]`   = flags byte; pollcheck tests `tst w,#0xe` (bits 1-3).
- `[myth + 16]`  = top frame pointer (push/pop the filc_frame here).
- `[myth + 128]` = CC payload buffer: arg/ret i intval at `+128 + 8*i`.
- `[myth + 384]` = CC aux buffer:     arg/ret i lower  at `+384 + 8*i`.

## filc_frame (pushed on stack, pointed to by myth+16)
- `[frame + 0]`  = prev frame (old myth+16).
- `[frame + 8]`  = origin pointer (&.Lfilc_origin).
- `[frame + 16 + 8*k]` = live pointer root slots (lowers of live pointers), scanned by GC.

## Fast entrypoint register CC (pizlonatedFIP<sig>_<name>)
- x0 = myth, x1 = function object payload ptr (closure data; often unused).
- args are packed DENSELY into x2..x7: a scalar arg consumes one slot (intval only), a
  pointer arg two consecutive slots (intval, lower). E.g. `long(long,long,ptr)`: arg0=x2,
  arg1=x3, arg2=(x4,x5); `unsigned long(ptr,size_t,size_t)`: arg0=(x2,x3), arg1=x4,
  arg2=x5. (Verified against pizlonated clang aarch64 output; the older fixed-pair
  description here — arg k always in (x(2+2k), x(3+2k)) — was WRONG for any signature
  with a scalar before a later arg.) Arguments beyond the sixth word go on the stack;
  sarcasm does not marshal stack arguments and rejects such signatures.
- return: w0 bit0 = exception flag (1=exception); x1 = ret.intval; x2 = ret.lower.
- FP args (arm64 float/double; verified against pizlonated clang aarch64 output):
  - Fast CC: FP args pass in v0..v7 in DECLARATION ORDER among the FP args (a float
    occupies the low 32 bits of its v register, a double the full 64); the dense GPR
    packing into x2..x7 counts only GPR/pointer args, so a float arg never consumes a
    GPR slot and a GPR arg after a float arg is NOT shifted by it. The FP return rides
    in v0 (s0 for float, d0 for double); the flag/retval GPR contract is unchanged
    (w0 bit0 = exception flag, x1 = ret.intval, x2 = ret.lower). Verified signatures:
    double(double,double)=4792, float(float,float)=3195, double(int,double)=4526,
    void(float,double)=4656, long(double,int,float,long)=211073, float(void)=3.
  - Generic/buffer CC (both sarcasm's weak callsite thunk and the 2ET generic thunks):
    one 8-byte word per argument at `myth+128+8*i` with i = the argument's DECLARATION
    index over ALL arguments (FP args included) — a float is a 4-byte store into the
    low half of its 8-byte slot; the aux word at `myth+384+8*i` is zero. w2 = total
    argument count * 8 (FP args count). An FP return is 8 bytes at `myth+128` (a float
    in the low 4 bytes) with a zero word at `myth+384`; the expected ret size is 8.
  - The weak callsite resolver does NOT spill FP args across its getter call: nothing
    between entry and its two call sites touches the v file, so on the fast path the
    FP args are still in their v registers for the tail call, and on the generic path
    they are stored into the buffer straight from there.
  - x86_64 implements the same float/double signature support with the x86
    equivalents: an independent xmm sequence (xmm0..xmm7 in declaration order among
    the FP args, independent of the dense rdx/rcx/r8/r9 packing), the FP return in
    xmm0 with `movl $0, %eax` still clearing the exception flag, `movss`/`movsd`
    buffer packing at the same 128+8i/384+8i offsets, a signature-forced 256-byte
    xmm-save area, and — where a >imm32 signature immediate is concerned —
    `movabsq`-widened compares instead of this arch's chunked movz/sub-cmp/movk
    encoding (x86 has no `cmpq $imm64, mem`); see ABI-NOTES-x86.md's
    "Floating-point ABI".
- NEON registers in instruction BODIES are fully supported: they
  pass through verbatim (sarcasm never register-allocates them), their heap
  accesses get the standard capability+bounds check at exact widths, and their
  frame slots virtualize into the GPR slot webs. The AAPCS64 vector discipline
  that makes this work: v0-v7 and v16-v31 are fully caller-saved (and the Fil-C
  runtime itself is built with a full NEON toolchain, so sarcasm's injected
  runtime calls can clobber them), while v8-v15's low 64 bits are callee-saved
  (the C callee preserves those itself, so only their upper halves are at risk
  across an injected call). sarcasm therefore brackets its injected RETURNING
  runtime calls (pollcheck slow path, filc_allocate, the ptr-store
  aux-ensure/barrier slow paths) with liveness- and width-aware vector saves —
  a v-reg live only in its low 4/8/16 bytes saves as sN/dN/qN, a dead one saves
  nothing, v8-v15 save only when live at more than 8 bytes — and treats user
  calls as killing caller-saved vector state. The AAPCS callee-saved d8-d15
  prologue/epilogue spill forms in the input virtualize through slot webs like
  any other frame slot, so the caller's vector values round-trip exactly.

## Stack overflow check (prologue, after saving regs, before frame push)
```
ldr x9, [x0]       ; myth stack limit
cmp sp, x9
b.hs .Lok
b   filc_stack_overflow_failure
.Lok:
```

## Pollcheck (in loops / safepoints)
```
ldrb w8, [myth, #8] ; tst w8, #0xe ; b.eq .Lnopoll
; slow: set up x0=myth, x1=&origin ; bl filc_pollcheck_slow ; (restore live regs)
.Lnopoll:
```

## Signature encoding (verified: unsigned(ptr)=1066, void(ptr,ptr)=12769, int(ptr,size_t)=2529)
Type indices: int/bool/all-int=0, float=1, double=2, long double=3,
vec128=4, vec256=5, vec512=6, pointer=7, (8,9,10 reserved).
```
enc(types t1..tn) = sum_{i=1..n} 11^(i-1) * (1 + t_i)     ; 0 if empty
Ret = enc(return types)      ; void -> 0, single scalar -> 1+t
Arg = enc(argument types)
signature = 1 + Ret + 133 * Arg
```
Argument-buffer size = 8 * (number of argument words), rounded per 8/alignment.

## Symbols emitted per exported function `NAME` with signature `SIG`
- `pizlonated_NAME`  (global): function getter. Returns FO flight ptr:
  `adrp/add x0, pizlonatedFO_NAME+16 ; mov x1, x0 ; ret`.
- `pizlonatedFIP<SIG>_NAME` (global): fast entrypoint (the real body).
- `pizlonated2ET<SIG>` (weak): generic (buffer) entrypoint thunk -> calls FIP.
- `pizlonatedFI<SIG>_NAME` (global) `.set` alias to `pizlonatedFIP<SIG>_NAME`.
- `pizlonatedFO_NAME` (.data.rel.ro, 40 bytes): FO object
  `.xword FO+16 ; .xword (FO+16)+0x83000000000000 ; .xword FIP ; .xword 2ET ; .xword SIG`.
  (`0x83<<48 = 36873221949095936` = function/special upper flags.)
- origin/string/function_origin objects (see templates in test-filc.s).

## Per called external function `NAME` with signature `SIG` (caller side)
- Caller sets x0=myth, x2/x3.. = args, then `bl pizlonatedFI<SIG>_NAME`; checks w0 bit0.
- Must emit a weak/hidden `pizlonatedFI<SIG>_NAME` callsite thunk that resolves the
  callee FO via `pizlonated_NAME`, validates special-object flags (0x80000000000000 kind),
  intval match, and signature==SIG, then tail-calls fast entrypoint (`br x5`) or falls
  back through generic buffers. Fail: `filc_check_function_call_fail`,
  size mismatch: `filc_cc_rets_check_failure` / `filc_cc_args_check_failure`.
  The getter takes (my_thread, origin): the origin argument (x1) must be NULL or a valid
  `filc_origin*`, because the getter's slow path (first initialization of a data object)
  swaps it into `my_thread`'s top `filc_frame`. The callsite thunk is shared by all
  callers, so it passes NULL: `mov x1, xzr; bl pizlonated_NAME` (pizlonated clang's own
  FI thunk does the same).

## Indirect calls (`blr xN ;! sig(...)` — the arm64 form; x86_64 emits the
## analogous `call *%reg ;! sig(...)`, see ABI-NOTES-x86.md)
For a register-indirect call with a callsite signature annotation, sarcasm inlines
exactly the check sequence above (the callsite resolver's checks, the same ones an
indirect call performs), for the flight pointer (P = target intval, L = target lower —
the target register's web must be a known pointer value, so its lower is known):

```
cbz  L, FAIL                                  ; null capability
ldur a, [L, #-8] ; movz/cmp (a>>48)&0x780 vs 0x80 ; b.ne FAIL   ; special type FUNCTION
and  a, a, #0xffffffffffff ; cmp a, P ; b.ne FAIL               ; canonical entrypoint
ldr  a, [L, #16] ; cmp a, #SIG (movz/sub-cmp/movk for big SIG) ; b.ne GENERIC
ldr  tgt, [L]                                  ; fast entrypoint
mov  x0, myth ; mov x1, L ; <dense fast-CC args>
blr  tgt
b    REJOIN
GENERIC:                                       ; signature mismatch: buffer CC
<store args at 128(myth), aux/lowers at 384(myth), xzr for scalar/FP aux>
mov  w2, #ARGBYTES ; mov x0, myth ; ldr x8, [L, #8] ; blr x8    ; generic entrypoint
tbnz w0, #0, EXC                               ; exception flag FIRST: on the exception
                                               ; edge x1 (ret size) is undefined, so the
                                               ; ret-size check must not run before this
cmp  x1, #RETBYTES ; b.lo RETFAIL              ; ret_size must cover the result
ldr  x1, [myth, #128] ; (ldr x2, [myth, #384] for ptr ret)      ; unmarshal
REJOIN:
tbnz w0, #0, EXC                               ; exception flag, as for direct calls
                                               ; (already known clear on the generic edge)
<result unpacking identical to a direct call; a ptr result's lower is rooted>
FAIL:    (x0, x1 = P, L) ; bl filc_check_function_call_fail
RETFAIL: mov x0, x1 ; mov w1, #RETBYTES ; mov x2, xzr
         bl filc_cc_rets_check_failure
```

The GENERIC block inlines exactly what the callsite resolver's generic mismatch path
does, so sarcasm never references pizlonated1ET<sig>. Unannotated `blr`, memory-operand
indirect calls (they do not exist on arm64 — `blr` is register-only, so the x86
`call *mem` rejection has no arm64 analog), and annotated calls whose target web is not
a known pointer value are compile-time errors; `br xN` (indirect branch) and `b xN` are
rejected in all forms.

