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
  `;! atomic load ptr` (`;! atomic store ptr` for atomic stores) — x86_64 only;
  these go through the Fil-C runtime (`filc_load_ptr_atomic_with_manual_tracking_outline`
  / `filc_store_ptr_atomic_outline`), exactly like C11 `_Atomic` pointer accesses
  compiled by filcc;
- on `cmpxchgq` with a memory destination: `;! atomic ptr` — a pointer
  compare-exchange through the runtime
  (`filc_strong_cas_ptr_with_manual_tracking`; the `lock` prefix is allowed and
  irrelevant, both forms make the same call). The expected value is the
  accumulator (compared by raw intval, like the hardware), the old value comes
  back in the accumulator WITH its capability, and flags are recomputed as
  (expected − old) so a `je`/`sete` immediately after behaves natively;
- on a memory-destination RMW over a pointer slot (8-byte add/adc/and/or/sbb/
  sub/xor, inc/dec/neg/not): `;! load store ptr` — a NON-atomic
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
  capability model — use a cmpxchg loop);
- on each call: the callee's signature, e.g. `bl foo ;! int(ptr, size_t)`;
- on stack allocations: `;! alloca size (x)` on the `sub sp,...` and `;! alloca result (x)`
  on the instruction that yields the pointer (dynamic), or `;! alloca result size=N` for a
  fixed-size buffer. These become GC allocations (`filc_allocate`), not real stack memory.

Annotations are validated, never silently ignored: `;! load ptr` / `;! store ptr`
require a plain 8-byte GPR load/store of the matching direction (and the
`;! atomic load ptr` / `;! atomic store ptr` forms are at least as strict); a
memory-destination RMW (add/xadd/cmpxchg & co with a memory destination)
annotated with either is rejected (pointer RMWs need `;! load store ptr`);
the pointer-RMW/atomic annotations require exactly the shapes above (8-byte
forms only; `;! atomic ptr` only on memory-destination cmpxchg) and are
rejected on ARM64 (x86_64-only for now) and on
cmpxchg8b/cmpxchg16b, which cannot operate on pointers; any other
unrecognized annotation string is a compile-time error.

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
  accesses hit the same rejection as heap ones. FP/SIMD stack accesses needing
  more than 16-byte alignment (e.g. `vmovdqa32` with ymm/zmm) are rejected —
  the ABI guarantees only 16-byte stack alignment; use the unaligned form.
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
  lanes — a contiguous full-width access). The implicit-register GPR
  instructions are genuinely MODELED via pin-in/pin-out copies, not passed
  through with a conservative def/use guess: div/idiv (rdx:rax dividend in,
  quotient/remainder out), mul and 1-operand imul (rax in, rdx:rax product
  out), mulx (implicit rdx source), cmpxchg (accumulator RMW + destination
  RMW), cmpxchg8b/cmpxchg16b (the implicit expected-value RMW pair edx:eax
  resp. rdx:rax plus the implicit new-value source ecx:ebx resp. rcx:rbx —
  all four pinned), and the cqo/cdq/cwd sign-extends (rax in, rdx out) all name their
  implicit rax/rdx effects to the web analysis; synthesized moves then copy
  the current webs of the implicit-use registers into their physical registers
  before the instruction and back out into fresh webs after it (coalesceable —
  free when the user already wrote rax/rdx), and the emitted instruction shows
  only its explicit operands. Intel PTR-sized memory forms of the family
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
  touch all addressed bytes (gather/scatter, vmaskmov*/maskmov*, AVX512
  {k}-masked memory operands — including the masked forms of
  vexpand*/vcompress*, whose unmasked forms are supported as just described),
  implicit operands the
  checker cannot see or model (pcmpestri/pcmpistri/pcmpestrm/pcmpistrm —
  implicit rax/rdx/rcx GPRs;
  cpuid/rdtsc/rdtscp/xgetbv/rdpkru/wrpkru/monitor/mwait/umwait/tpause —
  implicit GPR reads/writes the def/use model cannot express, cpuid alone
  writing rax/rbx/rcx/rdx, umwait/tpause reading the implicit edx:eax
  TSC-deadline pair; umonitor — monitoring-class hardware armed on a memory
  range the checker cannot size; clzero/xlatb — implicit memory operands;
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
  (`jmp *%rdi`), and register-based memory-indirect branches (bounds-checked);
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
  `ABI-NOTES-x86.md`); marshalling it is deferred future work. On ARM64, neon
  registers are uniformly rejected pending proper FP/SIMD support. Three known
  PRE-EXISTING issues (all reproduced on the unmodified baseline, NOT
  introduced by the current change) are documented in DESIGN.md's Limitations:
  a regalloc mis-coloring at ≥~13 simultaneously-live webs, injected
  bounds checks clobbering EFLAGS (reg-only flag chains are unaffected),
  and detect.luau's arch autodetect falling back to ARM64 for register-free
  x86 input — or input whose only registers are xmm-class (a lone `movss
  myglobal, %xmm0`; the detector keys on GPR markers) — (the input then
  fails later at `as` — confusing but harmless).
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
  `;! atomic ptr` on cmpxchg, and the atomic forms of `;! atomic load store
  ptr`) go through the Fil-C runtime exactly like filcc-compiled C11 atomic
  pointer accesses: sarcasm emits its usual inline access check first (so traps
  get good origins — the runtime re-checks internally), then calls
  `filc_load_ptr_atomic_with_manual_tracking_outline` /
  `filc_store_ptr_atomic_outline` / `filc_strong_cas_ptr_with_manual_tracking`
  in plain SysV marshalling (a `filc_ptr` is two consecutive words,
  intval-then-lower; `filc_strong_cas_ptr_with_manual_tracking`'s `new_value`
  travels on the stack). Atomically-stored slots are **boxed** (a 16-byte
  atomic box behind the aux entry, updated with `lock cmpxchg16b`); the plain
  `;! load ptr` path is box-aware, so plain and atomic accesses to the same
  slot interoperate. The runtime functions are `nounwind` (failures are fatal
  filc panics), so no exception check follows these calls; returned lowers are
  rooted into the frame's GC root slots immediately (the calls that can
  allocate are GC safepoints).

