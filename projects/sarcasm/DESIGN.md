# sarcasm design & build status

SAfe Runtime Capability-enforced Assembler: an ARM64 and X86_64 assembler (in Luau, run via
`lute`) that rewrites Yolo-C assembly into memory-safe, Fil-C-linkable assembly, then invokes
`as`. The target architecture — and, for X86_64, the AT&T vs Intel input syntax — is
auto-detected from the input text.

## Pipeline
```
detect arch/syntax (detect.luau)  ->  parse (arm64_parse.luau / x86_64_parse.luau)
   ->  split into functions (driver)  ->  frame preprocessing (frame.luau + per-arch frame policy)
   ->  lift to IR (register webs; lift.luau)  ->  pointer-flow (ptrflow.luau)
   ->  GIMSO transform (intval/lower, ptr ld/st, calls, pollchecks, SOV; transform.luau
       + per-arch codegen)  ->  IRC regalloc (regalloc.luau)  ->  spill-slot packing (driver)
   ->  emit body + prologue/epilogue (emit.luau + per-arch render)  ->  glue (per-arch glue)
   ->  write .yolo.s  ->  as -o .o
```

The safety-critical logic lives ONCE in the shared modules; each architecture supplies a
backend bundle (`arm64_*` / `x86_64_*`: parse, isa, frame, codegen, render, glue) behind a
common interface, so both ISAs share the lift/pointer-flow/transform/regalloc/emit pipeline.

## Module status

Shared (architecture-independent):
- `detect.luau`     — DONE + TESTED (exercised by every filc/tests sarcasm test, in both
  x86 syntaxes). Auto-detects arm64 vs x86_64 (and att vs intel).
- `sig.luau`        — DONE. Signature encoding (verified against clang: 1066/2529/12769).
- `frame.luau`      — DONE. Frame preprocessing skeleton; per-arch policy plugs in.
- `lift.luau`       — DONE + TESTED (via filc/tests; see Verification).
- `ptrflow.luau`    — DONE. Pointer-flow analysis over the lifted IR.
- `transform.luau`  — DONE. The GIMSO transform (see below).
- `regalloc.luau`   — DONE + TESTED. IRC: CFG, liveness, interference, coalesce, spill.
- `emit.luau`       — DONE. Shared emission: reload elimination, spill bookkeeping, self-move
  dropping; per-arch render module supplies instruction text + prologue/epilogue.
- `build.luau`      — DONE. Constructors for synthesized IR nodes.
- `numlabel.luau`   — DONE. GNU-as numeric local labels (`1:` / `1f` / `2b`): resolves
  f/b references and renames definitions to unique private symbols at parse time.
- `sarcasm.luau`    — DONE. Driver: function splitting, orchestration, spill-slot packing,
  `as` invocation, CLI.
- `ABI-NOTES.md` / `ABI-NOTES-x86.md` — complete ABI references.

Per-architecture backends (`arm64_*` / `x86_64_*` pairs) — both DONE + VALIDATED:
- `*_parse.luau`   — operand parser + `;!` annotations. x86_64 parses BOTH AT&T and Intel
  syntax into the common dest-first operand model. Both parsers accept GNU-as numeric
  local labels (`1:` may be defined repeatedly; `1f`/`1b` reference the next/previous
  definition, including as a memory displacement like `1f(%rip)`): numlabel.luau renames
  each definition to a unique private symbol and rewrites the references at parse time,
  so numeric labels work in branches and loops like any named label. A reference with no
  definition in the requested direction is rejected (`unresolved numeric label
  reference`). In Intel-syntax mode an AT&T-style parens operand field
  (disp(base,index,scale)) is rejected outright — "AT&T-style operand in
  Intel-syntax input (use [bracket] memory operands)": without the explicit
  check such a field fell through to parseSym and RE-RENDERED verbatim as
  valid AT&T memory syntax with Intel dest-first operand order applied and NO
  capability/bounds check — a total check bypass (`movq (%rdi), %rsi` in
  Intel mode emitted an unchecked 8-byte store). Any field containing parens
  is rejected (covering the parseSym fallthrough, the numeric-prefix immediate
  path, and whitespace-dodged forms); the only legitimate parens in an Intel
  operand are the x87 stack-register name st(N).
- `*_isa.luau`     — instruction semantics: register defs/uses, control flow. On
  x86_64 this is also where the implicit-register GPR instructions are MODELED:
  div/idiv (implicit rdx:rax dividend use, quotient/remainder def), mul and
  1-operand imul (rax use, rdx:rax product def), mulx (implicit rdx source,
  not written), cmpxchg (implicit accumulator RMW alongside the explicit
  destination RMW), cmpxchg8b/cmpxchg16b (the implicit expected-value RMW
  pair edx:eax resp. rdx:rax and the implicit new-value source ecx:ebx resp.
  rcx:rbx — all four pinned), the cqo/cdq/cwd sign-extends (rax use, rdx def),
  and the zero-explicit-operand implicit-only family — cpuid (eax/ecx uses;
  eax/ebx/ecx/edx defs), rdtsc (eax/edx defs), rdtscp (eax/edx/ecx defs),
  xgetbv (ecx use; eax/edx defs), rdpkru (ecx use; eax/edx defs), wrpkru
  (eax/ecx/edx uses), monitor (rax/rcx/rdx uses), mwait (eax/ecx uses) — name
  their implicit rax/rdx effects with implicit def/use operand tables the web
  analysis connects to the surrounding code; codegen's emitPinned then pins
  them to the physical registers with synthesized moves AROUND the instruction
  (the reaching webs of the implicit-use registers are copied into physical
  rax/rdx before it, the result webs copied back out into fresh webs after it
  — regalloc coalescing makes the copies free when the user already wrote
  rax/rdx), and the emitted instruction shows only its explicit operands (the
  implicit-only family renders as the bare mnemonic). monitor's implicit rax
  address is deliberately NOT modeled as a memory operand: MONITOR does not
  access memory, so there is nothing to bounds-check — a wild address can
  only fault, an uncatchable-signal safe halt the safety model accepts. An
  explicit operand naming a pinned register renders as the fixed physical
  register, keeping it in sync with the pin. cbw/cwde/cltq need no pinning:
  codegen rewrites them to a renameable movsxx on the rax web.
