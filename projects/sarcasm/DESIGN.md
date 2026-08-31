# sarcasm design

SAfe Runtime Capability-enforced Assembler: an ARM64 and X86_64 assembler (in Luau, run via
`lute`) that rewrites Yolo-C assembly into memory-safe, Fil-C-linkable assembly, then invokes
`as`. The target architecture — and, for X86_64, the AT&T vs Intel input syntax — is
auto-detected from the input text, or forced with the --x86_64/--arm64/--intel/--at&t
options (see "Command-line target selection" under the driver section).

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

## Modules

Shared (architecture-independent):
- `detect.luau`     — auto-detects arm64 vs x86_64 (and att vs intel).
- `sig.luau`        — signature encoding (verified against clang: 1066/2529/12769).
- `frame.luau`      — frame preprocessing skeleton; per-arch policy plugs in.
- `lift.luau`       — lifts asm to IR over register webs (see Core stages).
- `ptrflow.luau`    — pointer-flow analysis over the lifted IR.
- `transform.luau`  — the GIMSO transform (see below).
- `regalloc.luau`   — IRC: CFG, liveness, interference, coalesce, spill.
  `regalloc.color()` runs a soundness verifier that rejects any mis-colored
  assignment with a clean compile error (a detection backstop, not a repair).
- `emit.luau`       — shared emission: reload elimination, spill bookkeeping, self-move
  dropping; per-arch render module supplies instruction text + prologue/epilogue.
- `build.luau`      — constructors for synthesized IR nodes.
- `numlabel.luau`   — GNU-as numeric local labels (`1:` / `1f` / `2b`): resolves
  f/b references and renames definitions to unique private symbols at parse time.
- `sarcasm.luau`    — driver: function splitting, orchestration, spill-slot packing,
  `as` invocation, CLI.
- `ABI-NOTES.md` / `ABI-NOTES-x86.md` — complete ABI references.

Per-architecture backends (`arm64_*` / `x86_64_*` pairs):
- `*_parse.luau`   — operand parser + `;!`/`#!` (x86_64) / `//!` (arm64) annotations
  (see "Annotation markers" in README.md: the recommended spelling is `#!` on x86_64
  and `//!` on arm64, with `;!` supported on both for backwards compatibility).
  x86_64 parses BOTH AT&T and Intel
  syntax into the common dest-first operand model. Both parsers accept GNU-as numeric
  local labels (`1:` may be defined repeatedly; `1f`/`1b` reference the next/previous
  definition, including as a memory displacement like `1f(%rip)`): numlabel.luau renames
  each definition to a unique private symbol and rewrites the references at parse time,
  so numeric labels work in branches and loops like any named label. A reference with no
  definition in the requested direction is rejected (`unresolved numeric label
  reference`). In Intel-syntax mode an AT&T-style parens operand field
  (disp(base,index,scale)) is rejected outright — "AT&T-style operand in
  Intel-syntax input (use [bracket] memory operands)": such a field would
  otherwise fall through to parseSym and RE-RENDER verbatim as
  valid AT&T memory syntax with Intel dest-first operand order applied and NO
  capability/bounds check (`movq (%rdi), %rsi` in
  Intel mode would emit an unchecked 8-byte store). Any field containing parens
  is rejected (covering the parseSym fallthrough, the numeric-prefix immediate
  path, and whitespace-dodged forms); the only legitimate parens in an Intel
  operand are the x87 stack-register name st(N).

  Annotation markers and comments (both parsers — see README.md's "Annotation
  markers" for the user-facing contract): a line is split into code + annotation
  body at the EARLIEST annotation marker outside a string literal — `;!` on both
  architectures, plus `#!` on x86_64 and `//!` on arm64 (the recommended
  spellings). Every string-aware scan honors `\"` escapes: inside a string
  literal the character after a `\` is skipped, so `"a \" ;! b"` is one
  ordinary string whose `;!` is inert (and, on arm64, a `//` inside such a
  string is not a comment); outside strings `\` is an ordinary character with
  no quoting power. The interplay with comments is per-architecture, and in
  both directions the invariant is that comment and string-literal text can
  never fabricate an annotation:
  - x86_64: a single string-aware scan (splitAnnotation) walks the line; a `#`
    NOT immediately followed by `!` starts a comment that ends the line with NO
    annotation (so `# use ;! load ptr here` stays inert), `#!` or `;!` splits the
    line, and the body is then run through the ordinary comment stripper
    (stripComment), so a trailing `#` comment inside the body is removed.
    `//!` is NOT a marker here: it stays in the code part
    and fails to parse ("cannot parse line: //! ...").
  - arm64: comments are removed from the WHOLE text before line splitting
    (stripComments: `//` to EOL, inline and multi-line `/* ... */`, both
    string-literal aware, each replaced by a single space so token separation is
    preserved, with newlines kept so line numbers still line up). `//!` is
    emitted VERBATIM by that pass — it is a marker, not a comment — so the
    subsequent marker split finds it, while a later `//` on the same line is
    still stripped (arm64 bodies are verbatim: no further comment stripping
    happens inside a body). Block comments win: `/* //! load ptr */` is a
    comment, not an annotation. `#` is NOT a comment character here (it
    introduces immediates), and `#!` is NOT a marker, so `#!` text stays in
    the code part and produces an ordinary parse error.
