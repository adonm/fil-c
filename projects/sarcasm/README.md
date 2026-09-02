# sarcasm — SAfe Runtime Capability-enforced Assembler

sarcasm is a pizlonating assembler: it takes x86_64 or ARM64 assembly
annotated with Fil-C directives and rewrites it into a memory-safe object
file that links with Fil-C — invisicap pointers, capability-checked
accesses, the Fil-C ABI with safepoints and GC roots. It is clang's
default assembler for `.s` files, so annotated assembly gets full Fil-C
memory safety out of the box; `-yolo-assembler` is the escape hatch back
to the plain integrated assembler.

## Usage

The Fil-C driver invokes `pizfix/bin/sarcasm [--x86_64|--arm64] [-g]
INPUT.s -o OUT.o` for every `.s` file; standalone, the same CLI runs from
a Fil-C checkout (`projects/sarcasm/sarcasm.sh` runs the checkout copy):

    pizfix/bin/sarcasm [-o OUT.o] [-S] [--x86_64|--arm64] [--intel|--at&t] [--as CMD] INPUT.s

- `-S` / `--no-assemble` dumps the rewritten assembly instead of running
  `as` (without `-o` it writes `INPUT.yolo.s`); `--as CMD` overrides that
  assembler.
- The target and syntax are auto-detected; `--x86_64`/`--arm64` select the
  backend and `--intel`/`--at&t` pin the x86_64 syntax (default AT&T).

Annotations are mandatory and validated, never silently ignored: a wrong
direction, width, or shape is a compile-time rejection.

### Annotation markers

| Marker | Architectures |
|---|---|
| `;!` | both |
| `#!` | x86_64 only |
| `//!` | arm64 only |

- The earliest marker on the line, outside a string literal, splits the
  line into code and annotation body; text inside `"..."` never forms an
  annotation (`\"` escapes are honored). Write `#!` on x86_64 and `//!` on
  arm64, and keep `;!` where one file must assemble on either target.
- On x86_64 a `#` not followed by `!` is a plain comment (a trailing `#`
  comment is stripped from the body); on arm64 `//` without `!` is a
  plain comment, `/* ... */` wins over `//!`, and the body is verbatim.
- Annotations attach to the instruction's or label's own line (a marker on
  an otherwise-empty line inside a function is a compile error) and are
  per-architecture: `#!` in an arm64 file and `//!` in an x86_64 file are
  not markers, so the text stays in the code part and fails to parse.

### Signature annotations

Each defined function label carries its Fil-C signature in C style:

    hash: ;! unsigned(ptr)

The signature controls the internal calling convention: non-FP arguments
pack densely into GPRs (x86_64 `%rdx,%rcx,%r8,%r9` — further argument
words travel on the stack and are marshalled both ways, so signatures
are not arity-limited there; arm64 packs into six registers and keeps
its 3-argument/6-word limit), `float`/`double` arguments pass in
`%xmm0`-`%xmm7` (arm64 `v0`-`v7`) in declaration order among the FP
arguments, and a `float`/`double` result returns in `%xmm0`/`v0`. `ptr`
is the pointer type; `long double` and vector types are rejected. On
x86_64, SysV stack arguments (the 7th and later integer-class
arguments, read at `8+8i(%rsp)` at entry — directly, or through a
register that parked the entry `%rsp` with `movq %rsp,%reg` /
`leaq 0(%rsp),%reg`) are redirected to argument slots fed from the
incoming words.

### Pointer annotations

| Annotation | Applies to |
|---|---|
| `;! load ptr` / `;! store ptr` | plain 8-byte GPR pointer load/store |
| `;! atomic load ptr` / `;! atomic store ptr` | atomic pointer load/store through the Fil-C runtime, exactly like C11 `_Atomic` (x86_64 plain `movq`; arm64 `ldr`/`ldur`/`ldar`/`ldapr` and `str`/`stur`/`stlr`, 64-bit, no writeback) |
| `;! atomic ptr` | pointer compare-exchange: x86_64 `cmpxchgq` with a memory destination (`lock` allowed and irrelevant), arm64 64-bit `cas` forms |
| `;! load store ptr` | x86_64 non-atomic pointer RMW over a memory slot: 8-byte add/adc/and/or/sbb/sub/xor, inc/dec/neg/not |
| `;! atomic load store ptr` | atomic pointer RMW: x86_64 memory-destination RMW (with `lock`, a runtime compare-exchange loop); arm64 64-bit LSE RMW (`ldadd`/`ldset`/`ldeor`/`ldclr`/`swp` and aliases) |

- The annotation must match the instruction exactly; cmpxchg8b/cmpxchg16b,
  casb/cash/casp, xadd, and any shape mismatch are compile-time
  rejections.
