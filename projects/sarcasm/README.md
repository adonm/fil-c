# sarcasm — SAfe Runtime Capability-enforced Assembler

sarcasm is an assembler (written in Luau, run via `lute`) that takes ARM64 or X86_64
assembly written to link with **Yolo-C** and rewrites it into **memory-safe** assembly
that links with **Fil-C**. It performs the GIMSO transformation on pointers, changes the
pointer representation to invisicaps, reallocates registers with Iterated Register
Coalescing, and emits code that follows the Fil-C ABI (calling convention, safepoints,
stack-overflow checks, GC roots). It supports **ARM64** (aarch64) and **X86_64** (both
AT&T and Intel input syntax; the target is auto-detected from the input), and rejects
anything it cannot prove safe rather than passing unsafe code through.

## Usage

```
./sarcasm.sh [-o OUT.o] [-S|--no-assemble] [--as CMD] INPUT.s
```
- Default: writes a temporary `INPUT.yolo.s` next to the output and runs `as` to produce
  `OUT.o` (like `as`). `--as CMD` overrides the assembler (default `as`).
- `-S` / `--no-assemble`: emit assembly only. Without `-o`, writes `INPUT.yolo.s`.

Input assembly must carry `;!` annotations:
- on each exported function label: its Fil-C signature, e.g. `hash: ;! unsigned(ptr)`;
- on each instruction that loads a pointer from memory: `;! load ptr` (`;! store ptr` for stores);
- on each instruction that atomically loads a pointer from memory:
  `;! atomic load ptr` (`;! atomic store ptr` for atomic stores);
  these go through the Fil-C runtime (`filc_load_ptr_atomic_with_manual_tracking_outline`
  / `filc_store_ptr_atomic_outline`), exactly like C11 `_Atomic` pointer accesses
  compiled by filcc. x86_64 shapes: the plain `movq` forms. arm64 shapes:
  `ldr`/`ldur`/`ldar`/`ldapr` for the load, `str`/`stur`/`stlr` for the store
  (64-bit GPRs; no writeback — no atomic form has one);
- on `cmpxchgq` with a memory destination (x86_64) resp. `cas`/`casa`/`casl`/`casal`
  with x-registers (arm64): `;! atomic ptr` — a pointer
  compare-exchange through the runtime
  (`filc_strong_cas_ptr_with_manual_tracking`; on x86_64 the `lock` prefix is
  allowed and irrelevant, both forms make the same call). The expected value is the
  accumulator (x86_64) resp. the compare register (arm64) — compared by raw intval,
  like the hardware; the old value comes back in the same register WITH its
  capability, and flags are recomputed as (expected − old) so a `je`/`sete`
  (x86_64) or `b.eq`/`cset` (arm64) immediately after behaves natively;
