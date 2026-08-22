# sarcasm — SAfe Runtime Capability-enforced Assembler

sarcasm is an assembler (written in Luau, run via `lute`) that takes ARM64 assembly
written to link with **Yolo-C** and rewrites it into **memory-safe** assembly that links
with **Fil-C**. It performs the GIMSO transformation on pointers, changes the pointer
representation to invisicaps, reallocates registers with Iterated Register Coalescing,
and emits code that follows the Fil-C ABI (calling convention, safepoints, stack-overflow
checks, GC roots). It only supports **ARM64** (aarch64) and rejects anything it cannot
prove safe rather than passing unsafe code through.

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

See `tests/test-spasm.s`, `tests/test2-spasm.s`, `tests/test3-spasm.s`, `tests/test3-spasm0.s`
for ARM64 examples, and `tests/test-spasm-x86.s` / `tests/test-spasm-x86-intel.s` for x86_64.

## Pipeline (`sarcasm/`)
- `parse.luau`   — ARM64 GNU/clang assembly parser (+ `;!` annotations).
- `arm64.luau`   — instruction semantics: register def/use, control flow, RMW.
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
- `glue.luau`    — getter, FO object, generic entrypoint thunk, origins, alias, and the
  **weak callsite resolver thunk** for called externals.
- `emit.luau`    — renders IR with the allocation; synthesizes prologue/epilogue.
- `sarcasm.luau`   — the driver (function splitting, orchestration, `as` invocation).

## Safety model for memory accesses
- **Frame accesses** (`sp`/`x29`-relative, within the input frame) are virtualized as
  register-allocated locals — no capability needed. Accesses outside the frame, or
  writes into the caller's argument area, are **rejected at compile time**. Taking the
  address of the stack frame is also rejected.
- **Heap accesses** are bounds-checked against a capability: the base's `lower` if the
  base is a pointer, else the index's `lower` (base wins if both are pointers), else a
  **null capability** — which traps at runtime (`cannot ... with null object`).
- **Pointer stores** additionally reject read-only/special objects, ensure the aux
  capability array exists, and run the FUGC store barrier when marking is active.

## Testing
`tests/verify.sh` (run from the repo root; uses `lute` on the host and `as`/clang via
docker) is the comprehensive suite: it compiles every yolo input with sarcasm, assembles
with **GNU `as`**, links with Fil-C `main`s, and checks results, out-of-bounds/null-cap
**traps**, the pointer-store capability round-trip, register-indexed access, the callsite
resolver (via a forced-resolution link), and the compile-time frame-bounds rejection.
Current status: 12/12. `tests/run-all.sh` is the original four-file subset (11/11).

`tests/roundtrip-test.luau` checks that lift + identity-coloring reproduces the input
byte-for-byte (validates the register-web machinery).

See `ABI-NOTES.md` for the decoded Fil-C ARM64 ABI and `DESIGN.md` for the architecture.
