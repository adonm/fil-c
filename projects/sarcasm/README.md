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
- on each call: the callee's signature, e.g. `bl foo ;! int(ptr, size_t)`;
- on stack allocations: `;! alloca size (x)` on the `sub sp,...` and `;! alloca result (x)`
  on the instruction that yields the pointer (dynamic), or `;! alloca result size=N` for a
  fixed-size buffer. These become GC allocations (`filc_allocate`), not real stack memory.

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
  **stores (with aux allocation + FUGC store barriers)**, offset- and
  **register-index-aware** access checks, **null-capability trapping** for non-pointer
  heap accesses, Fil-C calls (marshalling + exception propagation), pollchecks at loop
  headers, SOV check, frame push/pop, GC roots.
- `regalloc.luau` — Iterated Register Coalescing (Appel & George) over the GPR file.
- `emit.luau`    — renders IR with the allocation; synthesizes prologue/epilogue.
- `build.luau`   — constructors for synthesized IR nodes.
- `sarcasm.luau` — the driver (function splitting, orchestration, `as` invocation).

Per-architecture backends (`arm64_*` / `x86_64_*` pairs behind a common interface):
- `*_parse.luau`   — GNU/clang assembly parser (+ `;!` annotations); x86_64 handles both
  AT&T and Intel syntax.
- `*_isa.luau`     — instruction semantics: register def/use, control flow, RMW.
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
  `;! alloca` annotation. `enter` is rejected, and floating-point/vector code is out
  of scope — any instruction naming an xmm-class register (xmm/ymm/zmm, MMX mmN, or
  x87 st/st(N)) or bearing an x87 FPU mnemonic (fld*, fst*, fnst*, ...) is rejected,
  and floating-point types are rejected in `;!` signatures (sarcasm has no vector
  register file and marshals dense GPRs only).
- **Heap accesses** are bounds-checked against a capability: the base's `lower` if the
  base is a pointer, else the index's `lower` (base wins if both are pointers), else a
  **null capability** — which traps at runtime (`cannot ... with null object`).
- **Pointer stores** additionally reject read-only/special objects, ensure the aux
  capability array exists, and run the FUGC store barrier when marking is active.

## Testing
All testing is via the Fil-C test suite: the 104 `filc/tests/sarcasm-*` tests run with
`filc/run-tests -f sarcasm` from the repo root. Each test carries a manifest with
`use-sarcasm: true`; `.s` inputs are assembled via minilute + sarcasm
(`pizfix/bin/minilute projects/sarcasm/sarcasm-cli.luau`) and `.c` files via clang. The
suite compiles every yolo input with sarcasm, links with Fil-C `main`s, and checks
results, out-of-bounds/null-cap **traps**, the pointer-store capability round-trip,
register-indexed access, the callsite resolver, pollchecks, GC stress, and every
compile-time rejection that applies on x86_64 (`filc/tests/sarcasm-reject-*`). Most
behavioral cases are exercised in both AT&T and Intel variants (`-att` / `-int` test
pairs).

The old in-tree `tests/` harness (host-lute `verify.sh`/`verify-x86.sh` via docker,
plus the Luau unit tests) has been removed; its coverage now lives in
`filc/tests/sarcasm-*`.

See `ABI-NOTES.md` / `ABI-NOTES-x86.md` for the decoded Fil-C ABIs and `DESIGN.md` for
the architecture.