## Testing
All testing is via the Fil-C test suite: the 361 `filc/tests/sarcasm-*` tests (311
x86_64, 50 aarch64) run with `filc/run-tests -f sarcasm` from the repo root. Each
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
`sarcasm-cmpxchg16b-att`/`-int`), the `lock` prefix on the modeled
memory-destination RMWs (`sarcasm-lock-rmw-att`/`-int`, and the
`sarcasm-oob-lock-xadd-att`/`sarcasm-oob-cmpxchg16b-att` traps), the
not-readonly CanWrite traps on plain/RMW/FP stores to read-only objects
(`sarcasm-ro-plain-store-att`/`-int`, `sarcasm-ro-rmw-att`,
`sarcasm-ro-fp-store-att`), the Phase-2 atomic pointer operations
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
non-RMW (`sarcasm-reject-alsptr-nonrmw`), and the whole atomic family on
ARM64 (`sarcasm-reject-atomicptr-arm`). Also: `lock` on stack-frame accesses
(`sarcasm-reject-lock-stack-mov` / `-mov-intel` / `-add` / `-add-intel` —
the slot would virtualize/materialize before the `lock` validation runs,
silently dropping the prefix), cmpxchg8b/cmpxchg16b on stack-frame slots
(`sarcasm-reject-cmpxchg8b-stack`, `sarcasm-reject-cmpxchg16b-stack` — no
register form to virtualize into), and `;! atomic ptr` on cmpxchg8b
(`sarcasm-reject-cmpxchg8b-ptr`, the 8-byte twin of
`sarcasm-reject-cmpxchg16b-ptr`). The 53
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
save/restore across pollchecks under GC stress, and per-width OOB traps
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

The old in-tree `tests/` harness (host-lute `verify.sh`/`verify-x86.sh` via docker,
plus the Luau unit tests) has been removed; its coverage now lives in
`filc/tests/sarcasm-*`.

See `ABI-NOTES.md` / `ABI-NOTES-x86.md` for the decoded Fil-C ABIs and `DESIGN.md` for
the architecture.