- For `;! atomic ptr` the expected value is the accumulator (x86_64) or
  the compare register (arm64); the old value returns with its
  capability, and flags are recomputed for a following branch/`setcc`.
- adc/sbb with `;! load store ptr` run without trapping, but the carry-in
  is clobbered: carry semantics are not preserved.

### Global variables (x86_64)

Same-file data becomes real Fil-C globals automatically, and extern globals
are one annotation away:

- Contiguous top-level data under `.section .rodata*`/`.data`/`.bss` (plus
  `.comm`/`.lcomm`) is collected into Fil-C data objects mirroring the
  compiler's per-global emission: bounds, alignment and write permission are
  checked exactly like compiled code, and a store to read-only data traps.
  Scalar initializers only (`.byte/.short/.long/.quad` numeric, `.float/
  .double`, `.ascii/.asciz`, `.zero/.space/.fill`, alignment padding);
  `.quad label` pointer initializers are a compile-time rejection. A
  `.comm name,size,align` becomes a strong writable definition (documented
  semantic change: commons lose cross-module merging).
- References to same-file data need no annotation: `leaq tab(%rip),%r` seeds
  a checked pointer (indexed table traffic just works), direct accesses like
  `movl g+4(%rip),%r` or `movdqa K256+512(%rip),%xmm7` run the ordinary
  capability check, and `#! load ptr` / `#! store ptr` maintain pointers
  through globals (pointer stores into writable globals register them with
  the GC).
- `#! global ptr` — on a rip-relative lea or any rip-relative memory access
  to an EXTERN global (defined in another module): materializes the flight
  pointer by calling the global's `pizlonated_<sym>` getter, then seeds
  (lea form) or checks-and-accesses (direct form). Extern globals without
  the annotation are compile-time rejections, as is any unresolvable
  rip-relative reference. arm64 keeps the historical rejections.

### Function references (x86_64)

`#! funcref` on a rip-relative lea to a FUNCTION symbol materializes the
function's flight pointer (its function-object capability), so the register
can be stored with `#! store ptr` into a function-pointer table that C later
calls indirectly — the OpenSSL poly1305_init shape:

    leaq poly1305_blocks(%rip),%r10 #! funcref
    ...
    movq %r10,0(%rdx) #! store ptr

- A same-file function (or alias entry) materializes its function object
  directly (`leaq pizlonatedFO_<fn>+16(%rip)` into both the intval and the
  capability lower — exactly the getter's output, a link-time constant into
  static ELF memory that needs no GC rooting).
- An extern function materializes through its cross-module getter
  (`pizlonated_<sym>`, the `#! global ptr` contract — an injected nounwind
  runtime call).
- The pointer flows through copies, address arithmetic and cmov selection
  chains (ptrflow's lockstep lowers: a cmov merging two function pointers
  gets a dynamic lower maintained by a conditional lower cmov with the same
  condition, emitted immediately after the instruction's own cmov).
- A data-object, body-local-label, or local-subroutine target is a clean
  compile-time rejection (a function needs a function object to point at).
  The stored capability passes the runtime FUNCTION-type check when C calls
  it indirectly. arm64 rejects `funcref` with a clean "not yet supported".

### `.section .init` / `.section .fini` content (x86_64)

At top level, inside `.section .init` (and `.section .fini` for symmetry), a
straight-line sequence of annotated DIRECT calls is accepted — the OpenSSL
x86_64cpuid shape:

    .section .init
    call OPENSSL_cpuid_setup #! void()

Each call must carry a `void()` signature annotation (the .init context runs
from `_init` as plain SysV code — there is no Fil-C argument state, so only
void() calls marshal soundly); labels, data directives, non-call instructions
and unannotated calls are clean rejections, as is a data-object or
local-subroutine target. The calls are emitted back into the same section as
Fil-C constructor calls through `filc_defer_or_run_global_ctor` (exactly what
filcc emits for a C constructor), preserving order — a same-file function's
function object is materialized directly, an extern function resolves through
its `pizlonated_<sym>` getter. Fil-C runs .init constructors, so the calls
run at process startup. arm64 rejects .init content with a clean "not yet
supported". `.section .init_array` pointer initializers stay rejected.

### Call annotations

- Every direct call carries the callee's signature — `bl foo //! int(ptr,
  size_t)`; an unannotated direct call is rejected. It is retargeted to
  the callee's pizlonated fast entrypoint; a cross-module call goes
  through a resolver that validates the target and marshals a
  mismatched signature via the generic buffer calling convention.
- A register-indirect call carries an inline signature — `call *%rax #! ptr(int)`
  (x86_64) or `blr x8 //! ptr(int)` (arm64). The target register must hold
  a known pointer value (a pointer argument, a `;! load ptr` result, or a
  pointer-returning call); the emitted code checks FUNCTION type,
  canonical entrypoint, and signature before calling.