- on a memory-destination RMW over a pointer slot (8-byte add/adc/and/or/sbb/
  sub/xor, inc/dec/neg/not — x86_64 only): `;! load store ptr` — a NON-atomic
  load-op-store that preserves the slot's capability (Fil-C pointer arithmetic
  through memory), or `;! atomic load store ptr` — WITHOUT `lock`, an atomic
  load + op + atomic store (each access atomic; the RMW as a whole is not);
  WITH `lock`, a real atomic RMW via a runtime compare-exchange loop. Flags
  are recomputed after the operation so a `jcc`/`setcc` immediately after
  behaves natively. Caveat for adc/sbb: they read a carry-in that the injected
  check/load/store sequences clobber — the carry is gone by the time the op
  runs (deterministically CF=0 for the non-atomic form, indeterminate for the
  atomic ones), so BOTH the stored result and the recomputed flags reflect a
  clobbered carry-in, not the program's: adc/sbb are supported for
  execution-without-trapping, not for carry semantics. xadd and cmpxchg are
  rejected with these annotations
  (cmpxchg wants `;! atomic ptr`; xadd's source-register destination has no
  capability model — use a cmpxchg loop). On **arm64**:
  `;! load store ptr` is rejected (no non-atomic memory-destination RMW exists —
  write the load, op and store annotated `;! load ptr` / `;! store ptr`), and
  `;! atomic load store ptr` annotates a 64-bit LSE RMW (ldadd/ldset/ldeor/
  ldclr/swp and the stadd-class aliases, incl. the a/l/al ordering variants):
  the instruction is already atomic, so ldadd/ldset/ldeor/ldclr lower to the
  runtime compare-exchange loop with a per-iteration pollcheck (the x86
  `lock` form's analog); the op is re-executed on the loaded intval with the
  SAME lower (Fil-C pointer arithmetic through memory). swp is the exception:
  its new value IS the source operand, so it lowers to a single
  filc_xchg_ptr_with_manual_tracking call (the exact primitive filcc emits
  for C11 atomic_exchange) and the new value carries the SOURCE's capability
  — a cross-object exchange stays dereference-able, while an integer source
  gets a null capability (storing it is legal; it just can't be dereferenced
  afterwards). Either way the old-value destination register (ldadd's Wt /
  swp's Wt) receives the old value WITH its capability, exactly like an
  `;! atomic load ptr` result. The native LSE forms write no flags, so NZCV
  is preserved across the sequence rather than recomputed;
- on each call: the callee's signature, e.g. `bl foo ;! int(ptr, size_t)`. On x86_64 the
  same annotation also marks a register-indirect call (`call *%rax ;! ptr(int)`) — see
  "Indirect calls" below;
- on stack allocations: `;! alloca size (x)` on the `sub sp,...` and `;! alloca result (x)`
  on the instruction that yields the pointer (dynamic), or `;! alloca result size=N` for a
  fixed-size buffer. These become GC allocations (`filc_allocate`), not real stack memory.

Annotations are validated, never silently ignored: `;! load ptr` / `;! store ptr`
require a plain 8-byte GPR load/store of the matching direction (and the
`;! atomic load ptr` / `;! atomic store ptr` forms are at least as strict); a
memory-destination RMW (add/xadd/cmpxchg & co with a memory destination)
annotated with either is rejected (pointer RMWs need `;! load store ptr`);
the pointer-RMW/atomic annotations require exactly the shapes above (8-byte
forms only; `;! atomic ptr` only on memory-destination cmpxchg resp. 64-bit cas)
and are rejected on
cmpxchg8b/cmpxchg16b (x86_64) and casb/cash/casp (arm64), which cannot operate
on pointers; any other
unrecognized annotation string is a compile-time error.

### Indirect calls (x86_64)

On x86_64, a register-indirect call carrying a callsite signature is supported
exactly like an annotated direct call:

```
call *%rax    ;! ptr(int)
```

The target register's web must be a known pointer value (a pointer argument,
the result of `;! load ptr`, or a pointer-returning call) so that its
capability (lower) is known. The emitted code is filcc's exact indirect-call
sequence for the flight pointer (P = target intval, L = target lower): L==0
traps; the aux word at [L-8] must have special type FUNCTION
((aux & 0x780000000000000) == 0x80000000000000); P must equal the object's
canonical entrypoint (aux & 0xFFFFFFFFFFFF); then the signature word at
[L+16] selects the fast entrypoint at [L+0] on a match (fast-CC args in
rdi=myth, rsi=L, rdx/rcx/r8/r9 densely packed) or, on a mismatch, an inlined
generic (buffer-CC) call through [L+8] — the arguments are marshalled into
my_thread's CC buffer (data at 128(myth), aux at 384(myth)) exactly like the
direct-call resolver thunk's mismatch path, so there is NO link dependency on
the weak pizlonated1ET<sig> thunk filcc uses (it exists only when some C
compilation unit performs an indirect call with that signature). All failure
edges share one stub calling filc_check_function_call_fail (rdi=P, rsi=L),
which reports the precise cause (null object / isn't even special / wrong
special type / ptr != aux). Results (including pointer results, with the
returned lower rooted) and the exception flag behave exactly like a direct
call. Three forms are rejected with clean errors: an UNANNOTATED
register-indirect call (no `;!` signature — historically it got no checks and
not even caller-saved clobber modeling), ANY memory-indirect call
(`call *mem`, annotated or not — load the function pointer into a register
first, e.g. via `;! load ptr`), and an annotated call whose target web is not
a known pointer value. On arm64 ALL indirect calls remain rejected
(validateBody), as before.

See the x86_64 examples under `filc/tests/` — e.g. `filc/tests/sarcasm-hash-att/hash.s`
(AT&T syntax) and `filc/tests/sarcasm-hash-int/hash.s` (Intel syntax), or
`filc/tests/sarcasm-call/get-sarcasm.s`.

## Pipeline (`sarcasm/`)
Shared, architecture-independent modules:
- `detect.luau`  — auto-detects the target (arm64 vs x86_64; att vs intel syntax).
- `sig.luau`     — Fil-C signature encoding (`1 + Ret + 133*Arg`).
- `frame.luau`   — drops the input frame; virtualizes stack slots as locals.
- `lift.luau`    — lifts to a virtual-register IR via reaching-definition **register webs**.
- `ptrflow.luau` — pointer-flow analysis: which temps are pointers + their `lower` temps.
- `transform.luau` — the GIMSO transform: intval/lower doubling, invisicap loads and
  **stores (with aux allocation + FUGC store barriers)**, **atomic pointer
  loads/stores/compare-exchange and pointer RMWs via the Fil-C runtime**,
  offset- and
  **register-index-aware** access checks, **null-capability trapping** for non-pointer
  heap accesses, **not-readonly (CanWrite) checks on every heap write**, Fil-C calls
  (marshalling + exception propagation), pollchecks at loop
  headers, SOV check, frame push/pop, GC roots.
- `regalloc.luau` — Iterated Register Coalescing (Appel & George) over the GPR file.
- `emit.luau`    — renders IR with the allocation; synthesizes prologue/epilogue.
- `build.luau`   — constructors for synthesized IR nodes.
- `sarcasm.luau` — the driver (function splitting, orchestration, `as` invocation).

Per-architecture backends (`arm64_*` / `x86_64_*` pairs behind a common interface):
- `*_parse.luau`   — GNU/clang assembly parser (+ `;!` annotations); x86_64 handles both
  AT&T and Intel syntax.
- `*_isa.luau`     — instruction semantics: register def/use, control flow, RMW.
- `x86_64_fp.luau` — the x86_64 FP/SIMD knowledge module: per-mnemonic memory
  access widths/alignments, GPR def/use roles of mixed GPR/vector instructions
  (cvtsi2sd, movd, kmov, fnstsw %ax, ...), and the unsafe-instruction reject
  list.
- `*_frame.luau`   — per-arch frame policy for the shared frame preprocessor.
- `*_codegen.luau` — per-arch instruction emitters used by the shared transform.
- `*_render.luau`  — per-arch rendering + prologue/epilogue synthesis for emit.
- `*_glue.luau`    — getter, FO object, generic entrypoint thunk, origins, alias, and the
  **weak callsite resolver thunk** for called externals.

## Safety model for memory accesses
- **Frame accesses** (`sp`/`x29`-relative on ARM64, `rsp`/`rbp`-relative on X86_64,
  within the input frame — on X86_64 that frame includes the 128-byte SysV red zone
  below rsp, reached via rsp- or normalized rbp-relative offsets alike) are
  virtualized as register-allocated locals — no capability needed.
  Accesses outside the frame, or writes into the caller's argument area, are
  **rejected at compile time**. Taking the address of the stack frame (e.g.
  `leaq 8(%rsp), %rax` or `movq %rsp, %rax`) is also rejected. On X86_64 the frame
  geometry is derived from the prologue prefix only, and there is **no mid-function
  stack-pointer movement**: constant rsp adjustments and push/pop outside the
  prologue/epilogue are rejected (balanced callee-saved save/restore pairs that no
  stack access can observe are the one exception), and dynamic allocation must use the
  `;! alloca` annotation. `enter` is rejected. A stack slot touched by an
  FP/SIMD instruction cannot be virtualized (a slot pseudo-register is not a
  vector register), so it is **materialized**: sarcasm reserves a region in its
  synthesized frame and rewrites the operand to a real `N(%rsp)`, preserving
  the input program's alignment guarantees up to 16 bytes (movaps/movdqa stack
  slots work). GPR accesses overlapping an FP-touched range are materialized
  too (byte aliasing is preserved), and materialization preserves AVX512
  decorators: `{1toN}` embedded broadcasts keep working on stack slots (the
  slot is sized at the broadcast element width), while `{k}`-masked stack
  accesses stay rejected (a virtualized slot is a pseudo-register the masked
  vector instruction cannot take, and masked-off lanes may not touch memory).
  FP/SIMD stack accesses needing
  more than 16-byte alignment (e.g. `vmovdqa32` with ymm/zmm) are rejected —
  the ABI guarantees only 16-byte stack alignment; use the unaligned form.
  On ARM64 a NEON/FP stack slot instead **virtualizes** into the same raw-byte
  GPR slot webs the GPR mechanism uses, via explicit GPR<->vector moves (a
  slot is just bytes: `str q0, [sp, #16]` becomes two `fmov`s out of the q
  register, a narrow `str b0`/`str h0` an extract+`bfi` preserving the
  neighboring bytes, pairs virtualize per element, and the AAPCS callee-saved
  d8-d15 prologue/epilogue writeback forms round-trip through slots at their
  final-sp-relative offset); the NEON forms that cannot be virtualized on a
  frame base — multi-structure ld2-4/st2-4, the replicate loads ld1r-4r, and
  lane-indexed single-element forms — are rejected.