- `x86_64_fp.luau` — DONE + TESTED (the sarcasm-fp-* tests). The x86_64 FP/SIMD
  knowledge module, consulted by the isa classifier (def/use modeling +
  rejections), the codegen (checked-access width/alignment), and the frame policy
  (stack-slot widths): per-mnemonic memory access widths/alignments (scalar and
  packed FP, vector moves, MMX, x87, AES/SHA/PCLMUL/GFNI crypto — SM3/SM4 also
  have width-table entries but are execution-untested on the current dev
  hardware —, opmask k moves, fxsave/fxrstor=512; embedded broadcast `{1toN}` =
  one element; vpbroadcastb/w/d/q memory sources = the exact element width
  1/2/4/8; exact narrow widths for the truncating stores — vpmovqb/qw/qd/
  db/dw/wb and the saturating vpmovs*/vpmovus* forms = source vector bytes /
  element ratio — and for vcvtps2ph/vcvtph2ps (half width on the ph side);
  sgdt/sidt=10, sldt/str/smsw=2, lss/lfs/lgs = destination size + 2-byte
  selector; movnti = the source register's width, never a guessed default;
  vpermi2*/vpermt2* and the unmasked vexpand*/vcompress*/vpexpand*/vpcompress*
  forms = full vector width; the AVX512-VNNI dot products vpdpbusd(s)/
  vpdpwssd(s)/vpdpbssd(s) = full vector width (the ss/sd suffix rule would
  otherwise pin them to 4/8 bytes) and vp4dpwssd(s) = 16 bytes; vdbpsadbw =
  full vector width; the AVX512-IFMA 52-bit multiply-adds
  vpmadd52huq/vpmadd52luq = full vector width (exact entries — the digits
  keep them out of the p-family pattern); the full-width unsigned converts
  vcvtpd2uqq/vcvttpd2uqq = full vector width (8-byte elements on both
  sides, like vcvtpd2qq); the ss/sd/ps/pd scalar-width suffix rule EXCLUDES
  p-stem mnemonics — after the optional 'v', a stem starting with 'p' is
  the packed-INTEGER family, where a trailing "sd"/"ss"/"ps"/"pd" is part
  of the NAME, not a scalar suffix — so the whole "sd"-ending packed class
  (vpabsd/vpmaxsd/vpminsd and the SSE pabsd/pmaxsd/pminsd, the cross-sign
  VNNI vpdpwusd(s)/vpdpbsud(s)/vpdpwsud(s), vpopcntd, ...) falls through
  to the p-family pattern at FULL vector width instead of being
  under-checked at 4/8 bytes, closing that under-check class generically
  rather than by whack-a-mole entries (scalar FMA keeps its width:
  vfmadd231sd's stem is "fmadd231" -> 8, as do the true scalar ss/sd
  forms); the suffix rule also resolves the packed AVX512-FP16 suffix ph
  to full vector width (like ps/pd), while the SCALAR FP16 sh forms are
  deliberately NOT matched — a width from the rule would be wrong for the
  GPR-mixing scalar-half converts (vcvtusi2sh's integer source is m32/m64)
  and would leave vcvtsh2si's GPR destination unmodeled, so every sh form
  stays unknown and a memory-operand one rejects cleanly; the widening
  convert zoo — the
  vcvtudq2pd/vcvtdq2pd/vcvtps2uqq families = half the destination width, the
  vcvtph2pd/vcvtph2qq/vcvtph2uqq quarter-widths,
  vcvtne2ps2bf16 = full width; the NARROWING converts (vcvtpd2ps & siblings —
  vcvtpd2dq/vcvttpd2dq/vcvtpd2udq/vcvttpd2udq/vcvtuqq2ps/vcvtqq2ps/
  vcvtneps2bf16, vcvtps2phx, and the pd2ph/dq2ph family) SIZE-DRIVEN, because
  the destination register class does not determine the memory source width
  (vcvtpd2ps reads m128 into an xmm, m256 into an xmm, or m512 into a YMM; the
  ph family reads m128/m256/m512 into an xmm every time — except the
  vcvtdq2ph/vcvtudq2ph .512 form, whose destination is a YMM like the ps/dq
  family's): the width comes from
  the Intel PTR size annotation or the AT&T x/y(/z) source suffix at exact
  widths (XMMWORD PTR or vcvtpd2psx = 16, vcvtpd2psy = 32, vcvtpd2phz = 64 —
  the ph-quad family's .512 form shares the xmm destination, so the z suffix
  is its only gas-encodable sized spelling), a bare unsized memory form is
  accepted only when the destination class is unambiguous (vcvtpd2ps (%rdi),
  %ymm0 ⇒ .512 ⇒ m512 — and likewise vcvtdq2ph/vcvtudq2ph with a ymm
  destination ⇒ m512 = 64: their .512 form has NO z-suffixed spelling
  (`vcvtdq2phz` does not assemble), so the bare ymm-dest form is its only
  gas-encodable sized spelling, with the x/y suffixes at 16/32 and ZMMWORD
  PTR driving the exact width in Intel syntax; the two are AVX512-FP16
  instructions — this dev machine has no FP16 silicon, so their acceptance
  is compile-time- and pre-execution-trap-proven) and is otherwise rejected
  cleanly ("unsized memory
  operand is ambiguous; use a size suffix or PTR annotation") BEFORE anything
  gas would fail is rendered, a PTR size that is not a legal source width for
  the family and a suffix/destination-class combination the ISA does not have
  are likewise rejected cleanly, and the renderer synthesizes the source-width
  suffix for a bare mnemonic with a sized (Intel PTR or materialized frame
  slot) memory operand; lzcnt/tzcnt/popcnt memory sources (incl. the
  AT&T w/l/q suffixes) = the destination GPR's byte width, and likewise the
  BMI1/BMI2/bsf/bsr exact entries (shlx/sarx/shrx/andn/bextr/blsi/blsr/
  blsmsk/bzhi/pdep/pext/rorx first-reg-def/rest-use, bsf/bsr — only the
  gas-encodable spellings exist, so there are no 16-bit BMI forms), xadd (RMW
  on BOTH explicit operands), and adcx/adox/crc32 (RMW destination — adcx/adox
  DO have r/m source forms; crc32's memory width is the crc SOURCE width from
  the b/w/l/q suffix, source register, or PTR annotation, and an illegal
  destination/source width combination is rejected cleanly — bare+sized crc32
  mem forms render with the explicit suffix synthesized), all at the
  shared/destination operand width), GPR def/use
  roles of mixed GPR/vector instructions (incl. the vpbroadcastb/w/d/q
  GPR-source forms, which READ the source GPR — an unmodeled read was a
  stale-register miscompile — and the vcvtusi2ss/vcvtusi2sd GPR/integer
  source with the reverse vcvtt*/vcvt*2usi GPR destination, the same
  stale-register class; the size-driven cvt-int memory forms synthesize the
  l/q AT&T suffix at render — `vcvtusi2ss QWORD PTR [rdi]` emits
  `vcvtusi2ssq`), the authoritative-width rule (the resolved
  ISA-fixed width never defers to an Intel PTR size annotation — a
  contradicting annotation is REJECTED, on the heap and stack paths alike;
  only the size-driven widths — the x87 PTR fallback and the cvtsi2ss/sd
  integer source — take their width from the annotation), the masked-access
  metadata (fp.maskedAccessInfo: the supported {k}-masked vector moves,
  truncating stores, expand/compress forms and the AVX2 vmaskmov/vpmaskmov
  forms get (element, lanes, vecsize, contiguous) metadata for the
  transform's mask-aware check — masked forms of anything else stay rejected,
  as do {%k0} and {k}-masked stack accesses), and the
  unsafe-instruction reject list
  (syscall/port-I/O/privileged/string-ops/non-lock prefixes/gather/scatter/
  maskmovdqu-maskmovq/
  xsave/x87-state/pcmpestri-family/implicit-GPR ops umwait/tpause
  —/implicit-memory-operand ops/monitoring-class umonitor (a memory range the
  checker cannot size)/AMX tiles (a strided, tile-config-dependent
  footprint)/far control transfers).
- `*_frame.luau`   — frame policy: drop the input's frame setup/teardown, virtualize
  stack-pointer/frame-pointer-relative slots, reject stack-address escapes.
- `*_codegen.luau` — per-arch instruction emitters (neutral micro-ops) for the transform.
- `*_render.luau`  — render IR back to assembly with colors; synthesize the Fil-C
  prologue/epilogue/frame layout. (x86_64 always emits AT&T output.)
- `*_glue.luau`    — getter/FO/2ET/origins/access-origin/alias link & run, plus the weak
  callsite resolver thunk for called externals. (x86_64: the 2ET generic-entrypoint
  thunk skips the actual-vs-expected argument-size check for zero-argument signatures —
  `actual <= argBytes - 1` would be `actual <= -1`, i.e. unsigned-always — matching
  clang's thunk, which has no check there; the thunk is a weak symbol that must remain
  link-compatible with clang's.)

NOTE (x86_64 vs arm64 CC packing): BOTH fast-CC packings are DENSE — a scalar arg
consumes one register slot, a pointer arg two consecutive slots. x86_64 packs from rdx
across rdx,rcx,r8,r9 (4 words max); arm64 packs from x2 across x2..x7 (6 words max);
clang passes anything wider on the stack (sarcasm rejects such signatures). arm64 used
to implement the older FIXED-PAIR packing (arg k always in x(2+2k)/x(3+2k)), which only
coincides with dense packing when every arg before k is a pointer; it was ported to
dense packing after verifying pizlonated clang's aarch64 output (e.g.
`long(long,long,ptr)` puts arg1 in x3 and arg2's intval/lower in x4/x5).

NOTE (arm64 alloca region redirect): the x86_64 `regionRedirect` mov branch
(`movq %rsp, %rd` re-deriving a region pointer) was fixed to redirect to
`buffer + (0 - region.base)` instead of `buffer + 0` — the old form was correct only
for a region based at sp+0. arm64's `regionRedirect` mov branch (`mov xD, sp`) has the
identical base-0 assumption (`cg.move(rd, r.ptrTemp, true)`): it is correct only when
the region's base is 0 and should become `cg.addImm(rd, r.ptrTemp, -r.base)`. arm64
also does not recognize x29-based alloca bases or normalize x29-relative offsets in
region/slot math the way x86_64 now does for rbp (see x86_64_frame.rewrite /
x86_64_codegen.allocaRegionBase / stackOff in cg.regionRedirect). A future arm64
session should port these fixes.

## Core stages

### lift.luau — asm -> IR over register "webs"
Faithful reallocation of the whole GPR file requires turning physical-register live
ranges into virtual temps. Approach (no full SSA needed):
1. Build CFG (reuse regalloc.buildCFG shape).
2. Reaching-definitions dataflow per physical GPR.
3. Union-find "webs": union each use with every def of the same reg that reaches it.
   Entry pseudo-defs for CC input regs (ARM64 example: x0=myth, x2/x3=arg0 iv/lower,
   x4/x5=arg1, ...). Each web = one temp id.
4. Emit copies at CC boundaries so precolored physical webs stay tiny:
   - entry: `vMyth = x0`, `vArg0iv = x2`, `vArg0lo = x3`, ...
   - call:  move args into the arg registers (precolored), call, move results out to
     virtuals.
   - return: move the ret virtual into the result register (+ lower if ptr), flags in
     the flags result.
5. Each IR insn keeps its mnemonic + operands, with reg operands replaced by
   `{temp=id, width=..}` refs so the emitter can substitute the assigned color.
   Spill-slot ld/st (within the input frame) become copies to/from a spill-slot temp
   ("spill slots as locals").

### frame.luau — prologue/epilogue recognition
Matches the idiomatic prologue (ARM64: `stp x29,x30,[sp,#-N]!` or `sub sp,sp,#N` + `stp`
saves + `mov x29,sp`; X86_64: `push %rbp`/`mov %rsp,%rbp`/`sub %rsp` + callee-saved
pushes, `leave`, `endbr64`) and the symmetric epilogue. Records N, the callee-saved set,
and the spill-slot region. On X86_64, rbp-relative displacements are normalized to
rsp-relative frame offsets via frameSize when rbp is the frame pointer (rbp = rsp +
frameSize), and slots are KEYED by that normalized offset — so `-8(%rbp)` and `8(%rsp)`
(addressing the same byte with a 16-byte frame) share one slot web, while `-8(%rbp)`
and `-8(%rsp)` (different bytes) stay distinct. Any remaining stack access outside the
analyzed frame [0, frameSize) is rejected (on X86_64 the range is extended down by the
128-byte SysV red zone for rsp-relative and normalized rbp-relative offsets alike —
with rbp = rsp + frameSize, an rbp-relative d in [-frameSize-128, -frameSize), e.g. the
gcc -O0 leaf `-8(%rbp)` with no `subq` at all, IS the red zone), as is taking the
address of the stack frame at all
(e.g. `add xD, sp, #k` / `leaq 8(%rsp), %rax` / `movq %rsp, %rax` — safety cannot be
proven).
sarcasm SYNTHESIZES its own frame regardless (for the SOV check + filc_frame push +
callee-saved for the new allocation), discarding the input's frame ops.

#### x86_64: no mid-function stack-pointer movement
Frame geometry is sound ONLY if every stack access executes with rsp at one known
value, so on x86_64 the frame size is derived from the PROLOGUE PREFIX ONLY: the
leading run of frame-setup instructions (callee-saved pushes/pops, `movq %rsp,%rbp`,
constant `subq $imm,%rsp` allocations and net-balanced `addq $imm,%rsp` undos within the
prefix), interleaved with instructions that cannot observe or modify the stack state;
the prefix ends at the first stack access, control-flow instruction, jump-target label,
or rsp/rbp-frame clobber. frameSize is the NET rsp depth at the end of the prefix —
relative to the frame pointer when one is established (so rbp = rsp + frameSize holds
for the post-prologue rsp) — hence a transient `subq $8,%rsp; addq $8,%rsp` pad or
`pushq %rbx; ...; popq %rbx` pair inside the prefix nets out and cannot inflate
frameSize (counting such pairs once, as a whole-body scan does, desyncs the rbp<->rsp
normalization AND the out-of-frame bounds check — a silent miscompile).

After the prologue, rsp must not move in ways sarcasm cannot prove safe — there is NO
mid-function stack-pointer movement: a control-flow rsp-depth analysis proves the
abstract depth (bytes below the entry rsp, or "unknown") at which every instruction
executes, and the frame rewrite rejects, with a clean `sarcasm: <file>: <msg>` error:
- constant (`subq`/`addq $imm`) or non-constant rsp adjustments that are not epilogue
  teardown — teardown being an `addq $imm,%rsp` / `movq %rbp,%rsp` leading to `ret`
  through callee-saved pops and ordinary, non-stack computation only (a `leave` is
  always teardown; it is rejected when no frame pointer was established). Dynamic
  allocation must use the `;! alloca` annotation — it is the supported mechanism, not
  raw `subq %rax, %rsp`;
- stack accesses executed while rsp is perturbed or of unknown depth (between a
  mid-function push/sub and its matching pop/add the same slot key would name two
  different addresses), and returns (or indirect tail jumps) with an unbalanced or
  unknown stack pointer;
- mid-function pushes/pops of non-callee-saved operands, and pops of the frame pointer
  that are neither inside verified teardown nor provably paired with the outstanding
  save of rbp (a paired `popq %rbp` — e.g. the leaf `popq %rbp; ret` needing no frame
  cleanup — is a sound epilogue restore; the depth analysis rejects any stack access
  or unbalanced return after it);
- establishing the frame pointer (`movq %rsp,%rbp`) outside the prologue;
- `enter`/`enterq` — packed push-rbp/`mov %rsp,%rbp`/`sub $imm,%rsp` frame setup that
  sarcasm does not model; passed through it would shift rsp and clobber rbp inside the
  synthesized Fil-C frame (frame setup must use the canonical three-instruction form);
- vector-INDEXED memory operands (gather/scatter: an xmm-class register as the
  memory base or index) — they touch multiple discrete addresses that cannot be
  bounds-checked. FP/SIMD registers as VALUES are in scope: instructions naming
  them pass through the frame policy, and their stack-frame accesses are
  materialized rather than virtualized (see the FP/SIMD subsection below).

Balanced callee-saved push/pop save/restore pairs ARE permitted anywhere the depth
analysis stays consistent (e.g. gcc's shrink-wrapped saves behind a conditional
branch): they are dropped — sarcasm's synthesized frame preserves the callee-saved
registers it actually uses — which is sound exactly because the depth analysis rejects
every stack access and return that could observe the shifted rsp. The alloca-annotated
dynamic `subq %rax, %rsp` makes the depth "unknown" until `leave`/`movq %rbp,%rsp`
restores it, so raw stack accesses in its scope are rejected while the annotated
alloca machinery itself (redirected to a GC allocation) keeps working. The alloca pops
nothing, so the abstract save stack SURVIVES across it (and across the inert
computation in its scope — including further annotated allocas): the fp restore
(`leave`, or `movq %rbp,%rsp` — clang -O0's VLA epilogue) revives both the known depth
and the save shape, and the teardown pops after it (`popq %rbp`, callee-saved
restores) pair with the prologue saves exactly as without an alloca.

Dropping a callee-saved pop is sound ONLY when the pop provably restores a matching
dropped push: alongside the depth, the analysis tracks an abstract save stack (the
outstanding pushes — register + slot depth — in push order; merges require agreement
on every path), and a pop is rejected when no outstanding push of the SAME register at
the SAME slot depth is on top (mid-function or inside a teardown region alike). An
unpaired pop's load would otherwise be silently lost, and the slot it actually reads
is not that register's save — an unpaired `popq %rbx` after `pushq %rbp` reads the
saved frame pointer (a live stack address) into rbx. The same pairing rule nets out
transient save pairs inside the prologue prefix, so such a pop can no longer masquerade
as balancing the frame-pointer save. Epilogue restores of prologue saves, balanced
shrink-wrapped pairs, and verified-teardown pops all pair exactly and keep being
dropped.

While rbp is the frame pointer it is a stack register (rbp = rsp + frameSize), so
reading it as a VALUE — `movq %rbp, %rax`, arithmetic on it, or using it as a memory
INDEX register (`movq (%rdi,%rbp,1), %rax`) — is the same stack-address escape class
as reading rsp and is rejected (the frame setup/teardown paths that legitimately name
rbp — `movq %rsp,%rbp`, `movq %rbp,%rsp`, `leave`, teardown `popq %rbp` — are
unaffected). An rsp memory index (`movq (%rdi,%rsp,1), %rax`, which the encoding
forbids but the parser accepts) is rejected on the same path instead of crashing the
assembler.

#### x86_64: FP/SIMD registers, materialization, and injected-call saves
FP/SIMD registers (xmm/ymm/zmm, MMX mmN, x87 st/st(N), opmask k0-k7) are IN SCOPE.
sarcasm never register-allocates them — it needs no vector registers for the Fil-C
checks, so their register numbers would only collide with GPR numbers in the web
analysis — and the calling convention makes none of them callee-save, so no usage
validation is needed: instructions naming them pass through with their vector
operands verbatim. Only the GPR operands are modeled in defs/uses — the memory
base/index, and the GPR halves of mixed GPR/vector instructions (cvtsi2sd, movd,
pinsrw, cvttsd2si, movmskps, kmov, fnstsw %ax, the GPR source of
vpbroadcastb/w/d/q, ...) with their correct def/use
roles. A memory operand of an FP/SIMD instruction is bounds-checked by the
transform at the width the x86_64_fp.luau knowledge module assigns the mnemonic
(movss=4, movsd=8, xmm vector=16, ymm=32, zmm=64, MMX=8, x87 tbyte=10,
fxsave/fxrstor=512, embedded broadcast {1toN}=element width, vpbroadcast
memory sources at the exact element width 1/2/4/8, truncating stores
— vpmovqb/qw/qd/db/dw/wb and the saturating vpmovs*/vpmovus* forms — at the
source vector bytes / element ratio, vcvtps2ph/vcvtph2ps at half width on the
ph side, the AVX512-VNNI dot products vpdpbusd(s)/vpdpwssd(s)/vpdpbssd(s) at
full vector width (vp4dpwssd(s)=16), vdbpsadbw at full vector width, the
AVX512-IFMA vpmadd52huq/vpmadd52luq at full vector width, the full-width
unsigned vcvtpd2uqq/vcvttpd2uqq at full vector width, the packed-integer
p-stem class (vpabsd/vpmaxsd/vpminsd & SSE pabsd/pmaxsd/pminsd, cross-sign
VNNI vpdpwusd(s)/vpdpbsud(s)/vpdpwsud(s), ...) at full vector width —
p-stems are excluded from the ss/sd/ps/pd scalar-width suffix rule, which
would otherwise pin them to 4/8; scalar FMA and the true scalar ss/sd forms
keep their widths —, packed FP16 ph-suffix forms at full vector width
(scalar sh memory forms reject), the
widening converts at their exact ratios (vcvtudq2pd/vcvtdq2pd/
vcvtps2uqq-family = dest/2, vcvtph2pd/vcvtph2qq/vcvtph2uqq = dest/4,
vcvtne2ps2bf16 = full width), the narrowing converts (vcvtpd2ps & siblings)
SIZE-DRIVEN (the width comes from the Intel PTR annotation or the AT&T
x/y(/z) source suffix — x=16, y=32, z=64 for the ph-quad family —, a bare
unsized memory form is accepted only when the destination class is unambiguous
(vcvtpd2ps (%rdi), %ymm0 => m512; likewise the AVX512-FP16
vcvtdq2ph/vcvtudq2ph with a ymm destination => m512 = 64 — their .512 form
has no z-suffixed spelling, so the bare form is its only gas-encodable
spelling) and otherwise rejected cleanly, and the
renderer synthesizes the source suffix for Intel PTR input; see the
x86_64_fp.luau module entry for the full matrix), lzcnt/tzcnt/popcnt and the
BMI1/BMI2/bsf/bsr exact entries memory sources at the
destination GPR's byte width, xadd/adcx/adox memory operands at the shared
operand width, crc32 memory sources at the crc source width, sgdt/sidt=10,
sldt/str/smsw=2, lss/lfs/lgs=dest+2,
...); aligned forms
(movaps/movdqa-class) also check alignment, clamped to 8 like FilPizlonator's
buildCheck (the runtime's access-check origin cannot express larger alignments —
a word-aligned but not vector-aligned address passes the check and then faults in
hardware, same as compiled code). The resolved width is AUTHORITATIVE over any
Intel PTR size annotation: the emitted instruction encodes the ISA-fixed width
regardless (`vmovdqu64 DWORD PTR [mem], zmm0` still stores 64 bytes), so a PTR
size that CONTRADICTS the resolved width is rejected — on the heap path here
and on the stack path below — with `PTR size annotation (N bytes) contradicts
the memory access width (W bytes) of '<mnem>'` (a lying annotation would
under-check the access or under-size a materialized stack slot — a
stack-overflow-into-the-caller hole). Only the genuinely size-driven widths
take the annotation: the unsuffixed x87 memory forms (fld DWORD PTR -> 4,
QWORD PTR -> 8, TBYTE PTR -> 10), the cvtsi2ss/cvtsi2sd integer memory
source, and the narrowing converts (vcvtpd2ps & siblings — for those the
annotation is not a contradiction candidate but the width SOURCE, since the
destination register class does not determine the memory source width; a PTR
size that is not a legal source width for the family is rejected cleanly,
and a bare unsized memory form is accepted only when unambiguous — see the
width enumeration above). Those size-driven forms also RENDER at the width the annotation
selected: the emitted AT&T mnemonic carries the encoding suffix (fld QWORD
PTR -> fldl, fild QWORD PTR -> fildq, fstp TBYTE PTR -> fstpt, cvtsi2ss
QWORD PTR -> cvtsi2ssq, vcvtusi2sd DWORD PTR -> vcvtusi2sdl, vcvtpd2ps
XMMWORD PTR -> vcvtpd2psx, crc32 BYTE PTR -> crc32b) — a bare
rendering would assemble at gas's default width and silently change the
checked access width. Combinations the ISA does not have (fst TBYTE PTR —
only fstp has an m80 form; fiadd QWORD PTR) are rejected with `<mnem> has no
<N>-byte memory form` rather than rendered as a nonexistent instruction.
movnti's width is likewise NOT annotation- or default-driven: it is
determined by the source register (%esi -> 4, %rsi -> 8), and a contradicting
PTR size rejects. The PTR-contradiction rejection is not FP-only: it also
fires on the GPR heap path (`mov WORD PTR [rdi], rax` stores 8 bytes, not 2)
and on GPR accesses materialized into an FP-tainted frame cluster (a lying
annotation would under-size the cluster while the instruction writes past
it). The legit narrowing exemptions keep working: movzx/movsx/movsxd take
their check width from the annotation (the source is genuinely narrower than
the destination register), and no-GPR-operand forms (push/pop/call/jmp,
mem-only inc/dec/neg/not) have no register-defined width to contradict.
Full-width two-source permutes (vpermi2*/vpermt2*) and the
UNMASKED expand/compress forms (vexpand*/vcompress*/vpexpand*/vpcompress*) are
SUPPORTED at full vector width — with no {k} writemask they touch all lanes,
a contiguous full-width access; the {k}-masked forms are supported too, via
the mask-aware check (see the transform section).

A stack-frame access by an FP/SIMD instruction cannot ride the GPR slot
virtualization (a slot pseudo-register renders as a GPR, not a vector register),
so analyzeFrame runs an FP TAINT SCAN over the body's stack accesses: intervals
are sweep-merged into clusters, and every cluster an FP/vector access touches —
dragging in any GPR access overlapping it (aliasing: the overlapped bytes must
have exactly one home) — is MATERIALIZED: the instruction is kept and its memory
operand rewritten to a real disp(%rsp) into a reserved region of sarcasm's
synthesized frame. Synthesized offsets are chosen so every input-guaranteed
alignment up to 16 bytes is preserved (entry rsp ≡ 8 mod 16 fixes the residue,
uniformly for rsp-relative and normalized rbp-relative offsets), so movaps/movdqa
stack slots work. Materialization preserves AVX512 decorators on the rewritten
operand: an embedded-broadcast stack access keeps its `{1toN}` (the cluster is
sized at the broadcast element width, so broadcasts off stack slots read exactly
one element), and a `{k}`-masked stack access is rejected (masked-off lanes may
not touch memory — a virtualized slot is a pseudo-register the masked vector
instruction cannot take, and a materialized slot would need the mask-aware lane
structure accounted for in the cluster sizing; heap masked accesses get the
mask-aware check instead). GC root slots keep their ABI-mandated position at the base of
the frame (the Fil-C GC reads them as frame->lowers[i]); the FP regions — the
vector-save area and the materialized clusters — sit past the root area, starting
on a 16-byte boundary (8 bytes of padding when the root count is odd) so the
clusters' mod-16 alignment residues survive the shift past the roots. FP/SIMD
stack accesses needing more than 16-byte alignment (vmovdqa32/vmovaps with
ymm/zmm to the stack) are REJECTED with a message suggesting the unaligned form —
the ABI guarantees only 16-byte stack alignment and sarcasm rejects dynamic rsp
alignment.

The runtime calls sarcasm injects invisibly and that RETURN — the pollcheck slow
path, filc_allocate for `;! alloca`, the ptr-store aux-ensure/barrier slow paths,
the Phase-2 atomic pointer load/store/compare-exchange calls —
would clobber the program's live xmm state (SysV makes every FP/SIMD register
caller-saved, and the Fil-C runtime is compiled SSE2-only), so the transform
wraps them in a vector save/restore into a reserved frame area above the GC
roots. The save/restore is LIVENESS- AND WIDTH-AWARE: `cg.fpSave`/`fpRestore`
emit placeholder nodes (`kind="fpsave"`/`"fprestore"`), and after the whole
function body is emitted (before the frameSlot numRoots shift)
`x86_64_codegen.expandFpSaves` runs a BACKWARD PER-REGISTER WIDTH LIVENESS over
the emitted node stream and replaces each placeholder with exactly the movs the
analysis proves live at that point: a register live only in its low 32 bits is
saved with `movss`, 64 bits with `movsd`, 128 with `movdqu`, 256 with `vmovdqu`,
512 with `vmovdqu64`; a register dead across the call emits nothing.

The width semantics come from `fp.vecEffects` (x86_64_fp.luau): each instruction
reports, per vector register NUMBER (xmm/ymm/zmm alias by number), a use width
and a "provided width" — the width up to which the instruction PROVIDES values
(written, or architecturally zeroed), with bits above flowing through from
before. Backward transfer for a register: a def with providedWidth p kills
liveness at or below p; a use at width u adds it (`live = max(u, live > p and
live or 0)`, so an RMW like addsd counts its own 8-byte merge read). For
example, a movss LOAD provides 16 bytes (writes 4, zeroes [4,16)), so a later
128-bit read (movdqu store) sees the movss's zeros — liveness records 16 bytes
live and the save/restore preserves the zeros; an addsd provides 8 while its
upper bytes flow through. VEX/EVEX destinations provide 64 bytes (upper state
zeroed to MAXVL), VEX scalar forms merge from src1 at 16 bytes, EVEX
merge-masked destinations are also uses, accumulate-style forms (FMA, VNNI
vpdp*, vpternlog*, vpermi2*/vpermt2*, ...) read their destinations, and
anything unrecognized defaults to the safe direction (no def — everything
flows through — and all vector operands used at full class width). User calls
(the pizlonatedFI* thunks and passthrough calls) KILL all vector state (SysV:
values live across a call were already broken in the source program); the
injected filc_* runtime calls are TRANSPARENT (the placeholder pair around
them preserves the state). Only xmm0-15 are ever saved: the SSE2-only runtime
cannot touch ymm/zmm bits above 128, zmm16-31, or k0-7.

The frame reservation is UNCHANGED at 16*vecBytes (vecBytes = the function's
widest vector operand, 16/32/64; slot i stays at 16+i*vecBytes pre-shift) —
the optimization only elides/narrows the movs, never the reservation, so no
layout/computeLayout changes. The expanded movs carry no temps (named fixed
operands), exactly like the old unconditional code, so the register allocator
never sees them.

x87/MMX state is NOT saved — and the reason is NOT "an SSE2-only runtime
cannot clobber x87": libpizlo.a DOES contain x87 instructions (the fldt/fstpt
in the zmath long-double wrappers; ~86 x87 insns in total). The correct
statement is that the injected runtime-call paths sarcasm wraps
(filc_pollcheck_slow, filc_allocate, filc_object_ensure_aux_ptr_outline,
filc_store_barrier_for_lower_slow, and the Phase-2 atomic pointer operations
filc_load_ptr_atomic_with_manual_tracking_outline /
filc_store_ptr_atomic_outline / filc_strong_cas_ptr_with_manual_tracking —
whose internal ensure-aux/box-allocation/barrier paths are the same
allocation/barrier code) never execute those x87 code paths, so the
program's x87 state survives across them (compiler-generated code never keeps
x87 values live across such points anyway). k-opmask state, by contrast, is
genuinely EVEX-only, so an SSE2-only runtime build cannot clobber it (an
AVX512 runtime build would require extending this to zmm16-31 and k0-7). The
whole mechanism emits NOTHING for GPR-only functions — zero cost (fpSave/
fpRestore emit no placeholders at all, and expandFpSaves is a no-op scan).

### ptrflow.luau — pointer-flow analysis
Seeds pointer-ness: function ptr args (from the signature), results of `;! load ptr`
(likewise `;! atomic load ptr` and the `;! atomic ptr` cmpxchg's accumulator def),
call results whose return type is ptr. Forward-propagates through `mov`/`add imm`/
`sub imm`/copies (GEP keeps lower, changes intval). A temp marked ptr gets a paired
`lower` temp. `ptrtoint` (ptr used as int) reads only intval; `inttoptr` w/o known
origin -> null lower. A memory operand's base/index registers are consumed as
addresses, never as value sources (on x86, `addq (%rsi), %rax` adds the loaded SCALAR;
`lea` is the exception — its memory-shaped operand is the computed value). The fixpoint
is guarded against non-convergence: one web can have several def nodes (x86 2-operand
RMW instructions, branch joins), and a web whose defs draw on genuinely different
pointer origins would flip-flop its lower forever, so a repeated global (isPtr,
lowerTemp) state is rejected as a conflicting-pointer-sources error.

### transform.luau — the GIMSO transform (templates in ABI-NOTES.md / ABI-NOTES-x86.md)
The walk and every invisicap sequence live here ONCE; the actual instructions come from
the per-arch codegen module (arm64_codegen / x86_64_codegen):
- Represent each in-flight ptr temp as (intval temp, lower temp).
- `;! load ptr`  -> access-check(8, align 8) + non-atomic invisicap load sequence
  (offset = iv-lower; aux=[lower-8]&mask; auxentry=[aux+off]; box bit handling).
- `;! store ptr` -> access-check + aux-ensure (filc_object_ensure_aux_ptr_outline) +
  store barrier (filc_current_marking_state / filc_store_barrier_for_lower_slow) + stores.
  The barrier slow call is skipped for a null stored lower (a NULL store has no
  object to barrier — the runtime's filc_store_barrier_for_lower guards
  `marking && lower`, and its _slow entrypoint asserts non-null).
- `;! atomic load ptr` / `;! atomic store ptr` (x86_64, plain movq forms) ->
  access-check(8, align 8, CanWrite for the store) + the runtime calls
  filc_load_ptr_atomic_with_manual_tracking_outline(slot) resp.
  filc_store_ptr_atomic_outline(myth, slot, value) — exactly what filcc emits
  for C11 _Atomic pointer accesses. SysV marshalling: a filc_ptr is two
  consecutive words (intval, lower); the load returns rax=iv/rdx=lower. The
  loaded lower is rooted immediately; pointer arguments need no caller rooting
  (the runtime protects them). The callees are nounwind — NO exception-flag
  check after them (failures are fatal filc panics).
- `;! atomic ptr` on cmpxchgq (lock or not — both forms make the same call) ->
  access-check(8, align 8, CanWrite) +
  filc_strong_cas_ptr_with_manual_tracking(myth, slot, 0, expected, new), where
  expected = the implicit accumulator's (iv, lower) webs and new = the source
  operand's; new_value travels on the stack ([rsp]=iv, [rsp+8]=lower at the
  call, marshalled via the red zone + a balanced sub/add of rsp around the
  call — see pushStackPtr in x86_64_codegen.luau). The pinned-accumulator
  machinery (emitPinned) is BYPASSED: expected goes in argument registers, and
  the old value arrives rax=iv/rdx=lower to define the accumulator's def web
  (seeded as a pointer in ptrflow, lower rooted). Success <=> old.iv ==
  expected.iv (the runtime compares raw intvals only — a null-lower expected
  is a legitimate "integer guess"); flags are recomputed as (expected - old)
  so a following je/sete behaves natively.
- `;! load store ptr` on a supported 8-byte mem-RMW (add/adc/and/or/sbb/sub/
  xor, inc/dec/neg/not) -> the NON-atomic box-aware pointer load into a fresh
  (iv, lower) pair, the ALU op re-emitted as a register operation on the iv,
  then the NON-atomic pointer store of (new iv, SAME lower) — the capability
  rides through unchanged: Fil-C pointer arithmetic through memory. adc/sbb
  caveat: the op executes immediately after the injected load/check sequence,
  whose last flag-affecting instruction is a `test` (the aux/box logic), so
  the carry-in is NOT the program's — it is clobbered (deterministically CF=0
  in the current emission) — and the value STORED BACK reflects that. adc/sbb
  are supported for execution-without-trapping (and capability preservation),
  not for carry semantics; see the EFLAGS bullet below.
- `;! atomic load store ptr` on the same forms -> WITHOUT lock: an atomic
  load (runtime call), the op, an atomic store (each access atomic; the RMW
  as a whole is not). WITH lock: a compare-exchange loop — inline checks once
  before the loop; per iteration a pollcheck, an atomic load, the op on the
  iv, and filc_strong_cas_ptr_with_manual_tracking(expected=current old,
  new=old.iv OP src with the SAME lower); a mismatch retries from the atomic
  load. The per-iteration returned lower is re-rooted before each safepoint
  call. adc/sbb caveat: here the op executes right after a runtime call (the
  atomic load), so the carry-in is whatever the call left in EFLAGS —
  indeterminate — and the value stored back (or CAS'd in) reflects it, exactly
  like the non-atomic form's clobbered carry-in above but without even a
  deterministic value.
- EFLAGS for the RMW/CAS sequences: the injected sequences clobber EFLAGS, so
  the operation is re-executed on a scratch copy of the kept-alive pre-op
  value (and source) as the LAST flag-affecting step — a jcc/setcc
  immediately after the annotated instruction sees the native flags (for the
  CAS, expected and result webs can coincide in a retry loop, so the
  comparison uses a private pre-call copy of the expected intval). `not` sets
  no flags to recompute — the documented EFLAGS caveat. adc/sbb are the other
  caveat, and it is wider than the flags: they read a carry-in the injected
  sequences already clobbered, so BOTH the recomputed flags AND the stored
  result carry it — the op itself runs on the clobbered carry (CF=0 after the
  non-atomic `;! load store ptr` load sequence's closing `test`; indeterminate
  — whatever the runtime call left — for the atomic forms), and the flag
  recompute runs on whatever the store/CAS sequence left. A flag consumer
  that does not immediately follow still sees clobbered flags.
- xadd with `;! load store ptr` / `;! atomic load store ptr` is rejected: its
  source register is also a destination and would receive the old pointer
  value (needing a pointer def + rooted lower — and its use/def web union
  would mis-seed the delta value as a pointer); cmpxchg with them is rejected
  (use `;! atomic ptr`); shifts/rotates/imul are rejected (not
  capability-preserving); all five Phase-2 annotations are rejected on ARM64
  (the runtime functions exist there but the marshalling/flag sequences are
  x86_64-only for now) and on cmpxchg8b/cmpxchg16b.
- non-ptr load/store through a ptr temp -> access-check(size, align) then the raw ld/st.
  Every heap WRITE (plain stores, memory-destination RMWs incl. locked forms,
  xadd/cmpxchg/cmpxchg8b/16b, FP/SIMD stores, movnti) additionally gets the
  not-readonly CanWrite test (aux word [lower-8] &
  ObjectFlagReadonly|ObjectFlagFree at bits 49-50), exactly like compiled
  Fil-C — the trap reports "cannot write to read-only object." via the write
  bit in the fail origin. Check order mirrors the compiler (null capability,
  alignment, CanWrite, lower, upper — the CheckKind declaration order
  FilPizlonator's canonicalizeAccessChecks stable-sorts by, verified against
  emitted IR); the origin's recorded alignment is clamped to the word size
  (the runtime asserts on wider), while the check itself tests the full
  alignment (cmpxchg16b tests 16). A full-alignment failure (word-aligned but
  not 16-aligned) could not be attributed by the optimized fail path against
  the clamped origin — every recorded test would pass and the runtime would
  hit its "Should not be reached" assert — so it goes to a dedicated stub
  calling filc_check_aligned_access_fail with the TRUE alignment (a clean
  "alignment requirement of 16 bytes not met" trap; the other failure kinds
  keep the optimized stub). The upper-bound test for a size>1 access uses the
  compiler's OVERFLOW-FREE form (FilPizlonator's buildCheck comment: "Ptr <=
  Upper - Size" is an "overflow-free way of saying Ptr + Size <= Upper"):
  the naive `hi = eff + size; hi ugt upper` WRAPS for eff in
  [2^64 - size, 2^64) (reachable: pointer base + a huge index via lea),
  letting the check pass so the CPU faulted on the wild address — a SIGSEGV
  instead of a clean filc trap (regression tests sarcasm-wrap-oob-*); real
  uppers are < 2^48, so `upper - size` never wraps and any eff that large
  fails the compare. (The ptr-store sequence's inline upper-bound check got
  the same fix; the size==1 arm needs no form change — a direct `eff uge
  upper` cannot wrap.)
- AVX512 {k}-masked and AVX2 vmaskmov/vpmaskmov memory operands through a ptr
  temp get the MASK-AWARE access check (x86_64 only), exactly the algorithm
  the Fil-C compiler emits for the masked intrinsics (FilPizlonator's
  lowerIntrinsicAccess, verified against clang output): for a fixed-position
  access of N lanes x E bytes (V = N*E the full footprint), flight ptr
  (eff, lower), upper at [lower-16]: (1) ValidObject — lower == 0 fails EVEN
  when the mask is zero (a size=0 origin makes the runtime report "cannot
  access pointer with null object."); (2) stores get the usual CanWrite
  aux-flags test; (3) fast path: eff < lower -> below-slow, eff > upper - V
  -> above-slow (overflow-free), else execute with no mask work; (4)
  below-slow: mask == 0 -> execute (masked-off lanes touch nothing), else
  i = cttz of the N-bit-truncated mask and fail iff eff < lower - i*E —
  contiguous expand/compress forms always fail there (the access starts at
  eff); (5) above-slow: mask == 0 -> execute, else fixed-position fails iff
  eff > upper - (h+1)*E (h = the highest set mask bit), contiguous fails iff
  eff > upper - popcount(mask)*E; (6) failures call the runtime's dedicated
  masked fail functions (filc_masked_read/write_check_fail, resp.
  filc_expand_read / filc_compress_write_check_fail — new fail-stub kinds
  marshalling (iv, lower, mask, V, origin) resp. (iv, lower, mask, E, V,
  origin) with a plain 16-byte filc_origin), producing "masked read not in
  bounds (even accounting for the mask)." & co. The mask is extracted into a
  GPR with kmovw/kmovd/kmovq ({%kN}) resp. vmovmskps/vmovmskpd (the AVX2
  mask vector's per-lane sign bits) and truncated to exactly the lane count.
  Supported: {k}-masked vmovdqu8/16/32/64, vmovups/upd, the aligned
  vmovdqa32/64 and vmovaps/pd (which keep their clamped-to-8 alignment
  check), the truncating/saturating vpmov(qb/qw/qd/db/dw/wb, incl. vpmovs*/
  vpmovus*) stores (E = the memory element size, N = the memory lane count),
  vexpand*/vpexpand* loads and vcompress*/vpcompress* stores (contiguous),
  and the AVX2 vmaskmovps/pd and vpmaskmovd/q forms. {%k0} is rejected (not
  a valid writemask — gas rejects it too); masked forms of anything else
  (masked ALU memory sources, gathers/scatters as ever, AMX) stay rejected;
  {k}-masked STACK accesses stay rejected (the frame rewrite virtualizes/
  materializes slots and cannot model masked-off lanes); and a {k} on a
  BROADCAST memory operand ({1toN} or vpbroadcast*/vbroadcast*) rides the
  plain element-width check — the read is unconditional, the mask only gates
  the register destination (verified against the SDM and filcc).
- annotations are validated, never silently ignored: `;! load ptr` / `;! store
  ptr` require a plain 8-byte GPR load/store of the matching direction (a
  mismatch was a silent miscompile — the instruction was replaced by an
  invisicap access); a memory-destination RMW carrying one is rejected
  (pointer RMWs need `;! load store ptr`); the Phase-2 annotations
  (`;! atomic load ptr`, `;! atomic store ptr`, `;! atomic ptr`,
  `;! load store ptr`, `;! atomic load store ptr`) are shape-validated by the
  per-arch backend (`ptrAtomicShape`): the atomic load/store forms are at
  least as strict as the plain ones, `;! atomic ptr` requires an 8-byte
  memory-destination cmpxchg, the RMW forms require a supported 8-byte
  mem-RMW, everything else is rejected with a precise error (on
  cmpxchg8b/cmpxchg16b EVERY ptr-family annotation is rejected — a
  double-width CAS cannot operate on invisicaps); any other
  unrecognized annotation string on an instruction is a compile-time error.
- calls (`;! sig` on the call insn) -> marshal args into the Fil-C CC registers, call the
  callsite thunk `pizlonatedFI<sig>_foo`, test the exception flag (propagate on throw),
  read results. Emits one weak/hidden callsite thunk per distinct called extern.
- loops (back-edges from the CFG) -> insert a pollcheck at the loop header.
- alloca annotations (`;! alloca size (x)` / `;! alloca result (x)`, or `;! alloca result
  size=N`) -> a GC allocation via filc_allocate, not real stack memory.
- fabricate prologue: SOV check + filc_frame push (prev,origin,roots) + callee-saved.
- roots: store each live-across-safepoint pointer's lower into a frame root slot;
  origin count field = number of root slots.
- injected RETURNING runtime calls (the pollcheck slow path, filc_allocate, the
  Phase-2 atomic pointer load/store/compare-exchange calls, the
  ptr-store aux-ensure/barrier slow paths) -> wrap in a vector save/restore
  (x86_64: xmm0-15, or ymm0-15/zmm0-15 when the function uses wider classes): the
  source program never saw these calls and the Fil-C runtime clobbers xmm
  registers. A no-op for GPR-only functions (arm64: always — neon is rejected).

### emit.luau + sarcasm.luau (driver)
- emit: renders the IR with colors via the per-arch render module; materializes spill
  slots; emits the prologue/epilogue with the exact callee-saved set actually colored;
  appends glue via the per-arch glue module. IRC actual spills are handled by rewriting
  (reload before use / store after def into a fresh slot) and re-coloring; the shared
  emission walk also eliminates redundant reloads and no-op self-moves.
- driver: `as`-like args. `-o x.o` default -> write `x.yolo.s` (temp, same dir) then run
  `as` (configurable via `--as`, default `as`) to make `x.o`. `--no-assemble`/`-S` ->
  emit assembly; if no `-o`, write `<input>.yolo.s`. Also splits the input into
  functions, auto-detects the target (detect.luau), and packs spill slots after each
  allocation round (slots with non-overlapping live ranges share an offset).

## Limitations (compile-time rejections)
Assembly that cannot be proven safe is rejected with a clean `sarcasm: <file>: <msg>`
error (exit code 1). Current limitations, enforced on both architectures unless noted:
- Every function declared `.type NAME, %function` and defined in the file MUST carry a
  `;!` signature annotation; an unparseable signature is likewise rejected.
- At most 3 register arguments per function; on x86_64, additionally at most 4 register
  argument WORDS (a pointer arg occupies two words: intval + lower). The x86_64 fast CC
  packs argument words densely into rdx,rcx,r8,r9 only — arguments beyond the fourth
  word are passed on the stack, which sarcasm does not yet marshal — while on arm64 the
  fixed x2..x7 arg pairs already cap any 3-argument signature at 6 words.
- `;! sig` call annotations (callsite signatures) are bounded only by the argument-WORD
  rule, NOT by the 3-argument entry cap: on x86_64 a callsite may use at most 4 register
  argument words, so a 4-scalar-argument call works end-to-end (the callsite resolver
  thunk also needs one callee-saved hold register per argument word, and its hold pool
  is 4 registers — the same limit). On arm64 the fixed x2..x7 pairs cap a callsite at 3
  arguments, same as entry signatures. An over-limit call is rejected.
- Floating-point/vector type classes (float, double, long double, the vector
  classes) are rejected in ALL `;!` signatures — entry signatures and callsite
  annotations alike, on both architectures. This is deliberately deferred, not
  fundamental: the Fil-C x86_64 FP ABI is now decoded (see ABI-NOTES-x86.md — FP
  arguments travel in a separate xmm sequence alongside the dense GPR packing,
  long double goes on the stack and returns in st(0), and the generic buffer CC
  gives every argument one 8-byte word regardless of class); the remaining work
  is the marshalling — entry/callsite glue and buffer-CC packing for the FP
  classes. Until it lands, an FP-typed signature would silently miscompile the
  ABI at both ends, so it is rejected; the error names the offending type.
- Taking the address of the stack frame is rejected (cannot prove safety), whether by
  address arithmetic off the stack register (`add xD, sp, #k` / `leaq 8(%rsp), %rax`),
  by copying it (`movq %rsp, %rax`), or by storing it into a frame slot
  (`movq %rsp, (%rsp)` / `movq %rbp, -8(%rbp)` — the slot virtualization rewrites only
  the memory operand, so the live sp/fp value would leak into a virtual temp). On
  X86_64, while rbp is the frame pointer it is
  treated as a stack register for this check: reading it as a value (`movq %rbp, %rax`)
  or as a memory index is rejected, as is an rsp memory index in any frame.
- On X86_64 there is no mid-function stack-pointer movement (see the frame section):
  constant or dynamic rsp adjustments outside the prologue prefix that are not
  epilogue teardown are rejected, as are stack accesses/returns while rsp is perturbed
  or unbalanced, pushes/pops of non-callee-saved operands, `leave` without an
  established frame pointer, and frame-pointer
  establishment outside the prologue. A callee-saved pop with no matching push of the
  same register at the same slot depth on every path (an "unpaired pop", mid-function
  or in a teardown region — including a pop of the frame pointer with no matching
  save) is rejected — dropping it would silently lose the load.
  Balanced callee-saved push/pop pairs remain legal where the rsp-depth analysis
  proves consistency; dynamic allocation must use the `;! alloca` annotation.
- Stack accesses outside the input frame — below it (on X86_64, below the 128-byte
  SysV red zone under rsp, reached via rsp- or normalized rbp-relative offsets alike),
  above it, or stores into the caller's argument area — are
  rejected; on X86_64, indexed stack-relative access is not supported either, and a
  stack-relative (rsp/rbp-based) memory operand with a SYMBOLIC displacement
  (`movq foo(%rsp), %rax` / `mov rax, [rsp + foo]`) is rejected — its target is
  unknown at compile time, so it cannot be bounds-checked or virtualized.
- alloca requires the annotation pair: an `;! alloca result (x)` with no preceding
  `;! alloca size (x)`, a duplicate size for the same name, or a direct stack-relative
  access into an alloca region are all rejected. For `;! alloca result size=N` the
  annotated instruction must compute the buffer base stack-frame-relative
  (`leaq disp(%rsp), %rd` / `movq %rsp, %rd`, or `leaq disp(%rbp), %rd` when rbp is the
  frame pointer — the gcc/clang -O0 idiom); any other base is rejected rather than
  silently creating no region. Region math uses rsp-relative frame offsets
  (rbp-relative displacements are normalized via frameSize), so rsp- and rbp-relative
  re-derivations of the buffer address (`leaq disp(%rsp), %rd` / `leaq disp(%rbp), %rd`
  / `movq %rsp, %rd`) all redirect to the allocation pointer, while DIRECT
  stack-relative accesses into the region — rsp- or rbp-relative — are rejected (the
  buffer must be accessed through the pointer).
- On ARM64, memory operands on non-load/store instructions are rejected; X86_64 accepts
  them (e.g. `addq (%rsi), %rax`) — on X86_64 any memory operand is modeled as a real,
  bounds-checked access.
- On ARM64, FP/SIMD (neon) registers are uniformly REJECTED with a clean error, as an
  operand or a memory base/index. Proper ARM64 FP/SIMD support (the x86_64 treatment:
  pass-through registers + width-correct checks + materialization) is future work;
  letting neon through unchecked would be unsound.
- On X86_64, `enter`/`enterq` is rejected (packed frame setup sarcasm does not model —
  see the frame section). FP/SIMD code is IN SCOPE (see the FP/SIMD subsection of the
  frame section); the only rejected instructions are ones whose memory-safety effects
  cannot be checked, each with a clean `sarcasm:` error:
  * system-call instructions (syscall/sysenter/sysexit/sysret) — their effect on
    memory safety is unknowable;
  * port I/O (the in/out family), hlt, wrmsr/rdmsr, and mov to/from cr/dr —
    privileged processor state, or data transfers the checker cannot see;
  * lgdt/lidt/lldt/ltr/lmsw — privileged descriptor-table/system-register
    loads. The unprivileged counterparts are SUPPORTED at exact widths:
    sgdt/sidt = 10 bytes (2-byte limit + 8-byte base), sldt/str/smsw = 2 bytes,
    and the far-pointer loads lss/lfs/lgs = destination size + 2-byte selector
    (all previously under- or over-checked);
  * `int N` for N≠3. int3/`int $3` remain legal — like ud2 they only raise a signal
    (SIGTRAP/SIGILL), and Fil-C forbids installing handlers for those
    (is_unsafe_signal_for_handlers in libpas/src/libpas/filc_runtime.c), so a
    merely-trapping instruction is fine;
  * string instructions (movs/stos/lods/scas/cmps, including the bare Intel forms)
    and the rep/repe/repne/xacquire/xrelease instruction prefixes — implicit
    rsi/rdi memory effects the checker cannot see or model. The `lock` prefix
    IS supported: the parser tags it, and x86_64_isa.classify allows it
    exactly on the memory-destination read-modify-write instructions sarcasm
    models precisely (add/adc/and/or/sbb/sub/xor, inc/dec/neg/not, xadd,
    cmpxchg, cmpxchg8b/cmpxchg16b — the hardware locked-instruction set
    intersected with the modeled set). The locked instruction rides the
    normal checked path (a single write-classified access check including the
    not-readonly CanWrite test) and the renderer re-emits the prefix; `lock`
    on anything else (reg-reg forms, mov, FP/SIMD, xchg, unmodeled
    mnemonics) is rejected at compile time — and `lock` on a stack-frame
    access is rejected by the frame rewrite (which runs BEFORE classify):
    the slot virtualizes into a pseudo-register or materializes into the
    thread-confined synthesized frame, so accepting the prefix would
    silently elide it (a locked memory RMW degenerating into an unlocked
    register operation);
  * gather/scatter (multiple discrete addresses), maskmovdqu/maskmovq (an
    implicit DS:rdi memory destination the checker cannot see), and the
    {k}-masked forms of anything outside the supported set (masked ALU memory
    sources, {%k0}, {k}-masked stack-frame accesses — see the masked-access
    bullet above). The SUPPORTED masked forms — the vector moves, truncating
    stores, expand/compress, and the AVX2 vmaskmov/vpmaskmov forms — get the
    mask-aware check described in the transform bullet; the UNMASKED
    vexpand*/vcompress*/vpexpand*/vpcompress* forms stay supported at full
    vector width (with no writemask they touch all lanes — a contiguous
    full-width access);
  * the xsave/xrstor family — the state image size is CPU-dependent (fxsave/fxrstor
    ARE supported: a fixed 512-byte image);
  * fsave/frstor/fstenv/fldenv — x87 environment/state saves;
  * the pcmpestri/pcmpistri family (pcmpestri/pcmpistri/pcmpestrm/pcmpistrm) —
    implicit GPR operands the def/use model cannot express (the estri forms
    read rax/rdx as explicit string lengths; pcmpestri/pcmpistri clobber rcx
    with the index result), so regalloc could silently rename one of those
    registers;
  * umwait/tpause — read the implicit edx:eax TSC-deadline pair (the explicit
    r32 is only a control hint), which the signature marshalling does not yet
    model. (cpuid/rdtsc/rdtscp/xgetbv/rdpkru/wrpkru/monitor/mwait were once in
    this class too; their implicit GPR operands are now modeled exactly and
    pinned — see the pinned implicit-register discussion in the x86_64
    backend notes);
  * umonitor — has no implicit GPR (its address is the explicit operand), but
    it arms address-monitoring hardware on a memory range whose extent cannot
    be bounds-checked;
  * AMX tile instructions (tileloadd/tilestored/ldtilecfg & co) — a tile
    load/store touches a strided, palette-configuration-dependent footprint
    (up to 16 rows x 64 bytes) that cannot be bounds-checked as a single
    access;
  * clzero/xlatb — implicit memory operands the checker cannot see (clzero
    stores the 64-byte cache line addressed by rax; xlatb loads the byte at
    rbx+al);
  * lcall/ljmp — an implicit far-return-frame stack push that the frame model
    cannot see;
  * memory accesses with symbolic addresses (RIP-relative/global data — not yet
    supported), and absolute-address (moffs) operands: a bare
    (non-$-prefixed) symbol operand in AT&T syntax (`movq myglobal, %rax`
    LOADS from the global; `addq myglobal, %rax` reads it through the
    absolute address) or a bare AT&T numeric literal (`movq 0x600000, %rax`
    loads from that address — NOT an immediate move) rejects with "memory
    access with a symbolic address cannot be bounds-checked (global data
    access is not yet supported)" (symbolic) / "...with an absolute
    address..." (numeric); gas's Intel syntax gives a bare symbol the same
    absolute-moffs reading (proven against gas/objdump: `mov rsi, myglobal`
    emits an R_X86_64_32S absolute relocation — only a bare NUMBER is an
    immediate there), so Intel bare symbols reject identically while Intel
    bare numerics stay immediates. Previously these were UNCHECKED absolute
    accesses or silent load→immediate rewrites. The rejection fires for
    every operand position (load, store, ALU source, push/pop), FP/vector
    forms included, and covers indirect-branch memory operands uniformly:
    `jmp *myglobal` / `call *myglobal` / `jmp *0x600000` branch THROUGH an
    absolute memory operand — an un-checkable absolute read of the branch
    target, not a direct branch to it — and `je *myglobal` has no indirect
    encoding at all (rendering would silently emit the DIRECT branch), so
    the `*` indirect marker overrides the code-target exemption below and
    the operand rejects with the same symbolic/absolute-address messages
    (previously the marker was silently dropped — a semantic-changing
    direct branch — or the output failed at gas). Unaffected: direct
    branches (call/jmp/jcc to symbols and numeric local labels),
    register-indirect branches (`jmp *%rdi`), and register-based
    memory-indirect branches (`call *(%rax,%rcx,8)` — bounds-checked like
    any memory operand). Exempt: bare code-target operands (call/jmp/jcc/
    loop*/xbegin, incl. numeric local labels), lea (address arithmetic, no
    dereference — `leaq myglobal, %rax` materializes the address as a
    value, like the supported `leaq myglobal(%rip), %rax`), $imm, and
    segment-register moves (%gs & co — the parser does not classify segment
    registers, so they parse as bare symbols; a mov to/from one is a
    register move, never an absolute memory operand);
  * an Intel PTR size annotation that CONTRADICTS the ISA-determined memory
    access width (`vmovdqu64 DWORD PTR [mem], zmm0` — the emitted instruction
    encodes the 64-byte width regardless of the annotation) — rejected on the
    heap and stack paths alike (`PTR size annotation (N bytes) contradicts the
    memory access width (W bytes) of '<mnem>'`), since a lying annotation
    would under-size the bounds check or the materialized stack slot. The same
    rule fires on the GPR heap path (`mov WORD PTR [rdi], rax` stores 8 bytes,
    not 2 — the width is register-defined) and on GPR accesses materialized
    into an FP-tainted frame cluster; the legit narrowing exemptions
    (movzx/movsx/movsxd — the source is genuinely narrower than the
    destination register — and no-GPR-operand forms like push/pop/call/jmp and
    mem-only inc/dec/neg/not) take their width from the annotation. The
    genuinely size-driven widths stay legal: the unsuffixed x87 memory forms
    (fld DWORD/QWORD/TBYTE PTR) and the cvtsi2ss/cvtsi2sd integer source take
    their width from the annotation, and movnti's width is
    source-register-determined (%esi -> 4, %rsi -> 8 — a contradicting PTR
    size rejects there too). An x87 PTR form the ISA does not have (`fst
    TBYTE PTR` — only fstp has an m80 form; `fiadd QWORD PTR`) is rejected
    with `<mnem> has no <N>-byte memory form` rather than rendered as a
    nonexistent instruction;
  * unknown mnemonics with memory operands — the access width is
    undeterminable and a guessed width could under-cover the access (enqcmd's
    m512 source, an unknown vector load, ...), so the unknown-mnemonic
    fallback no longer guesses a default-width check: unknown+mem REJECTS.
    The scalar FP16 sh-suffix forms land here deliberately: vaddsh & co
    read m16, but a uniform 2-byte rule would mis-model/under-check the
    GPR-mixing scalar-half converts (vcvtusi2sh's integer source is
    m32/m64; vcvtsh2si's GPR destination would go unmodeled), so every sh
    form stays unknown and a memory-operand one rejects cleanly (the PACKED
    ph-suffix forms ARE supported at full vector width; there is no FP16
    hardware here to test the scalar forms on anyway).
    Unknown register-only forms still pass through with the conservative
    first-register-def/rest-use model — a fallback that now covers only
    genuinely-unknown register-only mnemonics: the common compiler-output
    families BMI1/BMI2/ADX/bsf/bsr/xadd/adcx/adox/crc32 have exact
    width/def-use entries in x86_64_fp.luau, and the implicit-register
    mul/div/mulx/cmpxchg/cmpxchg8b/cmpxchg16b class is genuinely modeled via
    the pin mechanism in
    x86_64_isa.classify (see the `*_isa.luau` module entry), so neither lands
    in the unknown class;
  * FP/SIMD stack accesses needing more than 16-byte alignment (see the frame
    section).
  Floating-point signature types are rejected on both architectures (see above).
- On X86_64, an AT&T-style parens operand field in Intel-syntax input is
  rejected ("AT&T-style operand in Intel-syntax input (use [bracket] memory
  operands)") — see the `*_parse.luau` module entry; previously a total check
  bypass.
- X86_64 output is always AT&T syntax, even when the input is Intel syntax.

### Known pre-existing issues (NOT introduced by the current change)

All of the following reproduce on the unmodified baseline (the tree before
the current FP/SIMD review-cycle work); they are pre-existing bugs documented
here, not regressions introduced by this change:

- regalloc can mis-color a function with ≥~13 simultaneously-live webs: the
  same web is rendered in two different registers at different points,
  silently corrupting the value. The trigger is a sufficiently large
  interference graph under coalescing pressure; smaller web counts are
  unaffected.
- injected bounds checks clobber EFLAGS: the capability/bounds-check sequence
  sarcasm emits before a checked memory operand does not preserve the flags
  register, so an instruction that relies on a carry-in flag set before the
  access (`stc` then `adcx`/`adcq` through a checked memory operand) observes
  an indeterminate flag. Register-only flag chains (no checked memory operand
  between the flag-setter and the flag-consumer) are fine.
- detect.luau's architecture autodetect falls back to ARM64 for a
  register-free x86 input (e.g. a lone `rep movsb` with no % registers and
  no .intel_syntax/PTR/bracket markers): the input is then parsed as arm64
  and fails later — confusingly — at `as`. Harmless: the input was going
  to fail anyway (`rep movsb` is a rejected string instruction on the
  x86_64 path), only the error message is opaque. The same misdetect hits
  x86 input whose ONLY registers are xmm-class (e.g. a lone `movss
  myglobal, %xmm0`): the detector keys on GPR markers (%r*/%e*/%rip, bare
  r*/e* tokens, PTR/brackets), so a register file of pure vector registers
  is invisible to it. (That input rejects on the x86_64 path too — the
  symbolic moffs operand — so again only the error message changes.)

## Verification
All testing is via the Fil-C test suite: `filc/run-tests -f sarcasm` from the repo root
runs the 517 `filc/tests/sarcasm-*` tests (manifest key `use-sarcasm: true`; `.s` inputs
assemble via minilute + sarcasm, `.c` files via clang) — 467 x86_64 and 50 aarch64
(every test is `only-on-platform:` exactly one of them). For each yolo input the suite
runs sarcasm, assembles + links with Fil-C `main`s, runs, and confirms correct results
+ that OOB/null-capability inputs trap. The suite breaks down as:

- 317 behavioral tests (278 x86_64, 39 aarch64), most exercised in AT&T and Intel
  variants (`-att` / `-int` pairs, aarch64 singletons as `-arm`): pointer-chasing
  workloads in several sizes (`sarcasm-hash(-oob)-*`, `sarcasm-t2-*`,
  `sarcasm-t3valid/t3oob-*`, `sarcasm-medium/large`), null-capability and OOB traps
  (`sarcasm-nullcap-*`, `sarcasm-*-oob-*`, incl. the movnti store checked at its
  source-register width — `sarcasm-oob-movnti-att`), the pointer-store capability round-trip
  (`sarcasm-store(-gcstress)-*`, `sarcasm-ro-store-*`, `sarcasm-ptrret-*`,
  `sarcasm-nullret-*`), register-indexed access (`sarcasm-regidx(-oob)-*`), RMW
  memory operands (`sarcasm-rmw-*`), calls and the callsite resolver
  (`sarcasm-call(-error)-*`, `sarcasm-asmcall-*`, `sarcasm-funcptr-*`,
  `sarcasm-recurse-*`), dense fast-CC packing (`sarcasm-args3-*`,
  `sarcasm-densepack-llp-*` and the `-fp-` variants, which route the call through a
  function POINTER to exercise the generic buffer-CC entrypoint), width/zero-extension
  slots (`sarcasm-slotw-*`, `sarcasm-zeroext-*`), allocas and stack buffers
  (`sarcasm-alloca-*`, `sarcasm-stackbuf-*`, including region redirects via `lea`/`mov`
  re-derivations, the gcc -O0 rbp form, and the `movq %rbp,%rsp; popq %rbp; ret` VLA
  epilogue), spill-slot packing and frame geometry (`sarcasm-spill(-oob)-*`,
  `sarcasm-frame-*`: transient prologue-prefix push/pop pairs, the `movq %rbp,%rsp`
  teardown path, rbp-relative red-zone spills, rbp/rsp slot aliasing), rbp as an
  ordinary GPR under frame-pointer omission (`sarcasm-rbpgpr-*`), GNU-as numeric local
  labels (`sarcasm-numlabel(-pollcheck)-*`), far-pointer and descriptor-table
  accesses at their exact widths (`sarcasm-farptr-*` — lgs m16:16/m16:32;
  `sarcasm-sidt-*` — the 10-byte sidt store) and their OOB traps
  (`sarcasm-oob-lfs-*`, `sarcasm-oob-sidt-*`), the legit narrowing exemption from
  the GPR PTR-contradiction rule (movzx/movsx/movsxd take their check width from
  the PTR annotation, not the destination register width —
  `sarcasm-ptr-narrowing-int`), the pinned implicit-register family — div/idiv
  with cqo/cdq sign-extension under register pressure (webs live across the
  pin), register and checked-memory divisors, mul/imul rdx:rax products
  (`sarcasm-div-att`, `sarcasm-div-int`), the pinned cmpxchg accumulator and
  dual-RMW xadd (`sarcasm-rmw-pin-att`), the pinned four-register
  cmpxchg8b/cmpxchg16b pairs with success/failure CAS paths, mismatch
  edx:eax/rdx:rax writeback, lock and non-lock forms, and webs live across
  the pin (`sarcasm-cmpxchg8b-att`/`-int`, `sarcasm-cmpxchg16b-att`/`-int`),
  the lock prefix on every modeled mem-RMW family
  (`sarcasm-lock-rmw-att`/`-int`, plus the `-oob-lock-xadd-att` and
  `-oob-cmpxchg16b-att` traps), the zero-operand implicit-only pinned family
  — cpuid vendor/max-leaf, rdtsc/rdtscp monotonicity with a stable TSC_AUX,
  and xgetbv(0) XCR0 (`sarcasm-implicit-att`/`-int`); rdpkru/wrpkru behind a
  CPUID leaf-7 PKU+OSPKE probe with a no-op write-back of the read value
  (`sarcasm-pku-att`/`-int`); monitor/mwait behind a CPUID leaf-1 feature
  probe AND a forked-child execution probe (Fil-C deliberately makes SIGILL
  uncatchable, and userspace monitor/mwait #UD on the current dev machine
  even with the feature bit set — the test passes either way)
  (`sarcasm-monitor-att`/`-int`); and the register-pressure heart of the pin
  modeling: six and eleven webs live across a cpuid (coloring around, then
  spilling across, the pinned rax/rbx/rcx/rdx) plus the pin-in/out
  coalescing case where the user's own eax/ecx are exactly the cpuid inputs
  (`sarcasm-implicit-pin-att`/`-int`), the cmpxchg16b full-alignment trap at an
  in-bounds word-aligned-but-not-16-aligned address through the dedicated
  align>8 fail stub (`sarcasm-misalign-cmpxchg16b-att`), the BMI1/BMI2 exact entries
  (`sarcasm-bmi-att`), the not-readonly CanWrite traps on plain/RMW/FP stores
  to read-only objects (`sarcasm-ro-plain-store-att`/`-int`,
  `sarcasm-ro-rmw-att`, `sarcasm-ro-fp-store-att`), and pollchecks/GC stress
  (`sarcasm-pollcheck-*`, `sarcasm-*-gcstress*`), the eff+size overflow-hole
  regressions (`sarcasm-wrap-oob-read-att`/`-int`, `-write-att`, `-read16-att`
  — eff in [2^64 - size, 2^64) now traps cleanly instead of wrapping the
  upper-bound check and SIGSEGVing), and the AVX512 {k}-masked / AVX2
  vector-masked access suite (`sarcasm-masked-*`, `sarcasm-vmaskmov-*`,
  `needsAVX512` where AVX512 is used): in-bounds masked loads/stores with
  all-ones/sparse/zero masks, merge and {z} forms (`sarcasm-masked-move-att`/
  `-int`), success-by-masking below and above the object and the zero-mask
  survives (`sarcasm-masked-slowpath-att`), the expand/compress popcount-fit
  successes incl. the byte-element N=64 forms (`sarcasm-masked-expand-att`/
  `-int`), the truncating vpmovqb/vpmovdw masked stores
  (`sarcasm-masked-trunc-att`), the AVX2 vmaskmovps/vpmaskmovq sign-bit-mask
  forms (`sarcasm-vmaskmov-att`), the aligned vmovdqa32/vmovaps masked forms
  (`sarcasm-masked-aligned-att`), and the traps: completely-OOB masked
  load/store (`sarcasm-masked-oob-load-att`/`-store-att`), partially-OOB with
  ENABLED lanes out below/above (`sarcasm-masked-oob-below-att`/`-above-att`),
  the null-capability mask==0 load ("cannot access pointer with null object"
  — `sarcasm-masked-nullcap-att`), the read-only masked store
  (`sarcasm-masked-ro-store-att`), the expand-above and compress-below traps
  (`sarcasm-masked-expand-oob-att`/`-compress-oob-att`), the truncating-store
  trap (`sarcasm-masked-trunc-oob-att`), the vmaskmov trap
  (`sarcasm-vmaskmov-oob-att`), and the misaligned aligned-form trap
  (`sarcasm-masked-aligned-oob-att`). Trap coverage is made systematic by the
  `sarcasm-tm-*` matrix (121 tests, all AT&T-syntax x86_64 `return: failure`
  tests trapping in every subrun mode and asserting the exact first-line
  `filc safety error` message): the six fault categories — below-bounds,
  above-bounds, above-bounds-overflow (an effective address near 2^64, so
  eff+size wraps a naive upper-bound check), use-after-free, special object
  (direct access of a `zweak_new()` object), and null capability (an integer
  address) — crossed with every access width 1/2/4/8/10/16/32/64 in both load
  and store directions (movb/movw/movl/movq GPR forms, the x87 fldt/fstpt
  tbyte, movdqu xmm, vmovdqu ymm, vmovdqu64 zmm — the zmm cells are
  `needsAVX512`): the 96 core cells. Extras round out the interesting
  instructions: fxsave's 512-byte store in all six categories (fxrstor in
  three — below/above/null-cap), 6-byte lfs far-pointer loads, the
  cmpxchg16b/cmpxchg8b locked-RMW paths, AVX512 `{k}`-masked vmovdqu32 loads
  and stores on freed and special objects, and embedded-broadcast `{1to16}`
  element checks below/above. Masked-cell message attribution is subtle: a
  masked LOAD from a freed or special object falls to the mask-refined bounds
  slow path and reports "masked read not in bounds (even accounting for the
  mask)." — the masked fail function has no free/special distinction; a
  masked STORE to a FREED object trips the CanWrite aux-flags test
  (READONLY|FREE) BEFORE the bounds slow path and therefore reports "cannot
  access pointer to free object." (a size=0 origin — exactly like the Fil-C
  compiler's masked-store check), while a masked store to a SPECIAL object
  passes CanWrite (special is not in the READONLY|FREE mask) and reports
  "masked write not in bounds ...". The pre-existing non-matrix trap tests
  are unaffected and complementary: `sarcasm-oob-*`/`sarcasm-fp-oob-*` cover
  above-bounds widths, straddles and exotic instructions in both syntaxes,
  `sarcasm-nullcap-*` the null-capability forms, `sarcasm-wrap-oob-*` the
  eff+size overflow-hole regressions, `sarcasm-ro-*` the read-only CanWrite
  traps, and `sarcasm-masked-*`/`sarcasm-vmaskmov-*` the masked success/trap
  forms — the matrix adds the missing categories (below-bounds,
  use-after-free, special) and makes the width coverage systematic.
- 61 FP/SIMD tests (`sarcasm-fp-*`, all x86_64): SSE scalar arithmetic and
  comparisons (`sarcasm-fp-sse-arith-att` / `-int`), scalar FP heap loads/stores at
  8 and 4 bytes (`sarcasm-fp-mem-movsd-att` / `-int`), 16-byte vector heap copies
  (`sarcasm-fp-mem-movups-att`), an FP reduction loop with xmm live across the
  pollcheck (`sarcasm-fp-loop-att`), xmm state held live across GC stress
  (`sarcasm-fp-gcstress-att`), mixed GPR/vector conversions (`sarcasm-fp-cvt-att`:
  cvtsi2ss/cvtsi2sd l/q, cvttss2si/cvttsd2si l/q, cvtss2sd/cvtsd2ss, movd/movq),
  half-precision conversions at the exact ph-side width (`sarcasm-fp-cvtph-att`;
  `sarcasm-fp-cvtph-avx512-att`, `needsAVX512`), AVX2 ymm arithmetic with a
  broadcast load and a ymm stack spill/reload
  (`sarcasm-fp-avx2-att`), AVX512 zmm arithmetic, embedded-broadcast `{1to16}` and
  opmask-register code (`sarcasm-fp-avx512-att`, `needsAVX512`), embedded
  broadcasts off a materialized stack slot (`sarcasm-fp-bcast-stack-att`,
  `needsAVX512`), vpbroadcastb/w/d/q memory sources at their exact element
  widths 1/2/4/8 plus the xmm-source form (`sarcasm-fp-broadcast-att`), the
  GPR-source broadcast forms — a stale-register miscompile regression
  (`sarcasm-fp-broadcast-gpr-att`, `needsAVX512`), full-width vpermt2*
  permutes and an unmasked vpcompressd/vpexpandd round-trip through a
  materialized stack slot (`sarcasm-fp-avx512-perm-att`, `needsAVX512`),
  truncating stores at the source-vector-bytes/ratio width
  (`sarcasm-fp-truncstore-att`, `needsAVX512`), MMX reg-reg and
  memory forms (`sarcasm-fp-mmx-att`), x87 memory forms and a tbyte stack
  round-trip (`sarcasm-fp-x87-att`), x87 reg-reg ops with `fnstsw %ax` status-word
  branching (`sarcasm-fp-x87-misc-att` / `-int`), fxsave/fxrstor and
  stmxcsr/ldmxcsr (`sarcasm-fp-fxsave-att`), AES-NI key expansion + enc/dec round
  trip (`sarcasm-fp-aes-att`), pclmulqdq and SHA-NI (`sarcasm-fp-pclmul-att`),
  GFNI (`sarcasm-fp-gfni-att`; `sarcasm-fp-gfni-avx512-att`, `needsAVX512`),
  the EVEX unsigned-integer scalar converts — reg forms incl. the stale-GPR-source
  regression, the reverse vcvtt*/vcvt*2usi family, and the Intel QWORD PTR mem
  forms rendering vcvtusi2ssq/vcvtusi2sdq (`sarcasm-fp-cvtusi-att`,
  `needsAVX512`), the widening/narrowing convert zoo at its exact widths
  (vcvtudq2pd-family = dest/2 — `sarcasm-fp-cvtwid-att`; the vcvtps2uqq-family
  unsigned widening converts — `sarcasm-fp-cvt-unsigned-att`; the BF16 converts
  vcvtneps2bf16 = 2x dest and full-width vcvtne2ps2bf16 —
  `sarcasm-fp-bf16-att`; all `needsAVX512`), the size-driven narrowing
  converts at their exact x/y/z-suffix and Intel PTR widths plus the
  unambiguous bare-ymm m512 form (`sarcasm-fp-cvt-narrow-att`,
  `needsAVX512`), full-width vdbpsadbw
  (`sarcasm-fp-dbpsad-att`, `needsAVX512`), the AVX512-IFMA
  vpmadd52luq/vpmadd52huq multiply-adds at full vector width
  (`sarcasm-fp-ifma-att`, `needsAVX512`), the full-width unsigned
  vcvtpd2uqq/vcvttpd2uqq converts and the AVX512-FP16
  vcvtdq2ph/vcvtudq2ph m512-source forms — bare ymm-dest ⇒ 64, the x/y
  source suffixes at 16/32, Intel ZMMWORD PTR — assembling unconditionally
  but value-checked only where CPUID reports AVX512-FP16
  (`sarcasm-fp-cvt-dq2ph-att`, `needsAVX512`), Intel x87 memory forms
  rendering at
  the correct AT&T suffix (fld QWORD PTR -> fldl, fstp QWORD PTR -> fstpl;
  `sarcasm-fp-x87-widths-int`),
  movsd/movaps spills to materialized frame slots (`sarcasm-fp-stack-spill-att` /
  `-int` — movaps to the stack at preserved 16-byte alignment), GPR/FP byte
  aliasing of the same stack bytes (`sarcasm-fp-stack-alias-att`), FP accesses in
  the red zone (`sarcasm-fp-redzone-att`), and per-width OOB traps:
  `sarcasm-fp-oob-movss-att` (4), `-movsd-att` (8), `-movdqa-att` (16, aligned),
  `-ymm-att` (32), `-zmm-att` (64, `needsAVX512`), `-fldt-att` (x87 tbyte, 10),
  `-mmx-att` (8), `-vstmxcsr-att` (4), `-vnni-att` (vpdpwssd at the full 64-byte
  vector width, `needsAVX512`), `-cvtuqq2ps-att` (vcvtuqq2ps ymm reading a 2x-dest
  64-byte source, `needsAVX512`), `-pabsd-att` (vpabsd zmm at the full
  64-byte vector width — the p-stem ss/sd-rule exclusion, `needsAVX512`),
  `-pminsd-att` (SSE pminsd xmm at 16, the SSE side of the exclusion,
  `needsAVX512`), `-vnni-usd-att` (the cross-sign vpdpwusd ymm at 32,
  `needsAVX512`), `-dq2ph-att` (bare vcvtdq2ph ymm reading a 64-byte m512
  source, proven by the pre-execution bounds trap — no FP16 silicon needed,
  `needsAVX512`).
- 139 rejection tests (`sarcasm-reject-*`, 128 x86_64, 11 aarch64 — the `-arm` ones
  cover the ARM64-only rejections). Each directory carries exactly ONE `.s` file
  (compileFailure manifest), so every rejected input is proven rejected
  individually rather than one file's rejection masking another's. Families:
  missing/unparseable/over-limit signatures and callsites (`-nosig-*`,
  `-badsig-*`, `-too-many-args-*`, `-callsite-arity-*`), FP signature types
  (`-fp-sig-entry-float`, `-fp-sig-entry-double`, `-fp-sig-callsite-arg`,
  `-fp-sig-callsite-ret`), alloca misuse (`-alloca-*`), out-of-frame stack
  accesses (`-below-frame-*`, `-caller-frame-*`, `-dispsym-stack*`,
  `-stack-indexed`), mid-function stack-pointer movement and frame-geometry
  violations (`-midframe-sp-*`, `-frame-misc-*`, `-unpaired-pop-*`, `-enter*`),
  stack-address escapes (`-stack-addr-*`, `-rbp-escape-*`, `-sp-index*`,
  `-slot-store-escape-*`, `-slot-storeptr`), pointer-flow non-convergence
  (`-ptrflow-nonconverge-*`), unresolved numeric labels
  (`-numlabel-unresolved-*`), symbolic/global data access (`-global-load*`),
  absolute-address (moffs) operands (`-absaddr-load`, `-absaddr-store`,
  `-absaddr-num`, `-absaddr-alu`), indirect-branch moffs operands
  (`-jmp-indirect-abs`, `-call-indirect-abs`, `-jmp-indirect-num` — the `*`
  indirect marker overriding the call/jmp code-target exemption),
  AT&T-style parens operands in Intel-syntax input (`-intel-attmem`,
  `-intel-attmem-fp`, `-intel-enqcmd`), the ambiguous unsized narrowing
  convert (`-cvt-unsized`), and
  the FP/SIMD and unsafe-instruction rejections listed under Limitations
  (`-syscall`, `-portio`, `-hlt`, `-crmove`, `-intN`, `-stringop-*`,
  `-lockprefix` (`lock movq` — lock on a non-RMW), `-lock-regreg`,
  `-lock-stack-mov`/`-mov-intel`/`-add`/`-add-intel` (lock on a stack-frame
  slot — it would virtualize/materialize before classify's lockAllows check,
  silently dropping the prefix), `-gather`,
  `-scatter`, `-maskmovdqu`,
  `-avx512-masked-alu` (a masked ALU memory source), `-avx512-masked-k0`,
  `-avx512-masked-stack`, `-pcmpestri`,
  `-pcmpistri`, `-clzero`, `-xlatb`, `-lcall`, `-lgdt`, `-xsave`, `-fsave`,
  `-cmpxchg16b-ptr` (a ptr-family annotation on cmpxchg16b), `-ptrsize-stack`,
  `-ptrsize-gpr`, `-movnti-width`, `-vec-unknown-mem`, `-aligned-stack`,
  `-fp-loadptr`, `-tilestored`, `-tileloadd`, `-ldtilecfg`, `-enqcmd`,
  `-x87-noform`, `-umwait`, `-tpause`, `-umonitor`), the frame-slot
  double-width CAS rejections (`-cmpxchg8b-stack`, `-cmpxchg16b-stack` — no
  register form to virtualize into), and the annotation-
  validation rejections (`-storeptr-on-load`, `-loadptr-on-store`,
  `-rmw-storeptr`, `-loadptr-reg`, `-unknown-annotation`, `-loadstoreptr`,
  `-cmpxchg8b-ptr` — a ptr-family annotation on cmpxchg8b, the 8-byte twin of
  `-cmpxchg16b-ptr`).

The old in-tree `tests/` harness (host-lute `verify.sh`/`verify-x86.sh` via docker, and
the `roundtrip-test`/`detect-test`/`cleanup-test` Luau unit tests) has been removed;
its coverage now lives in `filc/tests/sarcasm-*`.