- Rejected: unannotated register-indirect calls, memory-indirect calls
  (`call *mem` — load the pointer into a register first; arm64 `blr` is
  register-only), and indirect branches (`jmp *%rdi`, `br xN`) — an
  uncontrolled branch cannot be made memory-safe.

### Local subroutines (x86_64)

An unannotated `call` to a file-local subroutine works with NO signature —
the OpenSSL perlasm shape: a non-`.globl`, non-signature label (with or
without `.type name,@function`) whose region contains a `ret`, called from a
function body (or from another subroutine) with a custom caller/callee
register convention. sarcasm compiles each call as an unconditional jump to a
per-caller CLONE of the subroutine and each clone `ret` as a multi-way branch
back to the continuations, so lift/regalloc color caller+clones as one
function — argument/result registers, clobbered caller-saved registers, and
the caller's frame slots all follow the ordinary web rules. Details:

- A call target may also be a label in the MIDDLE of a subroutine's body (the
  clone is then [mid-label .. the region's ret(s)]).
- Nested non-recursive local calls work (each clone gets its own
  continuations); recursion — direct or mutual — is a compile-time error.
- The stack pointer is never moved (no hardware push), so a subroutine
  written against the return-address-compensated `N+8(%rsp)` convention (the
  rsaz/mont5/aesni-gcm subs) sees its rsp-relative displacements biased by -8:
  its `8(%rsp)` keys to the caller's slot 0, and `leaq 8(%rsp),%rdi` becomes
  `leaq 0(%rsp),%rdi`, which resolves into the caller's alloca region.
- `#! local` is accepted as an optional explicit marker on such calls
  (validated to resolve the same way; a mismatch is a compile error).
- The flags are clobbered across a local call (the ret dispatch compares),
  exactly like an ordinary call. A subroutine that falls off its end, a
  branch out of a subroutine that is not a mid-body tail join (below), and a
  `.globl` no-signature label are compile-time errors; on arm64 a discovered
  local subroutine is a clean "not yet supported" error.

### Cross-function jumps (x86_64)

Two OpenSSL perlasm shapes are supported (arm64 rejects them with a clean
"not yet supported" error):

- **Tail branches to function entries** (`jmp/jcc` to a sig-annotated
  same-file function or alias entry, or to an extern symbol carrying an
  inline signature, `jne asm_AES_cbc_encrypt #! void(...)`): rewritten into
  an ordinary annotated CALL (the full Fil-C marshalling of the current SysV
  arg-register webs — 7th+ arguments ride the jumper's own incoming
  stack-argument webs) plus a jump to the function's synthetic epilogue, at
  any frame depth. The callee's return value becomes the jumper's return
  value. An annotated jump whose target has no matching signature is a clear
  compile-time error; an unannotated jump to a non-local label keeps the
  plain tail-call rejection.
- **Mid-body shared-tail joins** (`jmp/jcc` into a label inside another
  same-file function's or subroutine's body): the region [label .. ret(s)]
  is cloned into the jumper (renamed labels, the region's rets returning
  from the jumper — no call, no return address, no clone bias), with local
  calls cloned transitively. A tail join from inside a local subroutine
  (mont5's `jmp .Lsqr4x_sub_entry`) clones the target tail into each caller
  with the jumping subroutine's clone context and continuations.

Alias entry labels (a label immediately adjacent to a sig-annotated function
label — asm_AES_encrypt:/AES_encrypt: or sha1's _shaext_shortcut:) share the
function's signature and body: jumps to them resolve to the function, and a
`.globl` alias gets its own getter/direct-call symbols so C callers link.

### Alloca annotations

Stack allocation becomes a GC allocation (`filc_allocate`), not stack
memory:

- `;! alloca size (x)` names the byte size and goes in EITHER of two
  places. On a value-producing (register-dest) instruction that dominates
  the result and precedes it in the body, so the captured size is defined
  wherever the allocation runs — the deferred form — that instruction
  stays and computes the size. On the %rsp-writing allocation instruction
  itself (`subq
  %rax,%rsp`; arm64 `sub sp,sp,xN`) — the allocation form — that
  instruction is dropped and replaced by the allocation, which consumes
  the size value it carried. `;! alloca result (x)` goes on the
  instruction whose destination becomes the allocation pointer (replaced
  by the GC allocation); its name must match a `;! alloca size (x)` name —
  mismatched names are a compile error — and in the allocation form it
  goes on the first instruction reading %rsp after the allocation
  instruction (capturing the address with `leaq disp(%rsp),%rd` or `movq
  %rsp,%rd` compiles identically). `;! alloca result size=N` fixes the
  size.
- Access the buffer through the allocation pointer: a direct
  stack-relative access into an alloca region is rejected. The pointer
  may escape and outlive the function.
- An alloca perturbs %rsp. While it is perturbed, frame accesses must be
  %rbp-relative (%rsp-relative accesses are rejected). %rsp recovery —
  `movq %rbp,%rsp`, `leaq N(%rbp),%rsp`, or `movq %reg,%rsp` from a
  prologue save — is silently ignored (freeing a GC object is a no-op) and
  revives the known %rsp even after the alloca perturbed it; an
  `addq $imm,%rsp` free is accepted only as a teardown provably reaching a
  `ret` through callee-saved pops and non-stack computation. These
  recovery and teardown forms are honored even in the same straight-line
  region as the `;! alloca result` annotation — only the allocation's own
  %rsp setup and its rsp-derived address chains are dropped — so a
  branch-free alloca function may recover %rsp and pop its epilogue
  immediately after the result. The prologue parks %rsp with `movq
  %rsp,%reg` into a callee-saved register — caller-saved saves are
  rejected, because a call clobbers them — and the save register must not
  be redefined or read before the recovery.

### Frames and the stack pointer

- The prologue is the leading run of callee-saved pushes, `movq %rsp,%rbp`,
  and `subq $imm,%rsp`; the frame geometry comes from that prefix.
  `enter` is rejected.
- %rsp writes are legal only (a) in the prologue (callee-saved pushes,
  `movq %rsp,%rbp`, `subq`/`addq $imm,%rsp`, and a `movq %rsp,%reg` save
  into a callee-saved register), (b) as the alloca allocation, (c) as %rsp
  recovery (`movq %rbp,%rsp`, `leaq N(%rbp),%rsp` with the frame pointer
  established, or `movq %reg,%rsp` from an unredefined prologue save), (d)
  as a mid-function `addq $imm,%rsp` free that provably reaches a `ret`,
  and (e) as epilogue teardown — everything else is a compile error.
- Frame slots (x86_64 spellings; sp/x29 analogous on arm64) are
  virtualized into register-allocated locals with compile-time bounds —
  no capability needed; the 128-byte SysV red zone is legal. Accesses
  outside the frame, caller-argument-area writes, and taking the frame's
  address are rejected.
- A body that can fall off its end without `ret`, and a branch to the
  function's own entry label, are rejected.

## Build & install flow

sarcasm is written in Luau in this directory
(`projects/sarcasm/sarcasm/`). The Fil-C build never runs it from the
checkout: `./build_sarcasm.sh` (run from the repo root) installs the
modules into `pizfix` as a minilute entry script, `pizfix/bin/sarcasm`,
which is what clang and the test suite actually execute. Re-run it after
editing the sources; un-installed edits have no effect on clang or test
runs.

## Safety model

- Every memory access is capability-checked: bounds and alignment against
  the pointer's capability, and write permission on every heap write
  (read-only objects trap). A heap access whose base has no capability —
  an integer address — traps at runtime with a null capability.
- The stack frame is virtualized (compile-time bounds, red zone legal),
  and allocas become garbage-collected allocations.
- Pointer loads, stores, atomics, and RMWs maintain the capability through
  memory (including the aux capability array and the GC store barrier), so
  pointers round-trip and stay dereferenceable.
- A defined set of unsafe instruction classes is rejected at compile time:
  state-corrupting and privileged forms (segment-selector and FS/GS-base
  writes, `swapgs`, TSX, `syscall`/port I/O/`hlt`, MSRs, descriptor-table
  loads), anything whose memory semantics cannot be modeled (string/`rep`
  instructions, `xchg` with memory, gather/scatter, AMX tiles, unknown
  mnemonics with memory operands), symbolic and absolute addresses,
  indirect branches, memory-indirect calls, and `lock` outside the modeled
  memory-destination RMWs.
- Unknown register-only forms pass through with conservative def/use
  modeling; FP/SIMD/NEON registers pass through as written (memory
  operands checked at the exact width); non-pointer atomics (x86_64
  `lock`ed RMWs, arm64 LSE and load/store-exclusive families) are single
  checked accesses.
- Exceptions do not unwind through x86_64 sarcasm frames (a C++ throw in
  a callee terminates the process); arm64 frames propagate.

DESIGN.md has the full model, including per-access check sequences and the
complete reject lists.

## Testing

Tests live in `filc/tests/` in directories named `sarcasm*`; run
`filc/run-tests -f sarcasm` from the repo root (`-t <name>` for one). The
suite asserts results, traps, and compile rejections; extension-dependent
tests skip cleanly on unsupported hardware.

## More documentation

`DESIGN.md` has the design and full semantics; `ABI-NOTES.md` and
`ABI-NOTES-x86.md` decode the Fil-C ABIs sarcasm emits.
