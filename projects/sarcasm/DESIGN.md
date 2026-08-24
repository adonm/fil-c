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
  reference`).
- `*_isa.luau`     — instruction semantics: register defs/uses, control flow.
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
- any instruction naming a vector/floating-point (xmm-class: xmm/ymm/zmm, MMX mmN, or
  x87 stack st/st(N)) register, as an operand or a memory base/index, and any x87 FPU
  instruction at all (every x87 mnemonic begins with 'f'; ones naming no xmm-class
  register — `fldz`, `fnstsw %ax` — would otherwise slip past the register check) —
  sarcasm has no vector register file, so floating-point and vector code is out of
  scope and rejected rather than passed through to a cryptic assembler failure or a
  silent miscompile.

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

### ptrflow.luau — pointer-flow analysis
Seeds pointer-ness: function ptr args (from the signature), results of `;! load ptr`,
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
- non-ptr load/store through a ptr temp -> access-check(size, align) then the raw ld/st.
- calls (`;! sig` on the call insn) -> marshal args into the Fil-C CC registers, call the
  callsite thunk `pizlonatedFI<sig>_foo`, test the exception flag (propagate on throw),
  read results. Emits one weak/hidden callsite thunk per distinct called extern.
- loops (back-edges from the CFG) -> insert a pollcheck at the loop header.
- alloca annotations (`;! alloca size (x)` / `;! alloca result (x)`, or `;! alloca result
  size=N`) -> a GC allocation via filc_allocate, not real stack memory.
- fabricate prologue: SOV check + filc_frame push (prev,origin,roots) + callee-saved.
- roots: store each live-across-safepoint pointer's lower into a frame root slot;
  origin count field = number of root slots.

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
- Floating-point/vector type classes (float, double, long double) are rejected in ALL
  `;!` signatures — entry signatures and callsite annotations alike, on both
  architectures. sarcasm packs and unpacks dense GPRs only while the Fil-C ABI passes
  and returns FP/vector values in vector registers (which sarcasm rejects wholesale),
  so an FP-typed signature would silently miscompile the ABI at both ends. The error
  names the offending type.
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
- On X86_64, `enter`/`enterq` is rejected (packed frame setup sarcasm does not model —
  see the frame section), and floating-point/vector code is out of scope: any
  instruction naming an xmm-class register (xmm/ymm/zmm/mm/st; operand or memory
  base/index, AT&T or Intel syntax) or bearing an x87 FPU mnemonic (fld*, fst*, fnst*,
  fwait, fxsave, ...) is rejected rather than virtualized into garbage or passed
  through to a cryptic GNU-as failure. Floating-point signature types are rejected on
  both architectures (see Limitations).
- X86_64 output is always AT&T syntax, even when the input is Intel syntax.

## Verification
All testing is via the Fil-C test suite: `filc/run-tests -f sarcasm` from the repo root
runs the 104 `filc/tests/sarcasm-*` tests (manifest key `use-sarcasm: true`; `.s` inputs
assemble via minilute + sarcasm, `.c` files via clang). For each yolo input the suite
runs sarcasm, assembles + links with Fil-C `main`s, runs, and confirms correct results
+ that OOB/null-capability inputs trap. Most behavioral cases are exercised in both
AT&T and Intel variants (`-att` / `-int` pairs), and the suite additionally covers
auto-detection, spill-slot packing, pollchecks, GC stress, fixed-alloca region
redirects (rsp- and rbp-based, via `lea`/`mov` re-derivations), rbp/rsp slot aliasing,
frame-geometry stability under transient prologue-prefix push/pop pairs
(`sarcasm-frame-transient-pad`), the `movq %rbp,%rsp` epilogue-teardown path
(`sarcasm-frame-mov-rbp-teardown`), rbp-relative red-zone spills with the no-cleanup
leaf epilogue (`sarcasm-frame-rbp-redzone`), dynamic allocas torn down with the
`movq %rbp,%rsp; popq %rbp; ret` VLA epilogue (`sarcasm-alloca-mov-epilogue-att` /
`-int`), mid-function stack-pointer-movement rejections
(`sarcasm-reject-midframe-sp`, `sarcasm-reject-frame-misc`), frame-pointer-as-value
escape rejections (`sarcasm-reject-rbp-escape`), stack-register slot-store escape
rejections (`sarcasm-reject-slot-store-escape`), `enter` rejections
(`sarcasm-reject-enter`), vector/floating-point register rejections
(`sarcasm-reject-xmm`, including MMX `mmN`), x87 FPU rejections (`sarcasm-reject-x87`:
`%st(N)` operands in both syntaxes, no-operand `fldz`, `fldl` on a stack slot, and
`fnstsw %ax`), floating-point signature-type rejections (`sarcasm-reject-fp-sig`:
entry and callsite, argument and return position), unpaired-pop rejections
(`sarcasm-reject-unpaired-pop`), stack-register memory-index rejections
(`sarcasm-reject-sp-index`), and every compile-time rejection listed above that
applies on x86_64 (`filc/tests/sarcasm-reject-*`; the ARM64-only rejections go
untested there — every test is `only-on-platform: x86_64`).

The old in-tree `tests/` harness (host-lute `verify.sh`/`verify-x86.sh` via docker, and
the `roundtrip-test`/`detect-test`/`cleanup-test` Luau unit tests) has been removed;
its coverage now lives in `filc/tests/sarcasm-*`.