- **FP/SIMD (X86_64)** is in scope: xmm0-31/ymm/zmm, MMX mmN, x87 st/st(N), and
  opmask k0-k7 registers and their instructions are supported. sarcasm has no
  vector register file, so FP/SIMD registers pass through exactly as written —
  it never needs them for Fil-C checks, and the calling convention makes none
  of them callee-save, so no usage validation is needed. Their memory operands
  get the usual capability+bounds check at the correct width (movss=4, movsd=8,
  vector=16/32/64, x87 tbyte=10, MMX=8, fxsave=512, embedded-broadcast
  `{1toN}`=element width, vpbroadcastb/w/d/q memory sources = element width
  1/2/4/8, truncating stores — vpmovqb/qw/qd/db/dw/wb and the
  saturating vpmovs*/vpmovus* forms — = source vector bytes / element ratio,
  vcvtps2ph/vcvtph2ps = half width on the ph side, AVX512-VNNI dot products
  vpdpbusd(s)/vpdpwssd(s)/vpdpbssd(s) = full vector width (vp4dpwssd(s) = 16),
  vdbpsadbw = full vector width, the AVX512-IFMA 52-bit multiply-adds
  vpmadd52huq/vpmadd52luq = full vector width, the full-width unsigned
  converts vcvtpd2uqq/vcvttpd2uqq = full vector width (8-byte elements on
  both sides, like vcvtpd2qq), the whole class of "sd"-ending packed-INTEGER
  p-stem mnemonics = full vector width (vpabsd/vpmaxsd/vpminsd and the SSE
  pabsd/pmaxsd/pminsd, the cross-sign VNNI dot products
  vpdpwusd(s)/vpdpbsud(s)/vpdpwsud(s), vpopcntd, ...) — p-stems are EXCLUDED
  from the ss/sd/ps/pd scalar-width suffix rule, in which the trailing "sd"
  of those names is part of the NAME, not a scalar suffix (the rule used to
  under-check them at 4/8 bytes; scalar FMA — vfmadd231sd = 8 — and the true
  scalar ss/sd forms keep their widths), packed AVX512-FP16 ph-suffix forms
  = full vector width like ps/pd (the SCALAR FP16 sh forms with a memory
  operand are rejected — the GPR-mixing scalar-half converts would be
  mis-modeled/under-checked), the widening converts at their exact ratios
  (vcvtudq2pd/vcvtdq2pd/vcvtps2uqq-family = dest/2,
  vcvtph2pd/vcvtph2qq/vcvtph2uqq = dest/4, vcvtne2ps2bf16 = full width), the
  narrowing converts (vcvtpd2ps & siblings — vcvtpd2dq/vcvttpd2dq/
  vcvtpd2udq/vcvttpd2udq/vcvtuqq2ps/vcvtqq2ps/vcvtneps2bf16, vcvtps2phx, and
  the pd2ph/dq2ph family) SIZE-DRIVEN: the destination register class does not
  determine the memory source width (vcvtpd2ps reads m128/m256/m512), so it
  comes from the Intel PTR annotation or the AT&T x/y(/z) source suffix at
  exact widths (XMMWORD PTR or vcvtpd2psx = 16, vcvtpd2psy = 32,
  vcvtpd2phz = 64); a bare unsized memory form is accepted only when the
  destination class is unambiguous (vcvtpd2ps (%rdi), %ymm0 ⇒ m512 — and
  likewise the vcvtdq2ph/vcvtudq2ph m512-source forms: the bare
  ymm-destination spelling is their only gas-encodable .512 form ⇒ 64, with
  the x/y source suffixes at 16/32 and ZMMWORD PTR driving the exact width
  in Intel syntax; those two are AVX512-FP16 instructions, so on this
  FP16-silicon-less dev machine their acceptance is compile-time- and
  pre-execution-trap-proven) and is
  otherwise cleanly rejected ("unsized memory operand is ambiguous; use a size
  suffix or PTR annotation"), and the renderer synthesizes the source suffix
  for Intel PTR input, lzcnt/tzcnt/popcnt and the BMI1/BMI2/bsf/bsr forms
  (shlx/sarx/shrx/andn/bextr/blsi/blsr/blsmsk/bzhi/pdep/pext/rorx/bsf/bsr)
  memory sources = the destination GPR's width, xadd and adcx/adox memory
  operands = the shared operand width, crc32 memory sources = the crc source
  width (an illegal destination/source width combination is rejected cleanly),
  sgdt/sidt=10,
  sldt/str/smsw=2, far-pointer loads lss/lfs/lgs = destination size + 2-byte
  selector, movnti = the source register's width (4 or 8), ...); the
  vpbroadcastb/w/d/q GPR-source forms are modeled as reading that GPR (an
  unmodeled read was a stale-register miscompile), as are the
  vcvtusi2ss/vcvtusi2sd integer source and the reverse vcvtt*/vcvt*2usi GPR
  destination (the size-driven cvt-int memory forms render with the l/q AT&T
  suffix synthesized — `vcvtusi2ss QWORD PTR [rdi]` emits `vcvtusi2ssq`), and
  Intel x87 memory forms RENDER at the correct AT&T suffix (fld QWORD PTR →
  fldl, fild QWORD PTR → fildq, fstp TBYTE PTR → fstpt — a bare rendering
  would assemble at gas's default width and silently change the checked
  access), and vpermi2*/vpermt2*
  two-source permutes and the UNMASKED vexpand*/vcompress*/vpexpand*/vpcompress*
  forms are supported at full vector width (with no writemask they touch all
  lanes — a contiguous full-width access). AVX512 `{k}`-masked and AVX2
  vector-masked memory operands are SUPPORTED on the vector moves
  (vmovdqu8/16/32/64, vmovups/upd, the aligned vmovdqa32/64 and vmovaps/pd),
  the truncating/saturating vpmov stores, the expand loads
  (vexpand*/vpexpand*) and compress stores (vcompress*/vpcompress*), and
  vmaskmovps/pd + vpmaskmovd/q: they get the exact mask-aware check the Fil-C
  compiler emits for the masked intrinsics — ValidObject (even for a zero
  mask), CanWrite for stores, then a full-width fast path refined by the mask
  in the slow paths (a zero mask executes; otherwise the enabled-lane extents
  are checked with cttz/highest-set-bit, or popcount for the contiguous
  expand/compress forms), with failures reported by the runtime's dedicated
  masked fail functions ("masked read not in bounds (even accounting for the
  mask)." & co). The implicit-register GPR
  instructions are genuinely MODELED via pin-in/pin-out copies, not passed
  through with a conservative def/use guess: div/idiv (rdx:rax dividend in,
  quotient/remainder out), mul and 1-operand imul (rax in, rdx:rax product
  out), mulx (implicit rdx source), cmpxchg (accumulator RMW + destination
  RMW), cmpxchg8b/cmpxchg16b (the implicit expected-value RMW pair edx:eax
  resp. rdx:rax plus the implicit new-value source ecx:ebx resp. rcx:rbx —
  all four pinned), the cqo/cdq/cwd sign-extends (rax in, rdx out), and the
  zero-explicit-operand implicit-only family — cpuid (eax/ecx in;
  eax/ebx/ecx/edx out), rdtsc (eax/edx out), rdtscp (eax/edx/ecx out), xgetbv
  (ecx in; eax/edx out), rdpkru (ecx in; eax/edx out), wrpkru
  (eax/ecx/edx in), monitor (rax/rcx/rdx in), mwait (eax/ecx in) — all name their
  implicit rax/rdx effects to the web analysis; synthesized moves then copy
  the current webs of the implicit-use registers into their physical registers
  before the instruction and back out into fresh webs after it (coalesceable —
  free when the user already wrote rax/rdx), and the emitted instruction shows
  only its explicit operands. (monitor's implicit rax address is not a memory
  access — MONITOR reads/writes no memory — so there is nothing to
  bounds-check; a wild address can only fault, an uncatchable-signal safe halt
  the safety model accepts. rdpkru/wrpkru and monitor/mwait are
  feature/OS-gated by the CPU and kernel, not by sarcasm: rdpkru #UDs unless
  the OS enabled protection keys, and monitor/mwait commonly #UD in userspace
  even with the CPUID feature bit set — probe before use.) Intel PTR-sized memory forms of the family
  render with the AT&T suffix synthesized (div QWORD PTR [rdi] → divq), and
  cbw/cwde/cltq are rewritten to a renameable movsxx on the rax web. Aligned
  forms (movaps/movdqa/...)
  additionally
  get an alignment check clamped to 8, exactly like compiled code. The `lock`
  prefix is supported exactly where the hardware allows it AND sarcasm models
  the instruction precisely: on memory-destination read-modify-write
  instructions (add/adc/and/or/sbb/sub/xor, inc/dec/neg/not, xadd, cmpxchg,
  cmpxchg8b/cmpxchg16b) — the locked instruction gets the same single
  write-classified access check as its unlocked form (including the
  not-readonly CanWrite test) with the prefix re-emitted; `lock` on anything
  else is rejected at compile time — including on stack-frame accesses (a
  frame slot is thread-confined: it virtualizes into a register or
  materializes into the synthesized frame before the `lock` validation runs,
  so accepting the prefix there would silently drop it). What remains
  rejected is only what cannot be checked: instructions with unknowable memory
  effects (syscall/sysenter, port I/O, hlt, wrmsr/rdmsr, cr/dr moves, `int N`
  for N≠3, string instructions and the rep/xacquire/xrelease prefixes),
  accesses that may not
  touch all addressed bytes (gather/scatter, maskmovdqu/maskmovq — their
  implicit DS:rdi memory destination cannot be bounds-checked — and the
  {k}-masked forms of anything outside the supported masked set above:
  masked ALU memory sources, {%k0}, and {k}-masked stack-frame accesses),
  implicit operands the
  checker cannot see or model (pcmpestri/pcmpistri/pcmpestrm/pcmpistrm —
  implicit rax/rdx/rcx GPRs;
  umwait/tpause — implicit edx:eax TSC-deadline reads the signature
  marshalling does not yet model; umonitor — monitoring-class hardware armed
  on a memory range the checker cannot size; clzero/xlatb — implicit memory
  operands;
  lcall/ljmp — the implicit far-return-frame stack push), AMX tile
  instructions (tileloadd/tilestored/ldtilecfg & co — a strided,
  tile-configuration-dependent footprint that cannot be checked as a single
  access), Intel PTR size
  annotations that contradict the ISA-determined memory access width —
  rejected on the heap and stack paths alike, on GPR accesses too
  (`vmovdqu64 DWORD PTR [mem], zmm0` still stores 64 bytes and
  `mov WORD PTR [rdi], rax` still stores 8, so a lying annotation would
  under-check the access or under-size the materialized stack slot; the
  legit narrowing exemptions — movzx/movsx/movsxd and no-GPR-operand forms —
  keep their annotation-driven widths, the x87 PTR-driven
  widths — `fld DWORD/QWORD/TBYTE PTR` — remain legal, and movnti's width is
  source-register-determined), x87 PTR forms the ISA does not have (`fst
  TBYTE PTR` — only fstp has an m80 form — rejected `<mnem> has no <N>-byte
  memory form`), privileged
  descriptor-table/system-register loads (lgdt/lidt/lldt/ltr/lmsw), CPU-state
  saves of
  unknowable size (xsave family, fsave/frstor/fstenv/fldenv),
  AT&T-style parens operands in Intel-syntax input (rejected outright with
  "AT&T-style operand in Intel-syntax input (use [bracket] memory operands)" —
  previously a parens field fell through to parseSym and re-rendered as
  UNCHECKED AT&T memory with Intel operand order, a total check bypass),
  symbolic (RIP-relative/global) addresses, absolute-address (moffs)
  operands — an AT&T bare symbol is an ABSOLUTE MEMORY operand in gas's
  dialect (`movq myglobal, %rax` LOADS from the global; `addq myglobal,
  %rax` reads it through the absolute address), as is an AT&T bare numeric
  literal (`movq 0x600000, %rax` loads from that address — NOT an
  immediate), and gas's Intel syntax gives a bare symbol the same moffs
  reading (proven via gas/objdump; only a bare NUMBER is an Intel
  immediate) — all rejected ("memory access with a symbolic address cannot
  be bounds-checked (global data access is not yet supported)" for symbols,
  "...with an absolute address..." for numerics) where they were previously
  UNCHECKED absolute accesses or silent load→immediate rewrites — and the
  rejection covers indirect-branch memory operands uniformly (`jmp
  *myglobal` / `call *myglobal` / `jmp *0x600000` branch THROUGH an
  absolute memory operand, an un-checkable absolute read, and jcc has no
  indirect encoding at all, so the `*` marker overrides the code-target
  exemption rather than being silently dropped into a semantic-changing
  direct branch or gas-failing output); unaffected are direct branches
  (call/jmp/jcc to symbols, numeric labels), register-indirect branches
  (`jmp *%rdi`), and register-based memory-indirect branches (`jmp
  *(%rax,%rcx,8)` — bounds-checked like any memory operand; memory-indirect
  CALLS are instead rejected — see "Indirect calls");
  exempt are
  the bare code-target operands (call/jmp/jcc/loop*/xbegin, incl. numeric
  local labels), lea address arithmetic, $imm, and segment-register moves
  (%gs & co) —, and unknown mnemonics with
  memory operands (width unknowable — the fallback no longer guesses a
  default-width check; unknown register-only forms still pass through with
  conservative def/use modeling — a fallback that now covers only
  genuinely-unknown mnemonics: the common compiler-output families
  BMI1/BMI2/ADX/bsf/bsr/xadd/adcx/adox/crc32 have exact entries, and the
  implicit-register mul/div/cmpxchg/cmpxchg8b/cmpxchg16b class is genuinely
  modeled as described
  above). Floating-point types are still rejected
  in `;!` signatures — the Fil-C FP ABI is now decoded (see
  `ABI-NOTES-x86.md`); marshalling it is deferred future work. Three known
  PRE-EXISTING issues (all reproduced on the unmodified baseline, NOT
  introduced by the current change) are documented in DESIGN.md's Limitations:
  a regalloc mis-coloring at ≥~13 simultaneously-live webs, injected
  bounds checks clobbering EFLAGS (reg-only flag chains are unaffected),
  and detect.luau's arch autodetect falling back to ARM64 for register-free
  x86 input — or input whose only registers are xmm-class (a lone `movss
  myglobal, %xmm0`; the detector keys on GPR markers) — (the input then
  fails later at `as` — confusing but harmless).
- **FP/SIMD (ARM64)** is in scope: the NEON/FP registers (the b/h/s/d/q scalar
  forms, v-register and arrangement forms, and structure register lists) pass
  through exactly as written — sarcasm has no vector register file and never
  needs one for the Fil-C checks (regalloc never models NEON). Their memory
  operands get the usual capability+bounds check at the exact width: the
  scalar forms at 1/2/4/8/16 bytes (b/h/s/d/q), register pairs (ldp/stp/
  ldnp/stnp, incl. the GPR pairs) at two elements, and the single- and
  multi-structure family (ld1-4/st1-4 and the replicate loads ld1r-4r) at
  N-structures times the register width — or N times the element width for
  the lane-indexed and replicate forms — with the arrangement qualifiers
  validated (only legal 8/16-byte register shapes; mixed or unsized
  arrangements rejected) so a malformed structure list can never under-check.
  Alignment follows pizlonated clang's own demands: none at 8 bytes or fewer,
  8-byte for wider accesses. NEON/FP frame slots virtualize into the GPR slot
  webs (see the frame bullet above). Because the Fil-C runtime is compiled
  with a full NEON toolchain, sarcasm's injected RETURNING runtime calls (the
  pollcheck slow path, filc_allocate, the ptr-store aux/barrier slow paths)
  are bracketed by **liveness- and width-aware vector saves**: a backward
  per-register width-liveness over the emitted stream saves exactly the live
  state (a register live only in its low 4 bytes saves as sN, 8 as dN, 16 as
  qN; a dead register saves nothing; v8-v15 save only when live at more than
  8 bytes — AAPCS64 makes their low 64 bits callee-saved, and the C callee
  preserves those itself). User calls kill caller-saved vector state as
  usual. The ARMv8 crypto instructions (aese/aesd/aesmc/aesimc, the SHA-1/
  SHA-256/SHA-512/SHA-3/SM3/SM4 families, pmull/pmull2) are register-only
  forms that pass through with the conservative unknown-mnemonic def/use
  model (execution-tested for AES/SHA-256/pmull behind the `needsARMCrypto`
  probe). Still rejected: SVE/SVE2 (z/p registers and the SVE-only mnemonics,
  cleanly), any memory operand on a non-load/store mnemonic (prfm & co —
  its memory effect cannot be modeled), and FP/vector types in `;!`
  signatures (like x86_64).
- **Heap accesses** are bounds-checked against a capability: the base's `lower` if the
  base is a pointer, else the index's `lower` (base wins if both are pointers), else a
  **null capability** — which traps at runtime (`cannot ... with null object`).
- **Heap writes** (plain stores, memory-destination RMWs incl. locked forms, FP/SIMD
  stores, movnti) additionally reject read-only/special objects: the access check
  tests the aux word at `[lower-8]` for ObjectFlagReadonly|ObjectFlagFree (bits
  49-50), exactly like compiled Fil-C, and traps with `cannot write to read-only
  object.`
- **Pointer stores** additionally ensure the aux
  capability array exists, and run the FUGC store barrier when marking is active
  (skipped for a null stored lower — a NULL store has no object to barrier,
  exactly like the runtime's `filc_store_barrier_for_lower`).
- **Atomic pointer operations** (`;! atomic load ptr`, `;! atomic store ptr`,
  `;! atomic ptr` on cmpxchg/cas, and the atomic forms of `;! atomic load store
  ptr`) go through the Fil-C runtime exactly like filcc-compiled C11 atomic
  pointer accesses: sarcasm emits its usual inline access check first (so traps
  get good origins — the runtime re-checks internally), then calls
  `filc_load_ptr_atomic_with_manual_tracking_outline` /
  `filc_store_ptr_atomic_outline` / `filc_strong_cas_ptr_with_manual_tracking`
  in the platform C marshalling (a `filc_ptr` is two consecutive words,
  intval-then-lower; x86_64 SysV spills
  `filc_strong_cas_ptr_with_manual_tracking`'s `new_value` to the stack, while
  arm64 AAPCS64 marshals all eight argument words in x0–x7). Atomically-stored
  slots are **boxed** (a 16-byte atomic box behind the aux entry, updated with
  `lock cmpxchg16b` on x86_64); the plain
  `;! load ptr` path is box-aware, so plain and atomic accesses to the same
  slot interoperate. The runtime functions are `nounwind` (failures are fatal
  filc panics), so no exception check follows these calls; returned lowers are
  rooted into the frame's GC root slots immediately (the calls that can
  allocate are GC safepoints).
- **Non-pointer atomics** (arm64): the LSE RMW family (swp/ldadd/ldclr/ldeor/
  ldset/ldsmax/ldsmin/ldumax/ldumin and the st<op> aliases, all widths and
  ordering variants), `cas`/`casp` (+variants), and the load/store-exclusive
  family (ldxr/stxr/ldaxr/stlxr +b/h, ldxp/stxp/ldaxp/stlxp) are modeled
  directly as single checked memory accesses — full bounds, CanWrite on every
  write, and NATURAL alignment (the ARM ARM requires it for these, so an
  unaligned one traps cleanly rather than faulting hardware-dependently). No
  annotation is needed (like x86_64's lock-prefixed RMWs on non-pointers).
  `cas`'s compare register is an architectural read-modify-write and is pinned
  to its written physical register (same mechanism as x86_64's cmpxchg
  accumulator); `casp`'s compare and data pairs are pinned likewise (the
  hardware encodes a pair as one even register number). A hand-written
  ldxr/stxr CAS retry loop works unchanged (the back-edge pollcheck is
  inserted automatically).

## Testing
All testing is via the Fil-C test suite: the 728 `filc/tests/sarcasm-*` tests (467
x86_64, 261 aarch64) run with `filc/run-tests -f sarcasm` from the repo root. Each
test carries a manifest with `use-sarcasm: true`; `.s` inputs are assembled via
minilute + sarcasm (`pizfix/bin/minilute projects/sarcasm/sarcasm-cli.luau`) and `.c`
files via clang. The suite compiles every yolo input with sarcasm, links with Fil-C
`main`s, and checks results, out-of-bounds/null-cap **traps**, the pointer-store
capability round-trip, register-indexed access, the callsite resolver, pollchecks,
GC stress, exact-width far-pointer/descriptor-table accesses (`sarcasm-farptr-att`,
`sarcasm-sidt-att`, and the `sarcasm-oob-lfs-att`/`sarcasm-oob-sidt-att` traps),
the source-register-width movnti store (`sarcasm-oob-movnti-att`),
the pinned implicit-register mul/div/cmpxchg family under register pressure
(`sarcasm-div-att`, `sarcasm-div-int` — cqo/cdq/cwd sign-extension, reg and
checked-memory divisors, mul/imul products, webs live across the pin), the
pinned cmpxchg accumulator and dual-RMW xadd (`sarcasm-rmw-pin-att`), the
pinned four-register cmpxchg8b/cmpxchg16b pairs with success/failure CAS
paths, mismatch writeback and lock/non-lock forms (`sarcasm-cmpxchg8b-att`/`-int`,
`sarcasm-cmpxchg16b-att`/`-int`), the zero-operand implicit-register family —
cpuid vendor/max-leaf, rdtsc/rdtscp monotonicity with a stable TSC_AUX,
xgetbv(0) XCR0 (`sarcasm-implicit-att`/`-int`), feature-probed rdpkru/wrpkru
(`sarcasm-pku-att`/`-int`) and monitor/mwait (`sarcasm-monitor-att`/`-int` —
both skip cleanly where the CPU/OS does not allow them), and six/eleven webs
live across a cpuid forcing coloring-around and spill/reload across the
pinned rax/rbx/rcx/rdx plus the move-free pin-in/out coalescing case
(`sarcasm-implicit-pin-att`/`-int`), the `lock` prefix on the modeled
memory-destination RMWs (`sarcasm-lock-rmw-att`/`-int`, and the
`sarcasm-oob-lock-xadd-att`/`sarcasm-oob-cmpxchg16b-att` traps), the
not-readonly CanWrite traps on plain/RMW/FP stores to read-only objects
(`sarcasm-ro-plain-store-att`/`-int`, `sarcasm-ro-rmw-att`,
`sarcasm-ro-fp-store-att`), the eff+size overflow-hole regressions
(`sarcasm-wrap-oob-read-att`/`-int`, `-write-att`, `-read16-att` — an
effective address in [2^64 - size, 2^64) now traps cleanly instead of
wrapping the upper-bound check and SIGSEGVing), the AVX512 `{k}`-masked and
AVX2 vector-masked access suite (`sarcasm-masked-*`, `sarcasm-vmaskmov-*`,
`needsAVX512` where AVX512 is used): in-bounds masked loads/stores with
all-ones/sparse/zero masks, merge and `{z}` forms
(`sarcasm-masked-move-att`/`-int`), success-by-masking below/above the
object and the zero-mask survives (`sarcasm-masked-slowpath-att`),
expand/compress popcount-fit successes incl. the byte-element N=64 forms
(`sarcasm-masked-expand-att`/`-int`), truncating masked stores
(`sarcasm-masked-trunc-att`), the AVX2 sign-bit-mask forms
(`sarcasm-vmaskmov-att`), the aligned masked forms
(`sarcasm-masked-aligned-att`), and the traps: completely-OOB masked
load/store, partially-OOB with ENABLED lanes out below/above, the
null-capability mask==0 load ("cannot access pointer with null object"),
the read-only masked store, expand-above/compress-below, the
truncating-store trap, the vmaskmov trap, and the misaligned aligned-form
trap (`sarcasm-masked-oob-*`, `sarcasm-masked-nullcap-att`,
`sarcasm-masked-ro-store-att`, `sarcasm-masked-expand-oob-att`,
`sarcasm-masked-compress-oob-att`, `sarcasm-masked-trunc-oob-att`,
`sarcasm-vmaskmov-oob-att`, `sarcasm-masked-aligned-oob-att`), the Phase-2 atomic pointer operations
(`sarcasm-aptr-loadstore-att`/`-int` — atomic load/store round-trips, mixing
with the plain forms in both directions, NULL round-trips, and GC-stress
churn; `sarcasm-aptr-cmpxchg-att`/`-int` — pointer compare-exchange
success/failure/ZF-consumer paths, the lock form, a null-lower "integer
guess" expected, and the retry-loop idiom; `sarcasm-aptr-rmw-att`/`-int` and
`sarcasm-aptr-armw-att`/`-int` — non-atomic and atomic pointer RMWs incl.
neg/not, with native ZF/CF consumers immediately after and capability
preservation proven by dereference; `sarcasm-aptr-stress-att` — 4 threads ×
10000 locked atomic RMWs on one pointer slot; `sarcasm-aptr-fp-att` — xmm
state preserved across the injected runtime calls), the pointer-alignment
traps (`sarcasm-misalign-loadptr-att`, `sarcasm-misalign-storeptr-att`,
`sarcasm-misalign-aloadptr-att`, `sarcasm-misalign-astoreptr-att`,
`sarcasm-misalign-casptr-att`), the cmpxchg16b 16-byte alignment trap at an
in-bounds word-aligned-but-not-16-aligned address — reported through the
dedicated align>8 fail stub (`sarcasm-misalign-cmpxchg16b-att`), the atomic-access OOB/read-only/null-cap
traps (`sarcasm-oob-aloadptr-att`, `sarcasm-oob-astoreptr-att`,
`sarcasm-oob-lsptr-att`, `sarcasm-oob-aptr-walk-att`,
`sarcasm-ro-astore-att`, `sarcasm-ro-casptr-att`, `sarcasm-ro-lsptr-att`,
`sarcasm-ro-alsptr-att`, `sarcasm-nullcap-aloadptr-att`,
`sarcasm-nullcap-astoreptr-att`), the
BMI1/BMI2/ADX/bsf/bsr/xadd/crc32 exact entries (`sarcasm-bmi-att`),
and every compile-time rejection (`filc/tests/sarcasm-reject-*` — including the
Intel-syntax AT&T-operand rejections `sarcasm-reject-intel-attmem`,
`sarcasm-reject-intel-attmem-fp`, and `sarcasm-reject-intel-enqcmd`, and the
ambiguous unsized narrowing convert `sarcasm-reject-cvt-unsized`, the
absolute-address (moffs) rejections `sarcasm-reject-absaddr-load` /
`-absaddr-store` / `-absaddr-num` / `-absaddr-alu`, the indirect-branch
moffs rejections `sarcasm-reject-jmp-indirect-abs` / `-call-indirect-abs` /
`-jmp-indirect-num`, and the Phase-2 atomic-annotation shape rejections:
`;! atomic ptr` on non-cmpxchg / register-form cmpxchg / 4-byte cmpxchg
(`sarcasm-reject-atomicptr-noncmpxchg` / `-regreg` / `-width`),
`;! atomic load ptr` on a store or a 4-byte load
(`sarcasm-reject-aloadptr-on-store` / `-width`), `;! atomic store ptr` on a
load or a 4-byte store (`sarcasm-reject-astoreptr-on-load` / `-width`),
`;! load store ptr` on a pure load / pure store / cmpxchg / xadd / a
`lock`ed form / an unsupported op (`sarcasm-reject-lsptr-on-load` /
`-on-store` / `-cmpxchg` / `-xadd` / `-lock`, and
`sarcasm-reject-loadstoreptr` on shl), `;! atomic load store ptr` on a
non-RMW (`sarcasm-reject-alsptr-nonrmw`), and the arm64 atomic-annotation
shape rejections (`sarcasm-reject-atomicptr-arm` — `;! atomic ptr` on casp,
the double-width CAS that cannot update an invisicap pair atomically;
`sarcasm-reject-atomicptr-casb-arm` on the sub-word casb;
`sarcasm-reject-aptr-aload-on-store-arm` / `-astore-on-load-arm` /
`-armw-nonrmw-arm` / `-armw-minmax-arm` — the direction/shape mismatches and
the unsupported min/max RMW ops; `sarcasm-reject-aptr-writeback-arm` — an
annotated atomic with a writeback memory operand no atomic encoding has). Also: `lock` on stack-frame accesses
(`sarcasm-reject-lock-stack-mov` / `-mov-intel` / `-add` / `-add-intel` —
the slot would virtualize/materialize before the `lock` validation runs,
silently dropping the prefix), cmpxchg8b/cmpxchg16b on stack-frame slots
(`sarcasm-reject-cmpxchg8b-stack`, `sarcasm-reject-cmpxchg16b-stack` — no
register form to virtualize into), and `;! atomic ptr` on cmpxchg8b
(`sarcasm-reject-cmpxchg8b-ptr`, the 8-byte twin of
`sarcasm-reject-cmpxchg16b-ptr`). The 61
`filc/tests/sarcasm-fp-*` tests cover the x86_64 FP/SIMD support end-to-end: SSE
scalar/packed arithmetic, AVX2/AVX512 (incl. embedded broadcast — off the heap
and off materialized stack slots alike — and opmask registers), MMX, x87,
AES/SHA/PCLMUL/GFNI crypto, truncating stores and half-precision conversions at
their exact narrow widths, AVX512-VNNI dot products at full vector width,
AVX512-IFMA vpmadd52luq/huq multiply-adds at full vector width
(`sarcasm-fp-ifma-att`, `needsAVX512`), the full-width unsigned
vcvtpd2uqq/vcvttpd2uqq converts and the AVX512-FP16 vcvtdq2ph/vcvtudq2ph
m512-source forms — bare ymm-dest ⇒ 64, x/y suffixes, Intel ZMMWORD PTR;
value-checked only where CPUID reports AVX512-FP16
(`sarcasm-fp-cvt-dq2ph-att`, `needsAVX512`), the
widening/narrowing convert zoo at its exact ratios (dest/2, 2× dest,
quarter-widths, BF16), the size-driven narrowing converts at their exact
x/y/z-suffix and Intel PTR widths plus the unambiguous bare-ymm m512 form
(`sarcasm-fp-cvt-narrow-att`, `needsAVX512`), full-width vdbpsadbw, the
vcvtusi2ss/sd +
vcvtt*/vcvt*2usi GPR-mixing converts (incl. l/q suffix synthesis on the
size-driven memory forms), lzcnt/tzcnt/popcnt memory forms at the destination
GPR's width, Intel x87 memory forms rendering at the correct AT&T suffix,
vpbroadcastb/w/d/q at their exact element widths
(memory and GPR sources), full-width vpermi2*/vpermt2* permutes and unmasked
expand/compress, fxsave/fxrstor, mixed GPR/vector
conversions, FP stack-slot materialization and GPR/vector slot aliasing, xmm
save/restore across pollchecks under GC stress, the width- and liveness-aware
form of that save/restore (`sarcasm-fp-live-*`: movsd/movss-only saves around
pollchecks and filc_allocate, dead-register sites with no saves at all,
mixed-width zmm/ymm/xmm state under FUGC churn, the movss-load zeroed-upper
case, and mixed liveness across the atomic-pointer runtime calls), and
per-width OOB traps
(movss/movsd/movdqa/ymm/zmm/fldt/mmx/vstmxcsr/vnni/cvtuqq2ps, plus the
p-stem class — `sarcasm-fp-oob-pabsd-att` (vpabsd zmm at the full 64 bytes),
`sarcasm-fp-oob-pminsd-att` (SSE pminsd xmm at 16),
`sarcasm-fp-oob-vnni-usd-att` (cross-sign vpdpwusd ymm at 32) — and
`sarcasm-fp-oob-dq2ph-att` (bare vcvtdq2ph ymm at 64, the bounds trap
firing before the FP16 instruction would execute — no FP16 silicon
needed)). Most behavioral cases are exercised in both
AT&T and Intel variants (`-att` / `-int` test pairs). Each `sarcasm-reject-*`
directory carries exactly ONE `.s` file, so every rejected input is proven rejected
individually.

The 261 aarch64 tests (`-arm` singletons) cover the arm64 backend end-to-end:
the same pointer/trap/call/alloca core as x86_64, plus the arm64-specific
surface — the NEON/FP support (17 `sarcasm-fp-*-arm` tests and
`sarcasm-neon-arm`): scalar, pair and structure loads/stores at their exact
widths (`sarcasm-neon-arm`, `sarcasm-fp-ldmulti-arm`), NEON arithmetic,
conversions and fp16 (`sarcasm-fp-arith-arm`, `sarcasm-fp-cvt-arm`,
`sarcasm-fpconv-arm`, `sarcasm-fp-half-arm`), frame-slot virtualization incl.
the AAPCS callee-saved d8-d15 writeback forms and GPR/vector slot aliasing
(`sarcasm-fp-frame-arm`), the width- and liveness-aware vector saves around
injected pollcheck/filc_allocate/atomic runtime calls
(`sarcasm-fp-live-*-arm`, `sarcasm-fp-gcstress-arm`), the ARMv8 crypto
known-answer tests (`sarcasm-fp-crypto-arm` — AES-128 FIPS-197 KAT, SHA-256
of "abc", pmull/pmull2 against a C carryless multiply), and per-width OOB
traps (`sarcasm-fp-oob-*-arm`, `sarcasm-neon-oob-arm`,
`sarcasm-half-oob-arm`); the atomics: the LSE RMW family
(`sarcasm-lse-arm`), cas/casp (`sarcasm-cas-arm`,
`sarcasm-casp-misalign-arm`), the load/store-exclusive family incl. a
hand-written ldxr/stxr CAS retry loop (`sarcasm-llsc-arm`), the
natural-alignment/OOB/read-only/null-cap atomic traps
(`sarcasm-atomic-misalign-arm`, `sarcasm-atomic-oob-arm`,
`sarcasm-atomic-ro-arm`, `sarcasm-nullcap-atomic-arm`), and the annotated
pointer atomics (`sarcasm-aptr-*-arm`, mirroring the x86_64 Phase-2 suite);
and the fixed-alloca region redirect off both sp and x29
(`sarcasm-alloca-redirect-arm`). Trap coverage is made systematic by the
`sarcasm-tm-*-arm` matrix (73 tests: the six fault categories crossed with
the GPR widths 1/2/4/8, the 16-byte NEON ldr/str q forms, and LSE swp/stxr
cells). Two manifest keys gate extension-dependent aarch64 tests:
`needsARMCrypto` and `needsLSE` — probed when run-tests starts by compiling
and running `filc/tests/has_armcrypto.c` resp. `filc/tests/has_lse.c`
(Linux hwcap-bit probes, the arm64 analog of the x86_64 `needsAVX512` cpuid
probe; a missing extension skips the test cleanly).

Trap coverage is systematic in the `sarcasm-tm-*` matrix (121 tests, all AT&T-syntax
x86_64 `return: failure` tests trapping in every subrun mode — default, scribble,
stop-the-world, release — and asserting the exact first-line `filc safety error`
message): the six fault categories — below-bounds, above-bounds,
above-bounds-overflow (an effective address near 2^64, so eff+size wraps a naive
upper-bound check), use-after-free, special object (direct access of a
`zweak_new()` object), and null capability (an integer address) — crossed with
every access width 1/2/4/8/10/16/32/64 in both load and store directions
(movb/movw/movl/movq GPR forms, the x87 fldt/fstpt tbyte, movdqu xmm, vmovdqu
ymm, vmovdqu64 zmm — the zmm cells are `needsAVX512`): the 96 core cells. Extras
round out the interesting instructions: fxsave's 512-byte store in all six
categories (fxrstor in three), 6-byte lfs far-pointer loads, the
cmpxchg16b/cmpxchg8b locked-RMW paths (below/UAF/special/null-cap/overflow),
AVX512 `{k}`-masked vmovdqu32 loads and stores on freed and special objects, and
embedded-broadcast `{1to16}` element checks below/above. Masked-cell message
attribution is subtle: a masked LOAD from a freed or special object falls to the
mask-refined bounds slow path and reports "masked read not in bounds (even
accounting for the mask)." — the masked fail function has no free/special
distinction; a masked STORE to a FREED object trips the CanWrite aux-flags test
(READONLY|FREE) BEFORE the bounds slow path and therefore reports "cannot access
pointer to free object." (a size=0 origin — exactly like the Fil-C compiler's
masked-store check), while a masked store to a SPECIAL object passes CanWrite
(special is not in the READONLY|FREE mask) and reports "masked write not in
bounds ...". The pre-existing non-matrix trap tests are unaffected and
complementary: `sarcasm-oob-*`/`sarcasm-fp-oob-*` cover above-bounds widths,
straddles and exotic instructions in both syntaxes, `sarcasm-nullcap-*` the
null-capability forms, `sarcasm-wrap-oob-*` the eff+size overflow-hole
regressions, `sarcasm-ro-*` the read-only CanWrite traps, and
`sarcasm-masked-*`/`sarcasm-vmaskmov-*` the masked success/trap forms — the
matrix adds the missing categories (below-bounds, use-after-free, special) and
makes the width coverage systematic.

The old in-tree `tests/` harness (host-lute `verify.sh`/`verify-x86.sh` via docker,
plus the Luau unit tests) has been removed; its coverage now lives in
`filc/tests/sarcasm-*`.

See `ABI-NOTES.md` / `ABI-NOTES-x86.md` for the decoded Fil-C ABIs and `DESIGN.md` for
the architecture.
