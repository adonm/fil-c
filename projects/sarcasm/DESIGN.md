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
- `detect.luau`     — DONE + UNIT-TESTED. Auto-detects arm64 vs x86_64 (and att vs intel).
- `sig.luau`        — DONE. Signature encoding (verified against clang: 1066/2529/12769).
- `frame.luau`      — DONE. Frame preprocessing skeleton; per-arch policy plugs in.
- `lift.luau`       — DONE + UNIT-TESTED (tests/roundtrip-test.luau round-trips byte-for-byte).
- `ptrflow.luau`    — DONE. Pointer-flow analysis over the lifted IR.
- `transform.luau`  — DONE. The GIMSO transform (see below).
- `regalloc.luau`   — DONE + UNIT-TESTED. IRC: CFG, liveness, interference, coalesce, spill.
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
  callsite resolver thunk for called externals.

NOTE (x86_64 vs arm64 CC packing): the x86_64 fast-CC packing is DENSE — a scalar arg
consumes one register slot, a pointer arg two consecutive slots, packed from rdx across
rdx,rcx,r8,r9 (4 words max; clang passes anything wider on the stack) — matching
pizlonated clang output. arm64's `argIv/argLo` still uses the older FIXED-PAIR packing
(arg k always in x(2+2k)/x(3+2k)): the dense-packing fix was NOT applied to arm64
behavior, only mechanical signature updates. If arm64 clang packs mixed
scalar/pointer signatures densely (e.g. `int(long, void*)` putting arg1's intval in x3
rather than x4), arm64 has the same class of packing mismatch the x86_64 fix addressed
— a future arm64 session should check arm64 clang output and port the x86_64
dense-packing fix if needed.

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
and the spill-slot region. Any remaining stack access outside the analyzed frame
[0, frameSize) is rejected, as is taking the address of the stack frame at all (e.g.
`add xD, sp, #k` / `leaq 8(%rsp), %rax` — safety cannot be proven).
test-spasm/test2 have no frame; test3 has one; test3-spasm0 is spill-heavy. sarcasm
SYNTHESIZES its own frame regardless (for the SOV check + filc_frame push + callee-saved
for the new allocation), discarding the input's frame ops.

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
- Taking the address of the stack frame is rejected (cannot prove safety).
- Stack accesses outside the input frame — below it, above it, or stores into the
  caller's argument area — are rejected; on X86_64, indexed stack-relative access is
  not supported either.
- alloca requires the annotation pair: an `;! alloca result (x)` with no preceding
  `;! alloca size (x)`, a duplicate size for the same name, or a direct stack-relative
  access into an alloca region are all rejected.
- Memory operands on non-load/store instructions are rejected.
- X86_64 output is always AT&T syntax, even when the input is Intel syntax.

## Verification
- `tests/verify.sh` (ARM64) and `tests/verify-x86.sh` (X86_64) are the comprehensive
  suites, run from the repo root on the host (sarcasm via lute on the host; Fil-C
  clang/`as` via docker). For each yolo input they run sarcasm, check the inserted
  checks/calls structurally, assemble + link with Fil-C `main`s (see tests/), run, and
  confirm correct results + that OOB/null-capability inputs trap. The X86_64 suite
  exercises every behavioral case in BOTH AT&T and Intel syntax and additionally covers
  auto-detection and spill-slot packing. Both suites assert every compile-time
  rejection listed above; the X86_64 rejections are also covered by
  `filc/tests/sarcasm-reject-*` via `filc/run-tests`.
- Unit tests (run under lute, no docker needed): `tests/roundtrip-test.luau` (lift +
  identity-coloring reproduces the input byte-for-byte), `tests/detect-test.luau`
  (arch/syntax auto-detection), `tests/cleanup-test.luau` (spill reload elimination).