- `*_isa.luau`     — instruction semantics: register defs/uses, control flow. On
  x86_64 this is also where the implicit-register GPR instructions are MODELED:
  div/idiv (implicit rdx:rax dividend use, quotient/remainder def), mul and
  1-operand imul (rax use, rdx:rax product def), mulx (implicit rdx source,
  not written), cmpxchg (implicit accumulator RMW alongside the explicit
  destination RMW), cmpxchg8b/cmpxchg16b (the implicit expected-value RMW
  pair edx:eax resp. rdx:rax and the implicit new-value source ecx:ebx resp.
  rcx:rbx — all four pinned), the cqo/cdq/cwd sign-extends (rax use, rdx def),
  and the zero-explicit-operand implicit-only family (cpuid, rdtsc/rdtscp,
  xgetbv, rdpkru, wrpkru, monitor, mwait) — all name their implicit rax/rdx
  effects with implicit def/use operand tables the web
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
  codegen rewrites them to a renameable movsxx on the rax web. xchg is modeled
  with the same pin machinery: BOTH register operands are read and written (each
  receives the other's value), so classify creates a fresh def-site table per
  register (the def of rax's web must receive rcx's value — a crossing the
  plain web/RMW model cannot express), emitPinned
  copies both webs into their physical registers, the passthrough xchg swaps the
  physical registers, and each physical register is copied back out into its
  register's fresh web; xchg with a MEMORY operand is an implicitly LOCKED
  read-modify-write in hardware and is rejected ("implicitly locked
  read-modify-write"), as is any non-GPR operand pair (rsp/xmm exchanges). bswap
  is a use+def RMW of its ONE register web passed through raw — and only in
  its r32/r64 forms:
  the 16/8-bit spellings are not encodable (an 8-bit byte swap would be a
  no-op; gas: "invalid instruction suffix for `bswap'"), so `bswapw %ax` and
  `bswapb %al` are rejected at classify ("bswap requires a 32-bit or 64-bit
  register operand (bswapw/bswapb are not encodable)") instead of dying in the
  temp .yolo.s; movbe is rejected outright (it
  only exists as a byte-swapping move to/from memory; the register-to-register
  spelling is not a baseline x86-64 encoding and the memory forms are not
  modeled). Multi-byte padding NOPs (nop/endbr64/nopw/nopl) are a zero-effect
  class: baseMnemonic maps them all to "nop" (no def/use effects), the frame
  rewrite passes them through verbatim (their operand — `nopw 0x0(%rax,%rax,1)`
  — is a dummy encoding hint, NOT a memory access, so it must not be
  bounds-checked or virtualized), codegen's lowerSpecial skips the access check
  for them, and the renderer normalizes the bare forms (which gas rejects with
  "invalid instruction suffix") to plain `nop`. On arm64 this
  is where the NEON/FP semantics live: per-mnemonic def/use classification
  (the VEC_PURE_WRITE / VEC_DST_READ / lane-insert families, fmov's
  GPR<->vector roles, the safe unknown-mnemonic default — read all NEON
  operands, provide nothing), vecEffects for the width-liveness vector
  saves, the NZCV flag-use/flag-def tables (adcs/sbcs are load-bearing
  read+write), the SVE/SVE2 rejection, and the LSE_KIND table classifying
  the LSE RMW / cas / casp / load-store-exclusive families — including the
  cas/casp pin modeling (the compare register — and casp's data pair — are
  architectural read-modify-writes pinned to their written physical
  registers, the arm64 counterpart of x86_64's cmpxchg accumulator; the
  hardware encodes a pair as one even register number).
- `x86_64_fp.luau` — the x86_64 FP/SIMD knowledge module, consulted by the isa
  classifier (def/use modeling + rejections), the codegen (checked-access
  width/alignment), and the frame policy (stack-slot widths). Its substance is
  a set of width RULES over the SSE/AVX/AVX2/AVX512 surface, not a flat
  per-mnemonic table:
  * Per-family memory access widths/alignments cover the scalar and packed FP
    forms, vector moves, MMX, x87, AES/SHA/PCLMUL/GFNI crypto, opmask k moves,
    and fxsave/fxrstor (=512), plus the exact-width GPR classes (sgdt/sidt=10,
    sldt/str/smsw=2, lss/lfs/lgs = destination size + 2-byte selector;
    movnti = the source register's width, never a guessed default;
    lzcnt/tzcnt/popcnt and BMI/bsf/bsr memory sources = the destination GPR's
    byte width; xadd RMWs BOTH explicit operands; adcx/adox = the destination
    width; crc32 = the crc SOURCE width from the b/w/l/q suffix, source
    register, or PTR annotation, with an illegal destination/source width
    combination rejected cleanly).
  * Derived widths wherever a rule exists instead of entries: an embedded
    broadcast `{1toN}` reads one element; vpbroadcast memory sources read the
    exact element width 1/2/4/8; truncating/saturating vpmov stores read the
    source vector bytes / element ratio; vcvtps2ph/vcvtph2ps read half width
    on the ph side; widening converts read half or quarter the destination
    width. The full-width classes (vpermi2*/vpermt2*, unmasked
    expand/compress, VNNI dot products, vdbpsadbw, IFMA multiply-adds,
    vcvtpd2uqq) ARE exact entries, because a suffix rule would mis-pin them.
  * The ss/sd/ps/pd scalar-width suffix rule EXCLUDES p-stem mnemonics: after
    the optional 'v', a stem starting with 'p' is the packed-INTEGER family,
    where a trailing "sd"/"ss"/"ps"/"pd" is part of the NAME — so the whole
    "sd"-ending packed class falls through to the p-family pattern at FULL
    vector width instead of being under-checked at 4/8 bytes, closing that
    under-check class generically (scalar FMA keeps its width:
    vfmadd231sd's stem is "fmadd231" -> 8).
  * The packed AVX512-FP16 suffix ph resolves to full vector width (like
    ps/pd); the SCALAR sh forms are deliberately NOT matched — a rule-derived
    width would be wrong for the GPR-mixing scalar-half converts
    (vcvtusi2sh's integer source is m32/m64) and would leave vcvtsh2si's GPR
    destination unmodeled — so every sh form stays unknown and a
    memory-operand one rejects cleanly.
  * NARROWING converts (vcvtpd2ps & siblings) are SIZE-DRIVEN, because the
    destination register class does not determine the memory source width:
    the width comes from the Intel PTR annotation or the AT&T x/y(/z) source
    suffix; a bare unsized memory form is accepted only when the destination
    class is unambiguous (vcvtpd2ps (%rdi), %ymm0 ⇒ m512) and is otherwise
    rejected cleanly ("unsized memory operand is ambiguous; use a size suffix
    or PTR annotation") before anything gas would fail on is rendered; an
    illegal PTR size or suffix/destination combination rejects cleanly too;
    the renderer synthesizes the source-width suffix for a bare mnemonic with
    a sized memory operand.
  * GPR def/use roles of mixed GPR/vector instructions: the vpbroadcast
    GPR-source forms READ the source GPR; the vcvtusi2ss/sd GPR source and
    reverse vcvtt*/vcvt*2usi GPR destination are modeled.
  * The authoritative-width rule: the resolved ISA-fixed width never defers
    to an Intel PTR size annotation — a contradicting annotation REJECTS, on
    the heap and stack paths alike; only the size-driven widths (x87 PTR
    fallback, cvtsi2ss/sd integer source, narrowing converts) take their
    width from the annotation.
  * Masked-access metadata (fp.maskedAccessInfo): the supported {k}-masked
    vector moves, truncating stores, expand/compress forms and the AVX2
    vmaskmov/vpmaskmov forms get (element, lanes, vecsize, contiguous)
    metadata for the transform's mask-aware check; masked forms of anything
    else, {%k0}, and {k}-masked stack accesses stay rejected.
  * The unsafe-instruction reject list (each entry's reasoning lives under
    Limitations): privileged/system instructions, string ops and non-lock
    prefixes, gather/scatter, maskmovdqu, xsave/x87-state saves, implicit-GPR
    families (pcmpestri/pcmpistri, umwait/tpause), umonitor, AMX tiles, far
    control transfers, FSGSBASE/swapgs, TSX, CET notrack/setssbsy, SGX
    encls/enclu/enclv, skinit.

  Segment-register WRITES are rejected (the parser classifies
  %es/%cs/%ss/%ds/%fs/%gs as their own operand class, rc="seg", so the
  destination is visible; a bad selector raises an unconverted hardware
  fault). PUSH/POP of a segment register is rejected with its OWN message
  ("push/pop of a segment register is not supported (it transfers the segment
  selector, which the checker does not model)") — a push only READS the
  selector and a pop's selector load rides the stack push/pop machinery,
  while genuine selector writes keep the write-specific message. Plain
  selector READS (`movl %fs, %eax`) pass through: the destination web is
  defined with the selector's value, which is sound (the emitted instruction
  writes the web's allocated register); segment-QUALIFIED memory operands
  (`%fs:0x28`, Intel `fs:[0x28]`) still parse as symbolic displacements and
  keep their rejections.
- `*_frame.luau`   — frame policy: drop the input's frame setup/teardown, virtualize
  stack-pointer/frame-pointer-relative slots, reject stack-address escapes. (arm64
  also virtualizes NEON/FP stack slots into the raw-byte GPR slot webs — including
  the AAPCS callee-saved d8-d15 writeback save/restore forms — and derives the
  frame geometry that normalizes x29-relative alloca bases/offsets into the
  sp-relative coordinate space; see the arm64 NEON subsection of the frame
  section and the alloca-redirect NOTE below.)
- `*_codegen.luau` — per-arch instruction emitters (neutral micro-ops) for the transform.
  (arm64 includes the checked-access width/alignment model: NEON
  single-/multi-structure sizing with arrangement validation, pair forms, the
  LSE/LLSC/exclusive atomics at natural alignment, and the liveness/width-aware
  vector save/restore expansion around injected runtime calls.)
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
across rdx,rcx,r8,r9 (4 words max); arm64 packs from x2 across x2..x7 (6 words max) —
e.g. `long(long,long,ptr)` puts arg1 in x3 and arg2's intval/lower in x4/x5 —
and clang passes anything wider on the stack (sarcasm rejects such signatures).

NOTE (arm64 alloca region redirect): The `regionRedirect` mov branch (`mov xD, sp`
re-deriving a region pointer) redirects to `buffer + (0 - region.base)` via
`cg.addImm(rd, r.ptrTemp, -r.base)` — an addImm is required because a plain
`cg.move` is correct only for a region based at sp+0. arm64 also
recognizes x29-based alloca bases and normalizes x29-relative offsets in
region/slot math the way x86_64 does for rbp: arm64_frame.analyzeFrame derives
the frame geometry (frameSize, fpOffset, usesFp — x29 = sp + fpOffset when x29
is the frame pointer; it may be an ordinary GPR),
arm64_codegen.allocaRegionBase maps an `add xD, x29, #imm` alloca base into the
sp-relative coordinate space, and stackOff in cg.regionRedirect normalizes
x29-relative re-derivations the same way.

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
Matches the canonical prologue (ARM64: `stp x29,x30,[sp,#-N]!` or `sub sp,sp,#N` + `stp`
saves + `mov x29,sp`; X86_64: `push %rbp`/`mov %rsp,%rbp`/`sub %rsp` + callee-saved
pushes, `leave`, `endbr64`) and the symmetric epilogue. Records N, the callee-saved set,
and the spill-slot region. On X86_64, rbp-relative displacements are normalized to
rsp-relative frame offsets via frameSize when rbp is the frame pointer (rbp = rsp +
frameSize), and slots are KEYED by that normalized offset — so `-8(%rbp)` and `8(%rsp)`
(addressing the same byte with a 16-byte frame) share one slot web, while `-8(%rbp)`
and `-8(%rsp)` (different bytes) stay distinct. Distinct-width slot accesses whose
real-memory bytes overlap (a 4-byte store at rbp-52 over an 8-byte value at rbp-56)
are modeled as independent webs — the aliasing is not modeled (compilers do not
emit overlapping slot traffic). Any remaining stack access outside the analyzed
frame [0, frameSize) is rejected (on X86_64 the range is extended down by the
128-byte SysV red zone for rsp-relative and normalized rbp-relative offsets alike —
with rbp = rsp + frameSize, an rbp-relative d in [-frameSize-128, -frameSize), e.g. a
leaf function's `-8(%rbp)` with no `subq` at all, IS the red zone), as is taking the
address of the stack frame at all
(e.g. `add xD, sp, #k` / `leaq 8(%rsp), %rax` / `movq %rsp, %rax` — safety cannot be
proven).
sarcasm SYNTHESIZES its own frame regardless (for the SOV check + filc_frame push +
callee-saved for the new allocation), discarding the input's frame ops.

#### x86_64: no mid-function stack-pointer movement
Frame geometry is sound ONLY if every stack access executes with rsp at one known
value, so on x86_64 the frame size is derived from the PROLOGUE PREFIX ONLY: the
leading run of frame-setup instructions (callee-saved pushes/pops, `movq %rsp,%rbp`,
constant `subq $imm,%rsp` allocations and net-balanced `addq $imm,%rsp` undos),
interleaved with instructions that cannot observe or modify the stack state; the
prefix ends at the first stack access, control-flow instruction, jump-target label,
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
  through callee-saved pops and ordinary, non-stack computation only. A teardown-verified
  `addq $imm,%rsp` (and the `ret` terminating its span) is accepted even at an UNKNOWN
  depth: the constant cannot be PROVEN to undo a dynamic alloca, but every statement in
  the span is dropped and the synthesized epilogue owns the real %rsp, so the output is
  correct either way. A `leave` is
  legal ONLY as epilogue teardown (the teardown proof must reach the `ret`): a
  mid-function `leave` is always a compile error ("mid-function `leave` cannot be
  proven safe (a leave that does not lead directly to a ret may observe the caller's
  frame)" — hardware `leave` also restores the CALLER's frame pointer into %rbp), and
  a `leave` with no frame pointer established is rejected with its own error. Dynamic
  allocation must use the `;! alloca` annotation, not raw `subq %rax, %rsp`;
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
registers it actually uses — sound exactly because the depth analysis rejects every
stack access and return that could observe the shifted rsp. The alloca-annotated
dynamic `subq %rax, %rsp` makes the depth "unknown" until `leave`/`movq %rbp,%rsp`
restores it, so raw stack accesses in its scope are rejected while the annotated
alloca machinery itself (redirected to a GC allocation) keeps working. The alloca pops
nothing, so the abstract save stack SURVIVES across it (and across the inert
computation in its scope): the fp restore (`leave`, or `movq %rbp,%rsp` — the VLA
epilogue's %rsp recovery from the frame pointer) revives both the known depth and the save shape, and the teardown pops
after it pair with the prologue saves exactly as without an alloca. A constant
`addq $imm,%rsp` in the alloca's scope keeps the save stack too (it pops nothing);
whether it is a legal teardown is decided by the straight-to-`ret` proof above.

Dropping a callee-saved pop is sound ONLY when the pop provably restores a matching
dropped push: alongside the depth, the analysis tracks an abstract save stack (the
outstanding pushes — register + slot depth — in push order; merges require agreement
on every path), and a pop is rejected when no outstanding push of the SAME register at
the SAME slot depth is on top (mid-function or inside a teardown region alike). At an
UNKNOWN depth the slot depth cannot be checked; there a pop pairs off the outstanding
save stack by register alone, and ONLY inside a verified teardown — everything in such
a span is dropped and the synthesized epilogue owns the real %rsp, so only the
register identity matters; a redefined save still rejects an observable lost reload.
An
unpaired pop's load would otherwise be silently lost, and the slot it actually reads
is not that register's save — an unpaired `popq %rbx` after `pushq %rbp` reads the
saved frame pointer (a live stack address) into rbx. The same pairing rule nets out
transient save pairs inside the prologue prefix, so such a pop cannot masquerade
as balancing the frame-pointer save. Epilogue restores of prologue saves, balanced
shrink-wrapped pairs, and verified-teardown pops all pair exactly and keep being
dropped.

While a prologue-pad push is OUTSTANDING (e.g. `pushq %rbx` before the first frame
touch, popped only after), the bytes it saved are NOT an ordinary frame slot: their
content is mirrored by the pushed register's web, because the matching pop — proven to
restore exactly this register — is dropped. The rewrite therefore maps every stack
access at displacement (depth - save.depth) — 0 = the most recent push, 8 = the one
before it (the FIRST push sits at the HIGHEST address) — onto that register's web
instead of a slot web: a full 8-byte GPR store defines the register's web (the dropped
pop then naturally yields the stored value, matching real x86), a read-modify-write
operates on that web, and a load of any width at the slot base reads it (before any
store that is the pushed value). Anything else that overlaps a save slot is rejected:
a partial-width store (the web model has no subregister view, while the remaining slot
bytes keep the value the dropped pop restores), a vector/x87 access (it cannot name a
GPR web), an instruction whose register form is not exactly modeled (the rewritten
instruction is re-classified; the conservative first-reg-def fallback would desync
slot and register), and any access while the save state is unprovable ("dyn" — the
paths disagree on what is pushed, so no provable mapping exists). Virtualizing such an
access into an unrelated slot web would silently miscompile instead: the store would
never reach the register and the dropped pop would resurrect the stale pre-push
value, diverging from real x86, where the pop overwrites the register with the
stored value.
The saved FRAME POINTER (a `pushq %rbp` establishing the frame) is not a value slot
and never aliases here — it sits above the frame, where the bounds check already
rejects accesses.

ACCEPTANCE GAP (conservative, deliberate — soundness first): when a pad-pop's reload
is unmodeled (a `redefined` save whose pop is dropped but whose lost reload is judged
observable — see the checkLostReload walk in x86_64_frame), the analysis rejects
instead of stopping the walk at a re-push of the same save. Stopping there would be
UNSOUND: at the next iteration's re-push, the register's web does not hold the
hardware-faithful value (hardware restored the caller's value via the pop, while the
model's web still holds the body's last value), so the re-push would write that wrong
value into the new save slot — and a later slot access, or a use before the register
is redefined after the re-push, would silently observe the stale web value instead of
the hardware value. A standard save/restore around a loop-body load
(`pushq %rbx; movq (%rdi),%rbx; ...; popq %rbx; loop`) is therefore conservatively
rejected because the lost-reload walk crosses the back edge; restructure by not
saving/restoring the same register inside the loop — let sarcasm's own callee-saved
handling preserve it across the loop.

A prologue `movq %rsp, %reg` SAVE is prologue-transparent frame setup: the save is
DROPPED — sarcasm synthesizes its own frame, so the parked value has no meaning in
the output — and a `movq %reg, %rsp` RECOVERY from it is dropped with it, reviving
the saved depth (the save rides the depth analysis unchanged through a dynamic
alloca). The save must go into a CALLEE-SAVED register (a caller-saved one is
rejected — a call clobbers it, the injected runtime calls included; the exception is
a fixed-alloca-region base, redirected to the allocation pointer), and while the
save is outstanding its register must not be REDEFINED or READ (the rejection names
the register); a merge that disagrees on the save's redefined-ness poisons it, and a
POST-prologue `movq %rsp, %reg` stays a stack-address escape.

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
base/index, and the GPR halves of mixed GPR/vector instructions (cvtsi2sd,
movd, cvttsd2si, movmskps, kmov, fnstsw %ax, ...) with their correct def/use
roles. A memory operand of an FP/SIMD instruction is bounds-checked by the
transform at the width the x86_64_fp.luau knowledge module assigns the
mnemonic (see the module entry for the width rules, and the Limitations
classes for the rejection side); aligned forms (movaps/movdqa-class) also
check alignment, clamped to 8 like FilPizlonator's buildCheck (the runtime's
access-check origin cannot express larger alignments — a word-aligned but not
vector-aligned address passes the check and then faults in hardware, same as
compiled code). The resolved width is AUTHORITATIVE over any Intel PTR size
annotation — a contradicting annotation is rejected on the heap and stack
paths alike, including GPR accesses materialized into an FP-tainted frame
cluster, because a lying annotation would under-check the access or under-size
a materialized stack slot (a stack-overflow-into-the-caller hole); the
genuinely size-driven widths take the annotation and also RENDER at it, with
the emitted AT&T mnemonic carrying the encoding suffix (`fld QWORD PTR` ->
`fldl`) — a bare rendering would assemble at gas's default width and silently
change the checked access width.
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
instruction cannot take; heap masked accesses get the mask-aware check instead).
GC root slots keep their ABI-mandated position at the base of
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
the atomic pointer load/store/compare-exchange calls —
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
512 with `vmovdqu64`; a register dead across the call emits nothing. A call
node additionally carries `fpVecUses` — the FP arguments an annotated call
consumes (the source program placed them in xmm registers per the fast CC) —
as uses at the movss=4/movsd=8-byte live width, so an FP argument web stays
live from its definition up to the call and the save/restore brackets any
injected runtime call in between.

The width semantics come from `fp.vecEffects` (x86_64_fp.luau): each instruction
reports, per vector register NUMBER (xmm/ymm/zmm alias by number), a use width
and a "provided width" — the width up to which the instruction PROVIDES values
(written, or architecturally zeroed), with bits above flowing through from
before. Backward transfer for a register: a def with providedWidth p kills
liveness at or below p; a use at width u adds it (`live = max(u, live > p and
live or 0)`, so an RMW like addsd counts its own 8-byte merge read). For
example, a movss LOAD provides 16 bytes (writes 4, zeroes [4,16)), so a later
128-bit read sees the movss's zeros — liveness records 16 bytes live and the
save/restore preserves the zeros; an addsd provides 8 while its upper bytes
flow through. VEX/EVEX destinations provide 64 bytes (upper state zeroed to
MAXVL), VEX scalar forms merge from src1 at 16 bytes, EVEX merge-masked
destinations are also uses, accumulate-style forms (FMA, VNNI vpdp*,
vpternlog*, vpermi2*/vpermt2*, ...) read their destinations, and anything
unrecognized defaults to the safe direction (no def — everything flows
through — and all vector operands used at full class width). User calls (the
pizlonatedFI* thunks and passthrough calls) KILL all vector state (SysV:
values live across a call were already broken in the source program); the
injected filc_* runtime calls are TRANSPARENT (the placeholder pair around
them preserves the state). Only xmm0-15 are ever saved: the SSE2-only runtime
cannot touch ymm/zmm bits above 128, zmm16-31, or k0-7.

The frame reservation is UNCHANGED at 16*vecBytes (vecBytes = the function's
widest vector operand, 16/32/64; slot i stays at 16+i*vecBytes pre-shift) —
the optimization only elides/narrows the movs, never the reservation, so no
layout/computeLayout changes. The reservation is also FORCED at
16*16 = 256 bytes (`x86_64_frame.VEC_SAVE_BYTES`) when any signature in play —
the entry signature's FP args/return, or a callsite annotation's — carries a
float/double class, even if the body has no vector operand at all
(x86_64_frame.analyzeFrame forces it from the entry signature, transform.luau
from callsite signatures): an FP value riding in an xmm register needs the
save area in a GPR-only body just as much. The expanded movs carry no temps (named fixed
operands), so the register allocator
never sees them.

x87/MMX state is NOT saved: the injected runtime-call paths sarcasm wraps never
execute x87 code paths (compiler-generated code never keeps x87 values live
across such points anyway — even though libpizlo.a does contain x87
instructions, the fldt/fstpt in the zmath long-double wrappers), so the
program's x87 state survives across the wrapped calls. k-opmask state is
genuinely EVEX-only, so an SSE2-only runtime build cannot clobber it (an
AVX512 runtime build would require extending this to zmm16-31 and k0-7). The
whole mechanism still emits NOTHING for GPR-only functions with GPR-only
signatures — zero cost (fpSave/fpRestore emit no placeholders at all, and
expandFpSaves is a no-op scan); the one exception is an FP signature, which
forces the 256-byte reservation above even with no SSE instruction in the
body (the saves themselves stay liveness-driven, so a dead xmm still saves
nothing).

#### arm64: NEON/FP registers, slot virtualization, and injected-call saves
NEON/FP registers are IN SCOPE on arm64. As on x86_64 they pass
through verbatim — sarcasm never register-allocates them (regalloc never
models NEON), so instructions naming them keep their vector operands
unchanged and only their GPR operands (memory base/index, the GPR halves of
fmov/scvtf/ucvtf/dup & co) are modeled in defs/uses. The differences from
x86_64 are in the frame policy and the save discipline:

- **Frame slots VIRTUALIZE instead of materializing.** x86_64 materializes an
  FP-touched stack range into a real frame region because its vector ISA
  needs aligned memory operands; arm64's NEON scalar/pair loads and stores
  are just byte movers, so a NEON stack slot virtualizes into the same
  raw-byte GPR slot webs the GPR mechanism uses, via explicit GPR<->vector
  moves: `str q0, [sp, #16]` -> `fmov xslot16, d0 ; fmov xslot24, v0.d[1]`
  (the FMOV vector-element encoding only exists for the top half, so the low
  64 bits move as the d register), `str s0` -> `fmov wslot, s0`, a narrow
  `str b0`/`str h0` -> `umov` + `bfi` (preserving the neighboring bytes,
  like memory); a scalar load zeroes the register's upper bits exactly like
  the ldr it replaces, and pairs (stp/ldp/stnp/ldnp of s/d/q) virtualize per
  element. The AAPCS callee-saved NEON prologue/epilogue writeback forms
  (`str d8, [sp, #-32]!` / `ldr d8, [sp], #32`, `stp d8, d9, ...`) — which
  CANNOT be dropped like the GPR stp/ldp boilerplate, since the caller's
  d8-d15 values must round-trip — virtualize at their final-sp-relative
  offset (tracked via a cumulative sp adjustment, since the writeback's own
  sp update is frame setup we drop). The forms that cannot be virtualized on
  a frame base — multi-structure ld2-4/st2-4, the replicate loads ld1r-4r,
  and lane-indexed single-element forms — are rejected cleanly; on a heap
  base they are modeled memory accesses at their exact width (N structures x
  register width, or N x element for lane/replicate forms; arrangement
  qualifiers validated so a malformed register list never under-checks).
- **Width-liveness vector saves.** AAPCS64 makes v0-v7 and v16-v31 fully
  caller-saved and only the low 64 bits of v8-v15 callee-saved, and the
  Fil-C runtime is built with a full NEON toolchain — so sarcasm's injected
  RETURNING runtime calls are bracketed by saves, and user calls kill
  caller-saved vector state (v8-v15 degrade to their callee-saved low 8
  bytes). Mirroring the x86_64 design, fpSave/fpRestore emit placeholder
  nodes and expandFpSaves runs a backward per-vector-register WIDTH
  liveness (semantics from arm64_isa.vecEffects: NEON loads supply their
  full registers, lane loads merge, stores read only the stored bytes, the
  lane-insert ins/element-fmov destinations read the untouched lanes, and
  an unknown mnemonic — e.g. the crypto families — reads every NEON operand
  at its width and provides nothing, a safe default that never under-saves):
  a v-reg live only in its low 4 bytes saves as sN, 8 as dN, 16 as qN, a dead
  one saves nothing, and v8-v15 save only when live at MORE than 8 bytes.
  The save area is 16 bytes per v0..v31 slot past the GC root area, reserved
  regardless of elision; a GPR-only function emits NOTHING (vecSaveBytes == 0).
- **SVE/SVE2 is rejected** (arm64_isa.checkSve, run on every instruction):
  z0-31/p0-15 registers in any operand position (including structure lists
  and memory base/index) and the SVE-only mnemonic family (rdvl/addvl/
  inc*/dec*/cnt*/while*/ptrue/...) error with "SVE is not yet supported
  (NEON/AdvSIMD only)" — variable-width vector state cannot be modeled by
  the fixed 16-byte slot/save machinery.

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
- EFLAGS for the RMW/CAS sequences: these injected sequences clobber EFLAGS
  and are deliberately NOT bracketed by the flag save/restore (their
  native-flag contract depends on it — see below), so the operation is
  re-executed on a scratch copy of the kept-alive pre-op value (and source)
  as the LAST flag-affecting step — a jcc/setcc immediately after the
  annotated instruction sees the native flags (for the CAS, the comparison
  uses a private pre-call copy of the expected intval, since expected and
  result webs can coincide in a retry loop). `not` sets no flags to recompute
  — the documented EFLAGS caveat. adc/sbb are the other caveat, and it is
  wider than the flags: they read a carry-in the injected sequences already
  clobbered, so BOTH the recomputed flags AND the stored result carry it —
  the op itself runs on the clobbered carry (CF=0 after the non-atomic
  `;! load store ptr` load sequence's closing `test`; indeterminate —
  whatever the runtime call left — for the atomic forms), and the flag
  recompute runs on whatever the store/CAS sequence left. So a flag consumer
  that does not immediately follow one of these RMW/CAS sequences still sees
  clobbered flags — but every OTHER injected sequence site (plain access
  checks, pollchecks, allocas, ptr loads/stores, masked accesses) preserves
  the program's flags via saveFlags/restoreFlags whenever the flag-liveness
  scan says they are live (the same withFlagSave machinery arm64 uses; see
  the "Flags" bullet under the arm64 atomics below).
- xadd with `;! load store ptr` / `;! atomic load store ptr` is rejected: its
  source register is also a destination and would receive the old pointer
  value (needing a pointer def + rooted lower — and its use/def web union
  would mis-seed the delta value as a pointer); cmpxchg with them is rejected
  (use `;! atomic ptr`); shifts/rotates/imul are rejected (not
  capability-preserving); all five ptr-family annotations are rejected on
  cmpxchg8b/cmpxchg16b (x86_64) and casb/cash/casp (arm64).
- ARM64 atomics. Non-pointer atomics are modeled directly as single
  checked memory accesses, needing no annotation (like x86_64's lock-prefixed
  RMWs on non-pointers): the LSE family (swp/ldadd/ldclr/ldeor/ldset/ldsmax/
  ldsmin/ldumax/ldumin + the st<op> no-result aliases, all widths and a/l/al
  ordering variants), cas/casp (+variants), and the exclusive family (ldxr/
  stxr/ldaxr/stlxr +b/h, ldxp/stxp/ldaxp/stlxp). Checks: full bounds + CanWrite
  on every write + NATURAL alignment (the ARM ARM requires it for these — the
  ldxp/stxp/casp pair forms fault on anything less in practice, and single-word
  forms do on some cores — so an unaligned atomic gets the deterministic filc
  alignment trap, never a hardware-dependent fault). Register modeling:
  swp/ld<op>'s old-value destination is a def, the source a use; stxr/stxp's
  status register is a def; cas's compare register is an architectural
  read-modify-write modeled with the pin mechanism (implicit use+def operand
  tables, like x86_64's cmpxchg accumulator) so regalloc keeps both sides in
  the written physical register; casp's compare AND data pairs are both
  pinned (the hardware encodes a pair as one even register number, so all
  four explicit registers must render at their written numbers). The
  annotated pointer forms mirror the x86_64 contracts with arm64 shapes and
  AAPCS64 marshalling (a filc_ptr is two consecutive argument words;
  filc_strong_cas_ptr_with_manual_tracking's eight argument words and
  filc_xchg_ptr_with_manual_tracking's six all fit in x0..x7 — no stack
  marshalling; results arrive x0=intval, x1=lower):
  - `;! atomic load ptr` on ldr/ldur/ldar/ldapr xN -> access-check(8, align 8)
    + filc_load_ptr_atomic_with_manual_tracking_outline(slot). `;! atomic
    store ptr` on str/stur/stlr xN -> access-check(8, align 8, CanWrite) +
    filc_store_ptr_atomic_outline(myth, slot, value). (No writeback forms —
    no atomic encoding has one.)
  - `;! atomic ptr` on cas/casa/casl/casal xA, xB, [xM] (64-bit only;
    casb/cash/casp rejected like cmpxchg8b/16b) -> access-check(8, align 8,
    CanWrite) + filc_strong_cas_ptr_with_manual_tracking(myth, slot, 0,
    expected, new). The pin tables let the transform find the compare
    register's use (expected) and def (old result, pointer-seeded, lower
    rooted) webs without emitPinned. NZCV is recomputed as (expected − old)
    against a private pre-call copy of the expected intval, so a following
    b.eq/cset behaves like x86_64's cmpxchg flags.
  - `;! atomic load store ptr` on a 64-bit LSE RMW (ldadd/ldset/ldeor/ldclr/
    swp + variants, and the st<op> aliases): the instruction is already a
    single atomic RMW. For ldadd/ldset/ldeor/ldclr (and the st<op> aliases)
    the lowering is the runtime compare-exchange loop (the x86_64 `lock`
    form's analog): inline checks once before the loop; per iteration a
    pollcheck, an atomic load, the op re-executed as a register ALU
    operation on the intval (ldadd->add, ldset->orr, ldeor->eor,
    ldclr->bic), and the CAS call with new = (old.iv OP src, SAME lower) —
    the capability rides through: Fil-C pointer arithmetic through memory.
    swp is the exception (its plan ALU is "mov"): the new value IS the
    source operand, not a function of the old value, so stamping it with
    the old value's lower would store a SOURCE pointer into a DIFFERENT
    object with the OLD object's capability (the next dereference traps
    "cannot read pointer with ptr >= upper"). swp therefore lowers to a
    single filc_xchg_ptr_with_manual_tracking(myth, slot, 0, new) call —
    the exact primitive filcc emits for C11 atomic_exchange (a direct call,
    no pollcheck; the runtime retries a weak CAS internally) — with new =
    (src.iv, src's OWN lower); a non-pointer source has no lower temp and
    is marshalled with a null capability (mirroring `;! atomic store ptr`:
    storing an integer into a pointer slot is legal, it just can't be
    dereferenced afterwards). The old-value destination register (ldadd's
    Wt / swp's Wt) is pointer-seeded and receives (old.iv, old.lo) rooted —
    exactly like an `;! atomic load ptr` result (the st<op> forms have
    none). NZCV is PRESERVED across the whole sequence (withFlagSave): the
    native LSE forms write no flags, so there is nothing to recompute. The
    min/max forms are rejected (no single capability-preserving ALU op);
    sub-word forms are rejected (pointer slots are 8 bytes).
  - `;! load store ptr` (the non-atomic form) is rejected on arm64: no
    non-atomic memory-destination RMW instruction exists — write the ldr/op/
    str sequence with separate `;! load ptr` / `;! store ptr` annotations.
  - Flags: the annotated ldar/stlr/ldapr and LSE RMW forms write no NZCV, so
    their injected check+call sequences are bracketed by withFlagSave when
    the program's flags are live — the flag-liveness scan + save/restore
    machinery runs on BOTH backends (x86_64's saveFlags/restoreFlags
    round-trip EFLAGS through pushfq and a regalloc-owned virtual temp); only
    the annotated cas has a flag contract (the recompute above).
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
  [2^64 - size, 2^64) (reachable: pointer base + a huge index via lea) and
  would pass a wild address through to a CPU fault instead of a clean filc
  trap; real
  uppers are < 2^48, so `upper - size` never wraps and any eff that large
  fails the compare. (The ptr-store sequence's inline upper-bound check uses
  the same form; the size==1 arm needs no form change — a direct `eff uge
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
  Supported: {k}-masked vector moves (vmovdqu8/16/32/64, vmovups/upd, the
  aligned vmovdqa32/64 and vmovaps/pd, keeping their clamped-to-8 alignment
  check), the truncating/saturating vpmov stores (E = the memory element
  size, N = the memory lane count), vexpand*/vpexpand* loads and
  vcompress*/vpcompress* stores (contiguous), and the AVX2 vmaskmov/vpmaskmov
  forms. {%k0} is rejected (not
  a valid writemask — gas rejects it too); masked forms of anything else
  (masked ALU memory sources, gathers/scatters as ever, AMX) stay rejected;
  {k}-masked STACK accesses stay rejected (the frame rewrite virtualizes/
  materializes slots and cannot model masked-off lanes); and a {k} on a
  BROADCAST memory operand ({1toN} or vpbroadcast*/vbroadcast*) rides the
  plain element-width check — the read is unconditional, the mask only gates
  the register destination (verified against the SDM and filcc).
- annotations are validated, never silently ignored: `;! load ptr` / `;! store
  ptr` require a plain 8-byte GPR load/store of the matching direction (a
  mismatch would silently replace the instruction with an invisicap access of
  the wrong shape); a memory-destination RMW carrying one is rejected
  (pointer RMWs need `;! load store ptr`); the five ptr-family annotations
  (`;! atomic load ptr`, `;! atomic store ptr`, `;! atomic ptr`,
  `;! load store ptr`, `;! atomic load store ptr`) are shape-validated by the
  per-arch backend (`ptrAtomicShape`): the atomic load/store forms are at
  least as strict as the plain ones, `;! atomic ptr` requires an 8-byte
  memory-destination cmpxchg, the RMW forms require a supported 8-byte
  mem-RMW, everything else is rejected with a precise error (on
  cmpxchg8b/cmpxchg16b EVERY ptr-family annotation is rejected — a
  double-width CAS cannot operate on invisicaps); any other
  unrecognized annotation string on an instruction is a compile-time error.
  (Marker spelling, once, since these bullets all use the universal form: every
  `;!`-spelled annotation can equivalently be written
  `#!` on x86_64 or `//!` on arm64 — the RECOMMENDED spellings, see README's
  "Annotation markers". The annotation NAME is what the bullets document; the
  marker only introduces it, whichever of the three is used.)
- calls (`;! sig` on the call insn — REQUIRED on every direct call: an unannotated
  direct `call foo`/`bl foo` is rejected by body validation on BOTH architectures,
  see Limitations) -> marshal args into the Fil-C CC registers, call the
  callsite thunk `pizlonatedFI<sig>_foo`, test the exception flag (propagate on
  throw), read results. If `foo` is defined and annotated in the same module,
  `pizlonatedFI<sig>_foo` is a strong `.set` alias of its fast entrypoint (no
  resolver involved); otherwise sarcasm emits one weak/hidden callsite resolver
  thunk per distinct called external — it resolves the callee through
  `pizlonated_foo`, validates non-null capability, FUNCTION special type,
  canonical intval and signature (a DATA symbol panics at the special-type
  check), takes the fast entrypoint on an exact signature match, and marshals
  through the generic buffer CC on a mismatch.
- indirect calls (`call *%reg ;! sig(...)` on x86_64, `blr xN ;! sig(...)` on
  arm64 — both architectures support REGISTER-operand annotated indirect
  calls through the same arch-neutral transform code; on arm64 validateBody
  delegates to the shared annotation walk, which accepts exactly the annotated
  register-indirect shape) -> filcc's exact indirect-call sequence for the
  flight pointer (P = target intval temp, L = its lower temp): L==0 -> fail;
  aux = [L-8] must satisfy (aux & 0x780000000000000) == 0x80000000000000
  (special type FUNCTION); P must equal aux & 0xFFFFFFFFFFFF (the canonical
  entrypoint); then the signature word at [L+16] dispatches: a match calls
  the fast entrypoint at [L+0] with the direct call's fast-CC marshalling
  (rdi=myth, rsi=L, dense args; pointer args as iv,lower pairs), a mismatch
  runs an INLINED generic (buffer-CC) call through [L+8] — the arguments are
  stored into my_thread's CC buffer (data words at 128(myth), aux/lower words
  at 384(myth), zeroed aux for scalars), rdx = argument byte size, and after
  the call the returned ret_size in rdx is checked (else
  filc_cc_rets_check_failure) and the result unmarshalled from the buffer —
  exactly the callsite thunk's L_generic mismatch path, so (unlike filcc,
  which calls the weak pizlonated1ET<sig> thunk there) sarcasm has no link
  dependency on pizlonated1ET<sig>, which exists only when some C compilation
  unit contains an indirect callsite with that signature. Both paths rejoin at
  the direct call's exception-flag test
  and result unpacking (a pointer result's lower comes from rcx and is rooted
  immediately). All failure edges share one stub:
  filc_check_function_call_fail(rdi=P, rsi=L). The target register's web must
  be a known pointer value (ptrflow must know its lower) — a pointer
  argument, a `;! load ptr` result, or a ptr-returning call's result;
  anything else is a compile-time error, as are an UNANNOTATED indirect call
  (which would otherwise reach memory unchecked, with no caller-saved clobber
  modeling) and ANY memory-operand indirect call (`call
  *mem` — the loaded value has no capability; load the function pointer into
  a register first, e.g. via `;! load ptr`). The lift models the yolo
  argument registers as uses and the result register as a def for an
  annotated indirect call exactly like a direct one, and the renderer emits
  the AT&T `*` for indirect call/jmp operands (clang's integrated assembler
  rejects the star-less form). On arm64 the same sequence is emitted for
  `blr xN ;! sig(...)` through the same shared code with the arm64 CC
  registers (x0=myth, x1=L, dense args from x2, w2=argument byte size,
  x1 doubles as the ret-size register, fail stubs use plain `bl` — no @PLT
  relocations); the signature immediate uses the same movz/sub-cmp/movk
  widening as the callsite resolver. Memory-operand indirect calls do not
  exist on arm64 (`blr` is register-only), so the x86 `call *mem` rejection
  has no arm64 analog.
- loops (back-edges from the CFG) -> insert a pollcheck at the loop header.
- X86_64 implicit-counter support (`loop`/`loopq`/`loopl`, `jrcxz`, `jecxz`):
  the counter is an IMPLICIT register operand the emitted instruction always
  operates on physical rcx, so the counter's (unified use+def+RMW) web is
  PRECOLORED to physical rcx (fixedReg from classify -> temps[t].precolor in
  the transform) — the modeled decrement/branch must land in the register the
  hardware actually decrements/tests. Two invariants make the precolor SOUND:
  - The counter's fixed color is EXCLUSIVE for the whole function (transform
    collects the fixedReg webs and hands the color set to regalloc's
    `reserved` option): rcx is removed from the allocator's color pool and
    coalescing into any precolored temp OF a reserved color is blocked, so no
    other web can ever be ASSIGNED rcx or INHERIT it by aliasing an entry-unpack
    or argument-marshal move. This de-precolors the entry/dense-arg webs the
    fast CC seeds from rcx (a pointer argument's capability lower at dense
    slot 2, an int argument's intval at dense slot 2): their entry unpack move
    (rcx -> allocated web) becomes a real copy and regalloc spills/reloads them
    like any web. Without this, a counter web defined while a pointer
    argument's capability LOWER web was still live silently destroyed the
    lower (the IRC's George criterion coalesced the lower into the pinned
    physical rcx) and every later bounds check read the COUNTER as the
    capability lower. Nested loops with two counters are hardware-faithful:
    each counter def is a modeled rcx web def and all counter webs alias the
    same physical register exactly as the hardware register does.
  - Annotated CALLS in a counter function split into three classes, each with
    its own handling of physical rcx:
    * POINTER-returning annotated calls (direct and indirect, `retIsPtr`): the
      counter is NOT preserved — the call DEFINES the counter web from the
      result's LOWER web right after the call's result unpacking. Under the FIP
      CC the callee delivers a pointer result's lower in retLo = rcx, so
      hardware rcx after the call IS the returned lower; the pre-call counter
      value is gone (the callee's return destroyed it), and restoring it would
      stomp the returned lower. The wire is a plain copy (rcx already holds this
      value, so it changes no hardware behavior); it makes the MODELED web
      match the register. The lower web is the callee's modeled capability
      lower (a real object base, or zero for an unmodeled result) — sarcasm
      never delivers an arbitrary asm-written rcx value as a returned lower,
      because the caller roots every call-result lower into a GC root slot and
      the GC marks filc_object_for_lower(lower) blindly (a fabricated lower
      would crash the next safepoint).
    * INJECTED runtime calls (pollcheck slow path, filc_allocate, the aux/barrier
      slow paths, the atomic pointer operations): the counter IS preserved
      (save/restore of the counter web through a fresh scratch web, which, being
      live ACROSS the call, the allocator keeps out of every caller-saved
      register — callee-saved or spilled). Hardware has no such call at all, so
      preserving the counter around it is definitionally exact.
    * NON-pointer-returning annotated calls (direct and indirect): the counter
      IS preserved the same way. This matches plain hardware only when the
      callee leaves rcx alone — sarcasm cannot see the callee's internal rcx
      usage, and the arg marshal writes dense rcx (a call's 4th GPR argument
      word, or a pointer argument's lower at dense slot 2) BEFORE the call,
      which plain hardware does not do. This residue is documented and
      deterministic, and preserving is the closest-to-hardware choice: plain
      hardware leaves the pre-call counter alone, while not preserving would
      let the marshal's dense-rcx write reset the counter every iteration (a
      `loop` countdown whose body calls never terminates).
    Every pollcheck in a counter function preserves rcx — the counter's OWN back
    edge passes its web explicitly (loopHeaderRcx), any other header (a GC-churn
    loop whose back edge is a plain `jmp`, a CAS retry loop) falls back to the
    representative counter web; a pollcheck at a non-counter back edge otherwise
    lost rcx to filc_pollcheck_slow. The noreturn fail stubs need no save.
    Functions WITHOUT counters reserve nothing and emit nothing — their output
    is unchanged.
- X86_64 rel8-counter branches (`loop`/`loopq`/`loopl`, `jrcxz`, `jecxz`) are
  rewritten at RENDER time, unconditionally, through a rel8-reachable
  TRAMPOLINE (x86_64_render): these instructions re-emit verbatim and have NO
  encoding other than rel8, while the instrumentation (the pollcheck at a
  back-edge label, the per-access bounds checks) routinely pushes their target
  beyond +-127 bytes — gas would reject the whole file with an opaque "value
  of ... too large for field of 1 byte" from the temp .yolo.s. Sarcasm cannot
  predict the post-instrumentation displacement, so every such branch is
  emitted as `loop .Lsarctramp_<fn>_<n>t` / `jmp .Lsarctramp_<fn>_<n>s` /
  `.Lsarctramp_<fn>_<n>t:` / `jmp <original target>` / `.Lsarctramp_<fn>_<n>s:`
  — the trampoline label is 2 bytes ahead (always in rel8 reach), the skip jmp
  lands past the stub, and the stub's `jmp` can be rel32. NO flag-affecting
  instruction is added (jmp preserves all flags; loop/jcxz do not read them —
  a dec/jne rewrite is REJECTED: it would change the flags the fall-through
  path observes), fall-through semantics are unchanged, and the IR-level
  instruction plus its original target stay untouched (validateBody,
  reachability, liveness, the counter precolor and the pollcheck-at-back-edge
  machinery all still see the original branch — the trampoline sits at the
  jump site, the pollcheck at the label site). `<n>` is a per-function
  statement-order counter, bumped past any user label name anywhere in the
  FILE (the .Lsarctramp_* symbols are file-global: a user label named like
  another function's generated trampoline name otherwise collides in the
  object; generated names of different functions cannot collide, since each
  embeds its own function name), so synthesized labels are unique and
  deterministic.
- alloca annotations -> a GC allocation via filc_allocate (payload = allocation + 16,
  the capability rooted), not real stack memory. The `;! alloca size (x)` name goes in
  EITHER of two places. The DEFERRED form puts it on a value-producing (register-dest)
  instruction that dominates the result (CFG reachability) and precedes it in body
  order, so the captured size is defined wherever the allocation runs: that
  instruction STAYS and
  computes the size. The ALLOCATION form puts it on the %rsp-writing allocation
  instruction itself (x86_64 `subq %rax, %rsp`; arm64 `sub sp, sp, xN`): that
  instruction is DROPPED and replaced by the allocation — filc_allocate consumes the
  size value it carried. `;! alloca result (x)` sits on the instruction whose
  destination the allocation replaces; its name must match a `;! alloca size (x)` name
  (mismatched names are rejected as a missing size), and in the allocation form it
  goes on the first instruction reading %rsp after the allocation instruction —
  capturing the address with `leaq disp(%rsp), %rd` or `movq %rsp, %rd` compiles
  identically. The remaining %rsp-mutating setup and its rsp-derived address chains
  are dropped, and the dead-code-elimination pass removes the now-orphaned arithmetic.
  `;! alloca result
  size=N` (fixed region) instead annotates a `leaq disp(%rsp), %rd` / `movq %rsp, %rd`
  (or `leaq disp(%rbp), %rd` when rbp is the frame pointer): it defines [base,
  base+N) in frame coordinates; rsp math landing inside is redirected to the
  allocation pointer, and direct stack-relative accesses into a region are rejected.
  While %rsp is perturbed by an alloca, %rsp-relative frame accesses are rejected and
  %rbp-relative slots keep working: the frame pointer is tracked per program point
  (established by `movq %rsp,%rbp`, invalidated by a paired `popq %rbp`/`leave`), and
  a %rsp recovery (`movq %rbp,%rsp`, `leaq N(%rbp),%rsp`, or `movq %reg,%rsp` from an
  unredefined prologue save) revives the known depth. The dropped machinery is chosen
  by form, not position: the recovery forms above and the teardown `addq $imm,%rsp`
  are never marked as alloca machinery, so they are honored — not swallowed — even in
  the same straight-line region as the `;! alloca result` annotation, and a
  branch-free alloca function recovers %rsp and pops its epilogue immediately after
  the result.
- dead-code elimination then deletes instructions whose modeled defs nothing
  forward-reachable reads.
- fabricate prologue: SOV check + filc_frame push (prev,origin,roots) + callee-saved.
- roots: store each live-across-safepoint pointer's lower into a frame root slot;
  origin count field = number of root slots.
- injected RETURNING runtime calls (the pollcheck slow path, filc_allocate, the
  atomic pointer load/store/compare-exchange calls, the ptr-store
  aux-ensure/barrier slow paths) -> wrap in a vector save/restore; the
  source program never saw these calls and the runtime clobbers the vector
  registers. A no-op for GPR-only functions unless a signature in play carries
  a float/double class — the full mechanism (width-aware saves, reservations,
  the x87/k-opmask exceptions) is described in the frame section's FP/SIMD
  subsection and the arm64 NEON subsection.

- Determinism invariant: transform output is deterministic across processes —
  every site whose iteration order could reach the output (or the temp/slot
  numbering) iterates a sorted key array instead of a table. Re-verify by
  running the transform on the same input several times and diffing the
  outputs: all runs must be byte-identical.

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

#### Command-line target selection (--x86_64 / --arm64 / --intel / --at&t)

The target is auto-detected as above; four options force it explicitly, bypassing
detect.luau:
- `--x86_64` — select the X86_64 backend; the input syntax (AT&T vs Intel) is still
  auto-detected, so a `.intel_syntax`/`.att_syntax` directive still applies. When
  the input carries no syntax directive and no x86 syntax marker at all, the
  syntaxless forced case defaults to AT&T (GAS's x86 default): an unadorned
  x86_64 parse would silently be INTEL parsing (x86_64_parse only special-cases
  "att"), so bare `--x86_64` is pinned to AT&T. An explicit `--intel`/`--at&t`
  still wins.
- `--arm64` — select the ARM64 backend.
- `--intel` — select the X86_64 backend with Intel input syntax.
- `--at&t` — select the X86_64 backend with AT&T input syntax.

The options conflict with each other: `--x86_64` with `--arm64` (both select an
architecture), `--intel` with `--at&t` (both pin a syntax), and any architecture
selector with a syntax-pinning selector (`--x86_64` with `--intel`/`--at&t`,
because a pinned syntax already implies X86_64; `--arm64` with all three).
Conflicts are usage errors (exit code 2) naming the flag seen earlier on the
command line; repeating the same option is harmless.

## Limitations (compile-time rejections)
Assembly that cannot be proven safe is rejected with a clean `sarcasm: <file>: <msg>`
error (exit code 1). Current limitations, enforced on both architectures unless noted:
- Every function declared `.type NAME, %function` and defined in the file MUST carry a
  signature annotation on its label; an unparseable signature is likewise rejected.
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
- Indirect calls: on BOTH architectures a register-indirect call is supported
  when it carries a `;!` callsite signature and its target register's web is a
  known pointer value (`blr xN ;! sig(...)` on arm64 — validateBody delegates
  to the shared annotation walk; `call *%reg ;! sig(...)` on x86_64; see the
  transform section's indirect-call bullet for the emitted check and dispatch
  sequence). Rejected on both: an unannotated register-indirect call
  ("indirect call has no signature annotation (annotate the callsite with the
  callee's signature, e.g. `int(ptr)`)"), and an annotated call
  whose target web is not pointer-typed ("indirect call target must be a
  function pointer value..."). On x86_64 additionally ANY memory-indirect call
  `call *mem`, annotated or not ("indirect call through a memory operand
  cannot be made memory-safe (load the function pointer into a register
  first...)") — memory-operand indirect calls do not exist on arm64
  (`blr` is register-only).
- Unannotated DIRECT calls (`call foo` with no signature annotation) are
  rejected on BOTH architectures (validateBody, gated on each backend's
  `strictBodyValidation` — enabled on both: a passthrough would land the call
  in the callee's FIP body without myth marshalling and could never link
  against C callees, which filcc names `pizlonated_*`, never bare `foo`). The
  rejection message matches arm64's ("call to 'foo' has no signature
  annotation (annotate the callsite, e.g. `call foo ;! int(ptr)`)").
- Indirect BRANCHES are rejected on BOTH architectures in all raw forms: arm64
  `br xN` and `b xN`/`cbz xN, xM` with a register operand (any non-label branch
  target classifies as an indirect branch), and x86_64 `jmp *%reg` / `jmpq *%reg`
  and `jmp *mem` (both classify as indirect branches — the renderer would
  otherwise pass `jmp *%rax` through verbatim as an uncontrolled branch; memory
  targets are also caught by the moffs rejection when the operand names a symbol
  or absolute address, e.g. `jmp *myglobal`). A branch whose target operand is
  not a label at all (`jcc *%reg`, which is not even encodable, or a raw
  absolute `jmp $imm`) is rejected by the shared no-label-target check; a branch
  to a non-local LABEL is a tail call and is rejected on both (even annotated).
  Label-target branches inside the function (loop back-edges, `jmp
  .Llabel`/`1b`) keep working — all of this closes the same unvalidatable
  control-flow hole.
- (x86_64) explicit high-byte operands — the `%ah` subregister gap: sarcasm's
  web model has no subregister view, and `ah` and `al` both parse to the SAME
  web (register 0, width 8; see x86_64_isa.luau), while the renderer names the
  LOW byte of whatever register that web is colored into — an explicit `%ah`
  operand names the low byte of the colored register, the architectural AH only
  when the web sits in physical rax. `setcc %ah` is REJECTED ("setcc with the
  high-byte destination %ah is not supported (only the low byte of a register
  is modeled; use the low-byte form, e.g. `sete %al`)"), but every other
  explicit `%ah` operand is silently accepted at the low byte (`movb %al, %ah`
  renders `movb %al, %al`; `movzbl %ah, %edx` reads `%al`), so a program that
  really wants AH must pin its value to rax itself. lahf/sahf are NOT affected
  — they are modeled as
  implicit full-web RMW/use of the 64-bit rax web pinned to physical rax, so
  the flag byte lands in bits 8-15 of the colored register wherever it lives.
- A branch to the function's OWN ENTRY NAME (`jmp f` from inside `f`) is
  rejected on BOTH architectures (shared validateBody branch-target check): the
  entry label is in the body's local-label set, but the entry symbol itself is
  renamed away, so the branch would only die at link time ("undefined
  reference") — and if it did link, re-entering the prologue would re-run the
  SOV check against a perturbed rsp and grow the frame unboundedly.
- A body that can FALL OFF ITS END is rejected on BOTH architectures: a shared
  reachability worklist over the raw body's statement indices (unconditional
  label branches go only to their target; conditional branches also fall
  through; `ret` stops a path; every other statement — calls and indirect forms
  included — falls through) proves whether the index one past the last
  statement is reachable, i.e. whether some control-flow path runs past the end
  of the body without executing `ret`; the emitted FIP body would then fall
  through into sarcasm's own next emission (the generic-entry thunk or a fail
  stub) and execute through caller-garbage registers. Error: `sarcasm: function
  'f' can fall off the end of its body; every control-flow path must end with a
  ret instruction: ...`. A body ending in an infinite loop has NO reachable
  fall-off and stays accepted. This runs before the frame pass, whose
  control-flow walk only understands validated bodies. One conservative
  consequence: a call to a noreturn function is still just a call — it falls
  through — so a body whose ONLY exit is such a call is rejected; restructure
  it with a `ret` after the call (unreachable but present) or an explicit
  infinite loop.
- Top-level (inter-function) content is scanned on BOTH architectures with
  identical semantics. Data under a global or referenced label, symbol/macro
  definitions (`.equ`/`.set`/`.macro`/`.comm`/...), instructions outside any
  function, and labels outside any function are rejected; provably dead
  content (an unreferenced, non-global local label and its data bytes) is
  dropped, and structural directives (`.text`, `.section .note.GNU-stack,"",@progbits`,
  `.p2align`, `.cfi_*`, `.type`, `.size`, ...) stay accepted+ignored.
- On X86_64, instructions that manipulate processor state sarcasm cannot model, or
  that touch memory the checker cannot see, are rejected with clean `sarcasm:`
  errors — the full class list with per-instruction reasoning is in the
  enter/enterq bullet below.
- Exception propagation through sarcasm x86_64 frames: NOT SUPPORTED (intentional,
  for now). The x86_64 glue emits every function origin with personality_getter = 0
  (`.quad 0`) and can_throw = can_catch = has_setjmps = 0 (`.byte 0/0/0`), so Fil-C
  unwinding (filc_native__Unwind_RaiseException, libpas/src/libpas/filc_runtime.c)
  fatals at any sarcasm x86_64 frame whose origin is !can_catch: a C++ exception
  thrown in code CALLED from sarcasm x86_64 assembly terminates the process instead
  of reaching a handler in an outer frame — it can neither be caught inside nor
  propagate through the sarcasm x86_64 frame. The arm64 glue emits can_throw =
  can_catch = 1 (personality still NULL — no landing pads, so a throw still cannot
  be CAUGHT inside sarcasm code, but it DOES propagate through sarcasm arm64
  frames). Detailed in ABI-NOTES-x86.md's "Exceptions / unwinding" section.
- Floating-point signatures: float/double are FULLY SUPPORTED in `;!`
  signatures on BOTH architectures, entry and callsite alike (see the
  "Floating-point signatures" section below). Still rejected on both:
  `long double` (no fast CC on arm64; stack-passed on x86_64) and the vector
  classes (a vec4 signature would need q-register/xmm-vector CC machinery,
  and filcc's encoding only matches sarcasm's formula for vec4 anyway).

- Taking the address of the stack frame is rejected (cannot prove safety): by
  address arithmetic off the stack register (`add xD, sp, #k` / `leaq
  8(%rsp), %rax`), by copying it (`movq %rsp, %rax`), or by storing it into a
  frame slot (`movq %rsp, (%rsp)` — the slot virtualization rewrites only the
  memory operand, so the live sp/fp value would leak into a virtual temp). The
  full mid-function stack-pointer-movement policy is in the frame section.
- Stack accesses outside the input frame — below it (on X86_64, below the
  128-byte SysV red zone under rsp, via rsp- or normalized rbp-relative
  offsets alike), above it, or stores into the caller's argument area — are
  rejected, as are indexed stack-relative access and a stack-relative memory
  operand with a SYMBOLIC displacement (`movq foo(%rsp), %rax`) — its target
  is unknown at compile time, so it cannot be bounds-checked or virtualized.
- alloca requires the annotation pair: an `;! alloca result (x)` with no
  preceding `;! alloca size (x)`, a duplicate size for the same name, or a
  direct stack-relative access into an alloca region are all rejected. For
  `;! alloca result size=N` the annotated instruction must compute the buffer
  base stack-frame-relative (`leaq disp(%rsp), %rd` / `movq %rsp, %rd`, or
  `leaq disp(%rbp), %rd` when rbp is the frame pointer); any other base is
  rejected rather than silently creating no region (the region redirect is
  described in the transform section).
- Dropping the alloca's %rsp-mutating instruction also discards its flag effects: a
  body whose control flow consumes the flags of that instruction (branching on the
  allocation's `sub`/`mov` flags) observes different flags than hardware. An
  alloca-using body must not branch on the flags of its dropped stack math.
- On ARM64, memory operands on non-load/store instructions are rejected; X86_64 accepts
  them (e.g. `addq (%rsi), %rax`) — on X86_64 any memory operand is modeled as a real,
  bounds-checked access.
- On ARM64, NEON/FP (AdvSIMD) is IN SCOPE (see the arm64 NEON subsection of
  the frame section): b/h/s/d/q/v registers and structure lists pass through,
  heap accesses are checked at exact widths, frame slots virtualize into the
  GPR slot webs. Rejected: SVE/SVE2 ("SVE is not yet supported (NEON/AdvSIMD
  only)"), the NEON forms that cannot be virtualized on a FRAME base (on a
  heap base they are supported at exact widths), NEON structure pre-index
  writeback (no such encoding in the modeled subset), a memory operand on any
  non-load/store mnemonic (prfm & co), and `long double`/vector signature
  types.
- On X86_64, `enter`/`enterq` is rejected (packed frame setup sarcasm does not model —
  see the frame section). FP/SIMD code is IN SCOPE (see the FP/SIMD subsection of the
  frame section); the only rejected instructions are ones whose memory-safety effects
  cannot be checked, each with a clean `sarcasm:` error. They fall into classes:
  * PRIVILEGED / SYSTEM STATE, whose effect on memory safety is unknowable:
    syscall/sysenter/sysexit/sysret, port I/O (the in/out family), hlt,
    wrmsr/rdmsr, mov to/from cr/dr, lgdt/lidt/lldt/ltr/lmsw, skinit. The
    unprivileged counterparts ARE supported at exact widths (sgdt/sidt=10,
    sldt/str/smsw=2, lss/lfs/lgs = destination size + 2-byte selector).
  * STATE THE FIL-C RUNTIME OWNS, which a silent write corrupts without a
    fault: FSGSBASE rdfsbase/rdgsbase/wrfsbase/wrgsbase (the fs/gs
    thread-pointer bases — a canonical wrfsbase replaces fs.base with no fault
    and TLS breaks, the rd forms leak the thread pointer), swapgs, WRITES INTO
    a segment register (a bad selector raises an unconverted hardware fault;
    the parser classifies %es/%cs/%ss/%ds/%fs/%gs as their own operand class,
    rc="seg", so the destination is visible), and PUSH/POP of a segment
    register (a push only READS the selector and a pop's selector load rides
    the stack push/pop machinery — the selector transfer is what the checker
    does not model). Plain selector READS pass through soundly, and
    segment-QUALIFIED memory operands (`%fs:0x28`) keep the symbolic-address
    rejection.
  * UNMODELABLE IMPLICIT MEMORY OR CONTROL FLOW: string instructions
    (movs/stos/lods/scas/cmps) and the rep/repe/repne/xacquire/xrelease
    prefixes (implicit rsi/rdi memory the checker cannot see),
    gather/scatter, maskmovdqu/maskmovq (implicit DS:rdi destination),
    umonitor (arms monitoring on a range whose extent cannot be
    bounds-checked), clzero/xlatb (implicit rax / rbx+al memory), lcall/ljmp
    (an invisible far-return-frame stack push), TSX xbegin/xend/xabort
    (transactional control flow and memory; on TSX-less hardware the
    encodings are #UD), the CET `notrack` prefix (changes indirect-branch
    tracking for the instruction that follows) and `setssbsy` (a shadow-stack
    write through the implicit SSP), SGX encls/enclu/enclv (implicit
    eax/rbx/rcx plus enclave-controlled memory).
  * IMPLICIT OPERANDS THE DEF/USE MODEL CANNOT EXPRESS, which regalloc could
    silently rename: the pcmpestri/pcmpistri family (the estri forms read
    rax/rdx as string lengths, the stri forms clobber rcx) and
    umwait/tpause (the implicit edx:eax TSC-deadline pair). The
    cpuid/rdtsc/rdtscp/xgetbv/rdpkru/wrpkru/monitor/mwait family IS modeled
    exactly and pinned (see the x86_64 backend notes).
  * STATE IMAGES OF UNTRACKED SIZE: the xsave/xrstor family (CPU-dependent
    image size — fxsave/fxrstor ARE supported, a fixed 512-byte image) and
    fsave/frstor/fstenv/fldenv (x87 environment/state saves).
  * FOOTPRINTS THAT ARE NOT ONE CHECKABLE ACCESS: AMX tile instructions (a
    strided, palette-configuration-dependent footprint, up to 16 rows x 64
    bytes) and the {k}-masked forms of anything outside the supported set
    (masked ALU memory sources, {%k0}, {k}-masked stack-frame accesses). The
    SUPPORTED masked forms — vector moves, truncating stores, expand/compress,
    the AVX2 vmaskmov/vpmaskmov forms — get the mask-aware check (see the
    transform section), and UNMASKED expand/compress stays supported at full
    vector width (no writemask = all lanes, a contiguous full-width access).
  * ENCODINGS WITH NO MODELED MEMORY FORM: `lock` outside the exactly-modeled
    memory-destination RMWs — classify allows it exactly on
    add/adc/and/or/sbb/sub/xor, inc/dec/neg/not, xadd, cmpxchg,
    cmpxchg8b/cmpxchg16b (the hardware locked set intersected with the modeled
    set); the locked instruction rides the normal write-classified checked
    path (including the not-readonly CanWrite test) and the renderer re-emits
    the prefix, while `lock` on a stack-frame access is rejected by the frame
    rewrite (which runs BEFORE classify) — the slot virtualizes/materializes,
    so accepting the prefix would silently elide it, a locked RMW degenerating
    into an unlocked register operation. Also xchg with a MEMORY operand (an
    implicitly LOCKED RMW that is not one of the exactly-modeled memory RMWs;
    register-to-register xchg IS modeled), movbe (its only baseline encodings
    are byte-swapping MEMORY moves), and `int N` for N≠3 (int3/`int $3` stay
    legal — like ud2 they only raise SIGTRAP/SIGILL, which Fil-C forbids
    installing handlers for, so a merely-trapping instruction is fine).
  * MEMORY FORMS WHOSE WIDTH OR ADDRESS CANNOT BE MODELED: unknown mnemonics
    with memory operands (the width is undeterminable and a guess could
    under-cover the access — enqcmd's m512 source, an unknown vector load — so
    unknown+mem REJECTS rather than guessing; unknown REGISTER-only forms pass
    through with the conservative first-register-def/rest-use model, which
    covers only genuinely-unknown register-only mnemonics, since the common
    compiler-output families have exact width/def-use entries in
    x86_64_fp.luau and the implicit-register class is pinned); and symbolic
    (RIP-relative/global) / absolute-address (moffs) operands — a bare
    (non-$-prefixed) AT&T symbol operand LOADS from the global and a bare AT&T
    numeric literal loads from that address (NOT an immediate move), while
    gas's Intel syntax gives a bare symbol the same absolute-moffs reading
    (proven against gas/objdump: `mov rsi, myglobal` emits an R_X86_64_32S
    absolute relocation — only a bare NUMBER is an immediate there) — so both
    reject as un-checkable memory accesses ("memory access with a symbolic
    address cannot be bounds-checked (global data access is not yet
    supported)" / "...with an absolute address..."). The rejection fires for
    every operand position (load, store, ALU source, push/pop), FP/vector
    forms included, and covers indirect-branch memory operands uniformly:
    `jmp *myglobal` / `call *myglobal` / `jmp *0x600000` branch THROUGH an
    absolute memory operand (an un-checkable read of the branch target, not a
    direct branch to it), and `je *myglobal` has no indirect encoding at all
    (rendering would silently emit the DIRECT branch), so the `*` marker
    overrides the code-target exemption and rejects with the same messages.
    Exempt: direct branches (call/jmp/jcc to symbols and numeric local
    labels), register-indirect branches (`jmp *%rdi`), register-based
    memory-indirect branches (`jmp *(%rax,%rcx,8)` — checked like any memory
    operand; memory-indirect CALLS are instead rejected), lea (address
    arithmetic, no dereference), $imm, and plain segment-register moves.
  * WIDTH LIES: an Intel PTR size annotation that CONTRADICTS the
    ISA-determined memory access width — rejected on the heap and stack paths
    alike (`PTR size annotation (N bytes) contradicts the memory access width
    (W bytes) of '<mnem>'`), since a lying annotation would under-size the
    bounds check or the materialized stack slot; the rule also fires on the
    GPR heap path (`mov WORD PTR [rdi], rax` stores 8 bytes, not 2) and on GPR
    accesses materialized into an FP-tainted frame cluster. The exceptions are
    the narrowing exemptions (movzx/movsx/movsxd; no-GPR-operand forms like
    push/pop/call/jmp and mem-only inc/dec/neg/not) and the size-driven widths
    (x87 memory forms, cvtsi2ss/sd integer source, narrowing converts,
    source-register-determined movnti) — see the x86_64_fp.luau module entry.
    An x87 PTR form the ISA does not have (`fst TBYTE PTR`) rejects with
    `<mnem> has no <N>-byte memory form` rather than rendering a nonexistent
    instruction;
  * FP/SIMD stack accesses needing more than 16-byte alignment (see the frame
    section).
  `long double`/vector signature types are rejected on both architectures;
  float/double signature types ARE supported on both (see above).

- On X86_64, an AT&T-style parens operand field in Intel-syntax input is
  rejected ("AT&T-style operand in Intel-syntax input (use [bracket] memory
  operands)") — see the `*_parse.luau` module entry for the rationale (such a
  field would otherwise re-render verbatim as AT&T memory syntax with Intel
  dest-first operand order and NO capability/bounds check).
- Intel-syntax lowercase `ptr` (e.g. `qword ptr [rbp-8]`) mis-parses as a
  symbolic displacement and rejects — uppercase `PTR` is required (a known
  parser gap; gcc emits uppercase, so real compiler output is unaffected).
- X86_64 output is always AT&T syntax, even when the input is Intel syntax.
## Floating-point signatures (arm64 and x86_64)
- Capability marker: BOTH codegen modules set `cgm.fpSignatures = true`, and
  the signature class check is arch-aware only in its error spelling:
  `sig.checkSupportedClasses(sd, where, { arch = target.arch })` accepts the
  float/double classes on both architectures and rejects `long double` and the
  vector classes (the error names the offending type class and the arch), at
  entry signatures (sarcasm.luau) and callsite annotations (the backends'
  `checkCallsiteSig`) alike.
- Fast paths (entry unpack, direct calls, indirect-call fast arm, returns): FP
  arguments and results PASS THROUGH the vector registers untouched — the transform
  simply skips FP-class args in the dense GPR marshalling (the yolo→dense
  mapping counts only GPR args, so GPR args are not shifted by FP args) and
  skips the integer retval move for FP returns. On arm64 the source program
  places FP args in v0..v7 per AAPCS and reads the FP result from v0 (s0/d0).
  On x86_64 they go in xmm0..xmm7 in declaration order among the FP args —
  INDEPENDENT of the dense GPR packing rdx,rcx,r8,r9 (a GPR arg's ordinal
  counts only the non-FP args before it; the entry unpack copies the internal
  dense fast-CC registers into the author-visible yolo sequence
  %rdi,%rsi,...), and an FP return rides in xmm0 with the `ret` path still
  clearing the %al exception flag (`movl $0, %eax`) even though %rax is not
  the result register (verified signatures mirror arm64's:
  `long(double,int,float,long)` reads the double in %xmm0, the int in %rdi,
  the float in %xmm1 and the long in %rsi).
- Generic/buffer paths (indirect-call generic arm, the weak callsite resolver
  thunk, the 2ET generic thunks): FP args are stored into the CC buffer at
  their declaration index — arm64's `cg.storeFpArg` emits `str sN/dN, [myth,
  #128+8i]` (a float writes the low 4 bytes of the 8-byte slot), x86_64's
  emits `movss/movsd %xmmN, 128+8i(%myth)` — each with a zero aux word at
  384+8i; the argument byte size counts every argument word. An FP return is
  loaded back from `myth+128` after the ret-size check (expected size stays 8):
  arm64 `cg.loadFpRet` (`ldr s0/d0`), x86_64 `movss/movsd 128(%myth), %xmm0`
  (the 2ET thunk additionally zeroes the aux word at `384(%rbx)` on the way
  out). The callsite thunk keeps FP args live in the vector file
  across its getter call (nothing in the thunk touches the v/xmm registers)
  and stores them into the buffer straight from there on the mismatch path.
- Frame interaction: FP values ride in vector registers even when the body
  never names one, so the vector-save reservation is FORCED whenever any
  signature in play (entry or callsite) has a float/double class — otherwise
  an injected runtime call's liveness-driven vector saves would not bracket
  the clobbered vector registers (gated on `cgm.fpSignatures`; both backends
  force it — see the frame section's reservation discussion).
- x86_64 specifics: call nodes carry `fpVecUses` so the width-aware backward
  liveness keeps an FP argument web live from its definition up to the call
  (see the frame section); and FP signatures push signature numbers past a
  32-bit immediate (eight doubles encode to 8552919316), so both
  signature-compare sites widen — the shared codegen hook
  (`cmpImmBranchWidened`) materializes the constant with `movq $imm64, %reg`
  (the movabs encoding) into a freshly allocated temp and compares registers,
  and the hand-written resolver glue does the same into the dead scratch
  `%r10` (arm64 needs none of this: its `cmp` immediate uses the existing
  chunked movz/sub-cmp/movk widening).

## Verification

Tests live under `filc/tests/` (yolo inputs named `sarcasm*`); from the repo
root, `filc/run-tests -f sarcasm` runs the whole suite and `-t <name>` runs one
test. Each input is assembled, linked with a Fil-C `main`, run, and its results
asserted; OOB and null-capability inputs must trap with the exact first-line
`filc safety error` message, and unsafe inputs must be rejected at compile
time. Extension-dependent tests carry manifest keys (`needsAVX512`,
`needsARMCrypto`, `needsLSE`, `needsFP16`) probed at startup and skip cleanly
when the hardware lacks the feature. Transform output is deterministic across
processes (see the determinism invariant in the transform section).

