# sarcasm design & build status

SAfe Runtime Capability-enforced Assembler: an ARM64 assembler (in Luau, run via `lute`) that rewrites
Yolo-C assembly into memory-safe, Fil-C-linkable assembly, then invokes `as`.

## Pipeline
```
parse.luau  ->  split into functions  ->  frame analysis  ->  lift to IR (register webs)
   ->  pointer-flow  ->  GIMSO transform (intval/lower, ptr ld/st, calls, pollchecks, SOV)
   ->  IRC regalloc (regalloc.luau)  ->  emit body + glue (glue.luau)  ->  write .yolo.s  ->  as -o .o
```

## Module status
- `parse.luau`      — DONE. Full ARM64 operand parser + `;!` annotations.
- `sig.luau`        — DONE. Signature encoding (verified against clang: 1066/2529/12769).
- `glue.luau`       — DONE + VALIDATED. getter/FO/2ET/origins/access-origin/alias link & run.
- `regalloc.luau`   — DONE + UNIT-TESTED. IRC: CFG, liveness, interference, coalesce, spill.
- `reference/hash.yolo.s` — VALIDATED golden output for tests/test-spasm.s (links, runs, traps OOB).
- `ABI-NOTES.md`    — complete ABI reference.

## Remaining modules (this is the continuation work)

### lift.luau — asm -> IR over register "webs"
Faithful reallocation of the whole GPR file requires turning physical-register live
ranges into virtual temps. Approach (no full SSA needed):
1. Build CFG (reuse regalloc.buildCFG shape).
2. Reaching-definitions dataflow per physical GPR.
3. Union-find "webs": union each use with every def of the same reg that reaches it.
   Entry pseudo-defs for CC input regs (x0=myth, x2/x3=arg0 iv/lower, x4/x5=arg1, ...).
   Each web = one temp id.
4. Emit copies at CC boundaries so precolored physical webs stay tiny:
   - entry: `vMyth = x0`, `vArg0iv = x2`, `vArg0lo = x3`, ...
   - call:  move args into x2/x3.. (precolored), `bl`, move x1/x2 out to virtuals.
   - return: move ret virtual into x1 (+ x2 lower if ptr), flags in w0.
5. Each IR insn keeps its mnemonic + operands, with reg operands replaced by
   `{temp=id, width=..}` refs so the emitter can substitute the assigned color.
   Spill-slot ld/st (`[sp,#k]`/`[x29,#-k]` within frame) become copies to/from a
   spill-slot temp (per the plan: "spill slots as locals").

### frame.luau — prologue/epilogue recognition
Match idiomatic prologue: `stp x29,x30,[sp,#-N]!` or `sub sp,sp,#N` + `stp` saves +
`mov x29,sp`/`add x29,sp,#k`; symmetric epilogue. Record N, callee-saved set, spill-slot
region. Reject non-idiomatic frames and any address-of-stack escape (e.g. `add xD, sp, #k`
whose result flows to a store/call). test-spasm/test2 have no frame; test3 has one;
test3-spasm0 is spill-heavy. sarcasm SYNTHESIZES its own frame regardless (for SOV check +
filc_frame push + callee-saved for the new allocation), discarding the input's frame ops.

### ptrflow.luau — pointer-flow analysis
Seed pointer-ness: function ptr args (from signature), results of `;! load ptr`, call
results whose return type is ptr. Forward-propagate through `mov`/`add imm`/`sub imm`/
copies (GEP keeps lower, changes intval). A temp marked ptr gets a paired `lower` temp.
`ptrtoint` (ptr used as int) reads only intval; `inttoptr` w/o known origin -> null lower.

### gimso.luau — the transform (templates in ABI-NOTES.md, validated in hash.yolo.s)
- Represent each in-flight ptr temp as (intval temp, lower temp).
- `;! load ptr`  -> access-check(8, align 8) + non-atomic invisicap load sequence
  (offset = iv-lower; aux=[lower-8]&mask; auxentry=[aux+off]; box bit handling).
- `;! store ptr` -> access-check + aux-ensure (filc_object_ensure_aux_ptr_outline) +
  store barrier (filc_current_marking_state / filc_store_barrier_for_lower_slow) + stores.
- non-ptr load/store through a ptr temp -> access-check(size, align) then the raw ld/st.
- calls (`bl foo ;! sig`) -> marshal args to x2/x3.., `bl pizlonatedFI<sig>_foo`,
  test w0 bit0 (exception -> propagate), read results. Emit a weak/hidden callsite
  thunk `pizlonatedFI<sig>_foo` per distinct called extern (template from test3-filc.s).
- loops (back-edges from CFG) -> insert pollcheck at back edge / header.
- fabricate prologue: SOV check + filc_frame push (prev,origin,roots) + callee-saved.
- roots: store each live-across-safepoint pointer's lower into a frame root slot;
  origin count field = number of root slots.

### emit.luau + sarcasm.luau (driver)
- emit: render IR with colors; materialize spill slots; emit prologue/epilogue with the
  exact callee-saved set actually colored; append glue via glue.luau. Handle IRC actual
  spills by rewriting (reload before use / store after def into a fresh slot) and re-color.
- driver: `as`-like args. `-o x.o` default -> write `x.yolo.s` (temp, same dir) then run
  `as`(configurable, default `as`) to make `x.o`. `--no-assemble`/`-S` -> emit assembly;
  if no `-o`, write `<input>.yolo.s`.

## Verification
For each of test-spasm/test2/test3/test3-spasm0: run sarcasm, assemble+link with a Fil-C
`main` (see tests/), run, and confirm correct results + that OOB inputs trap.
