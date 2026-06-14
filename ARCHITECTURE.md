# Fil-C Architecture Guide

## Overview

Fil-C is a memory-safe implementation of C and C++ that achieves full safety through a combination of **invisible capabilities (InvisiCap)** and **concurrent garbage collection (FUGC)**. Created by Filip Pizlo at Epic Games, Fil-C provides full C17/C++20 compatibility while catching all memory safety errors as deterministic panics—no `unsafe` keyword, no escape hatches.

**The GIMSO Principle**: "Garbage In, Memory Safety Out"—any program accepted by the Fil-C compiler cannot escape the Fil-C type system. At worst, execution is thwarted at runtime with a descriptive panic.

### Key Characteristics

| Property | Details |
|----------|---------|
| **Memory model** | InvisiCap: 64-bit pointers in C address space + invisible capability in an auxiliary allocation |
| **Pointer in registers** | Two registers: one for the pointer, one for the capability (lower bound) |
| **GC** | FUGC: parallel, concurrent, on-the-fly, accurate, non-moving |
| **Platform** | Linux/x86_64 only (ARM and other OSes feasible but not current focus) |
| **Performance** | 1.5x–4x slower than native C (actively being optimized) |
| **Compiler** | Based on Clang 20.1.8 with the FilPizlonator LLVM pass |

### Two-Libc Sandwich Architecture

```
 ┌────────────────────────────────────────────────────────┐
 │                   User Program                         │
 │  (compiled normally, uses pointers like normal C)       │
 ├────────────────────────────────────────────────────────┤
 │              USER libc  (heavily modified)             │
 │  musl: projects/usermusl/   glibc: projects/user-glibc/│
 │  ┌──────────────────────────────────────────────────┐  │
 │  │  Provides standard libc API to user programs.    │  │
 │  │  Heavily pizlonated: syscall wrappers, malloc,   │  │
 │  │  etc. all go through Fil-C runtime safety checks.│  │
 │  └──────────────────────────────────────────────────┘  │
 ├────────────────────────────────────────────────────────┤
 │              Fil-C Runtime (libpas)                     │
 │  libpas/src/libpas/filc_runtime.{h,c}                  │
 │  ┌──────────────────────────────────────────────────┐  │
 │  │  InvisiCap management, capability creation/check  │  │
 │  │  FUGC garbage collector, safepointing, pollchecks │  │
 │  │  Thread/signal/syscall safety infrastructure      │  │
 │  └──────────────────────────────────────────────────┘  │
 ├────────────────────────────────────────────────────────┤
 │              YOLO libc  (minimally modified)           │
 │  musl: projects/yolomusl/   glibc: projects/yolo-glibc/│
 │  ┌──────────────────────────────────────────────────┐  │
 │  │  Low-level libc primitives for the runtime.       │  │
 │  │  Provides syscall wrappers, threading primitives, │  │
 │  │  memory layout, etc. Called only by the runtime.  │  │
 │  └──────────────────────────────────────────────────┘  │
 └────────────────────────────────────────────────────────┘
```

The yolo libc is the only part of the system that is NOT memory-safe (it is the "yolo" layer). It provides low-level primitives that the Fil-C runtime uses to implement the safety layer. The user libc, which applications link against, is heavily pizlonated and memory-safe. The Fil-C runtime sits between them, mediating all syscalls and enforcing capability checks.

---

## Build System Architecture

### Build Dependency Graph

The build follows a strict dependency order. Here is the core dependency chain:

```
build_base.sh                    LLVM/Clang compiler (the Fil-C compiler itself)
    │
    ├── build_yolomusl.sh        Yolo musl libc (or build_yolo_glibc.sh)
    │
    ├── build_runtime.sh         Fil-C runtime (libpas)
    │       │
    │       ├── build_usermusl.sh    User musl libc (or build_user_glibc.sh)
    │       │
    │       ├── build_cxx.sh         C++ standard library (libc++/libc++abi)
    │       │
    │       └── build_all_fast.sh    Quick build: base + yolo + runtime + user + cxx
    │               │
    │               └── build_all.sh     Full build: above + all ported apps
    │
    └── build_and_test_base.sh   Builds base then runs tests
```

**Essential components** (must all be present):
- `build_base.sh` — LLVM/Clang compiler with FilPizlonator pass
- `build_runtime.sh` — libpas runtime library
- `build_yolomusl.sh` — yolo musl libc
- `build_usermusl.sh` — user musl libc
- `build_cxx.sh` — C++ standard library

**Alternative libc variants**:
- `build_yolo_glibc.sh` / `build_user_glibc.sh` — glibc instead of musl
- `build_all_fast_glibc.sh` / `build_all_glibc.sh` — glibc builds

**Ported application builds** (`build_*.sh`): Each script builds a specific ported application (curl, openssl, openssh, sqlite, python, vim, etc.) and installs it into the `pizfix/` staging environment.

### Key Directories

| Directory | Purpose |
|-----------|---------|
| `build/` | Compiled Fil-C compiler (clang, clang++, lld) and FilC runtime libraries |
| `pizfix/` | Staging environment for compiled (pizlonated) programs |
| `pizlix/` | Full Linux distribution based on Fil-C |
| `optfil/` | `/opt/fil` distribution build |
| `llvm/` | LLVM source tree with the FilPizlonator pass |
| `libpas/` | Fil-C runtime library (FUGC, capabilities, threading) |
| `filc/` | Fil-C specific code and tests |
| `filc/include/` | Main header (`stdfil.h`) |
| `filc/src/` | Runtime components written IN Fil-C |
| `filc/main/` | Program entry point |
| `filc/tests/` | Test suite |
| `projects/` | Ported applications and libraries |
| `projects/yolomusl/` | Yolo (minimally modified) musl libc |
| `projects/usermusl/` | User (heavily pizlonated) musl libc |
| `projects/yolo-glibc-2.40/` | Yolo glibc libc |
| `projects/user-glibc-2.40/` | User glibc libc |

### Build Environment Variables

| Variable | Effect |
|----------|--------|
| `FUGC_STW=1` | Force stop-the-world GC for debugging |
| `FUGC_SCRIBBLE=1` | Enable memory scribbling on free for verification |
| `FUGC_VERIFY=1` | Enable GC verification |
| `FUGC_MIN_THRESHOLD=0` | Zero GC threshold for stress testing |
| `FILC_DUMP_SETUP=1` | Dump environment variable settings at startup |

---

## Compiler Pipeline

### Overview

The Fil-C compiler is Clang 20.1.8 with a custom LLVM module pass: `FilPizlonator.cpp`. After Clang produces LLVM IR, the FilPizlonator pass transforms it into GIMSO-safe IR before code generation.

```
C/C++ Source
    │
    ▼
Clang Frontend (produces normal LLVM IR)
    │
    ▼
LLVM Optimization Pipeline
    │
    ▼
FilPizlonatorPass (module-level pass)    ← THE KEY TRANSFORMATION
    │
    ▼
LLVM Backend (generates x86_64 code)
```

### What the FilPizlonator Does

The FilPizlonator (`llvm/lib/Transforms/Instrumentation/FilPizlonator.cpp`, ~12,500 lines) is the heart of Fil-C. It transforms standard LLVM IR into instrumented IR that carries invisible capabilities. Key transformations:

#### 1. Pointer Splitting

Every pointer value in the IR is split into a **flight pointer**—a two-register structure:

```c
// Runtime representation (filc_runtime.h:347)
struct filc_ptr {
    void* ptr;    // The raw pointer (what C code sees)
    void* lower;  // The capability (lower bound pointer)
};
```

In registers: `{ptr, lower}` → two x86_64 registers.
In memory: only the `ptr` field is stored. The `lower` (capability) is stored in the **auxiliary allocation** for the containing object.

#### 2. Bounds Check Instrumentation

Every memory access (load/store) is instrumented with bounds checks. For a non-pointer access to `ptr[N]`:

```
Check: ptr + N >= lower  (implicit: ptr carries lower)
Check: ptr + N + size <= upper  (upper = *(Object*)lower[-16])
```

The `filc_object` header is stored **at a negative offset from lower**:

```c
struct filc_object {         // 16 bytes at [lower - 16]
    void* upper;             // Upper bound of the allocation
    uintptr_t aux;           // Flags + aux pointer for pointer capabilities
};
```

For the compiler, accessing `upper` means loading from `lower - 16 + 0` (offset 0 within the object struct). This is what the checks in FilPizlonator reference as `KnownLowerBound` (known to be valid), `LowerBound` (the actual lower check), and `UpperBound` (the upper check).

#### 3. Calling Convention Changes

Standard C calling conventions pass a single 64-bit value for a pointer. Fil-C replaces this with a **two-register convention**:

- Each pointer argument becomes **two function arguments**: `ptr` and `lower`
- Each pointer return becomes **two return values** (or a struct return)
- The type `filc_ptr` (`{ i8*, i8* }`) is the universal flight pointer IR type

The compiler generates "pizlonated function types" like:
```c
// Internal calling convention
typedef filc_ptr (*pizlonated_function)(filc_thread* my_thread,
                                         void* callee_lower,
                                         size_t argument_size);
```

Functions can also be called via a **generic entrypoint** for cases where the signature isn't known at compile time (function pointers, dynamic linking).

#### 4. Allocation Lowering

The FilPizlonator lowers `malloc`, `alloca`, and global variables:
- **Heap allocations** → calls to `filc_runtime` allocation functions (which set up the `filc_object` header and capability)
- **Stack allocations (alloca)** → similarly instrumented with capabilities
- **Global variables** → initialized with proper capabilities and auxiliary allocations

#### 5. Safepoint Pollchecks

Pollchecks are injected in every loop and after function calls (bounded by `FILC_MAX_BYTES_BETWEEN_POLLCHECKS` = 10,000 bytes of code). The fast path is just a load-and-branch:
```c
if (thread->state & THREAD_STATE_CHECK_REQUESTED)
    call pollcheck_slow_path();
```

This enables the GC to request work from threads without stopping them.

#### 6. Store Barriers for GC

When a pointer is stored into a heap object, the FilPizlonator emits a **store barrier** (Dijkstra barrier). The barrier ensures that if the GC is running, the newly-stored-to object gets marked. The fast path is:

```c
// Fast path: if not in GC marking phase, just store
lower_or_box->encoded_value = (uintptr_t)target_lower;

// Slow path (only when GC is marking):
// CAS-based barrier that marks the target object
```

#### 7. Atomic Pointer Support

Atomic pointer operations get special treatment. The auxiliary allocation stores an **atomic box** (a 16-byte atomic `{ptr, lower}` tuple) for atomically-accessed pointers. The FilPizlonator emits the correct atomic instructions for these cases.

### Compiler Use

```bash
# Must compile with -g for meaningful error messages
# Must also use -O with -g (compiler crashes without optimization when -g is present)
build/bin/clang  -o program program.c -g -O
build/bin/clang++ -o program program.cpp -g -O -std=c++20
```

---

## Runtime System

### libpas Architecture

The Fil-C runtime lives in `libpas/src/libpas/`. Core files:

| File | Purpose |
|------|---------|
| `filc_runtime.h` | Runtime type definitions (filc_object, filc_ptr, filc_thread, etc.) |
| `filc_runtime.c` | Core runtime implementation: allocation, capabilities, threading, signals, syscalls |
| `filc_runtime_inlines.h` | Inline helpers for capability checking |
| `fugc.c` | Fil's Unbelievable Garbage Collector |
| `filc_start_program.c` | Program startup trampoline |
| `verse_heap.h` | Heap configuration (used by FUGC for fast sweeping) |

### The filc_object

Every allocation in Fil-C has a hidden 16-byte `filc_object` header stored at a **negative offset** from the allocation base:

```
Memory layout of a Fil-C heap allocation:
┌─────────────────────────────────────┐
│  filc_object header (16 bytes)      │ ← hidden, at `lower - 16`
│  - upper: void*  (upper bound)      │
│  - aux: uintptr_t (flags + aux_fn)  │
├─────────────────────────────────────┤
│  Auxiliary allocation (optional)    │ ← only if object contains ptr fields
│  - capabilities for stored pointers │
├─────────────────────────────────────┤
│  User data                         │ ← `lower` points here
│  (the C-visible allocation)         │
└─────────────────────────────────────┘
```

The `aux` field packs two things:
- **Aux ptr** (48 bits): pointer to the auxiliary allocation containing capabilities for this object's pointer fields
- **Flags** (16 bits): `FREE`, `GLOBAL`, `READONLY`, `MMAP`, special type, alignment

### Capability Representation

A capability is represented as the `lower` pointer itself. The runtime knows:
- `lower` = base of the allocation (what the capability was created for)
- `upper` = `((filc_object*)(lower))[-1].upper` (read from the object header)
- `aux` = the auxiliary allocation (from the object header)

**Capability checking** is done inline by code generated by FilPizlonator:

```c
// Check for an access to ptr of size size:
// 1. ptr >= lower (always true if ptr is derived from lower)
// 2. ptr + size <= upper (loaded from object header)
// 3. check alignment matches
// 4. For pointer accesses: locate and access the capability in aux
```

### Memory Allocation Flow

1. **`zgc_alloc(count)`** → `malloc` → `zgc_aligned_alloc(16, count)`
2. Runtime allocates from libpas verse heap with space for `filc_object` header + alignment
3. Sets up `filc_object` with correct `upper` and zero `aux`
4. If the type has pointer fields, a call to `filc_object_ensure_aux` creates the auxiliary allocation
5. For pointer fields, the aux stores `filc_lower_or_box` entries (one per pointer field)

**Freeing** an object:
1. Sets `FILC_OBJECT_FLAG_FREE` in the object's flags
2. Sets `upper = lower` (bounds become zero, all accesses trap)
3. GC redirection: on next cycle, all pointers to this object get their `lower` redirected to the **free singleton**

### FUGC: Fil's Unbelievable Garbage Collector

FUGC is a **parallel, concurrent, on-the-fly, grey-stack Dijkstra, accurate, non-moving** collector.

**Key design decisions**:
- **No load barrier**: Loading a pointer from the heap needs no instrumentation
- **Dijkstra store barrier**: Storing a pointer into the heap during GC marking phase marks the target
- **Grey-stack fixpoint**: After initial marking, threads are soft-handshaked to rescan stacks until no new work is found
- **Advancing wavefront**: Newly allocated objects during GC are pre-marked (black allocation), so mutators don't add work
- **Non-moving**: Objects stay where they are. Only pointers to freed objects get redirected to the free singleton.

**GC Cycle** (simplified):

```
1. Wait for trigger (memory threshold exceeded)
2. Turn on store barrier → soft handshake all threads (no-op)
3. Turn on black allocation → soft handshake (reset thread-local caches)
4. Mark global roots
5. Soft handshake → scan all thread stacks + donate thread mark stacks
   ┌─ If mark stacks empty → go to 7
   └─ Otherwise → go to 6
6. Concurrent tracing: mark outgoing refs from each marked object
   → loop back to 5 (the fixpoint)
7. Turn off store barrier → soft handshake (reset caches)
8. Sweep: bitvector SIMD-based sweep (very fast, <5% of GC time)
9. Done → wait for next trigger
```

**Safepointing** makes all this possible:
- Pollchecks: compiler inserts checks in loops and after calls
- Soft handshakes: GC requests threads to run callbacks (stack scan, cache reset)
- Enter/exit: threads can exit (block in syscalls) without pollchecks; GC handles exited threads

**GC-related user-facing API** (from `stdfil.h`):
```c
void zgc_request_and_wait(void);      // Force a full GC cycle
zgc_cycle_number zgc_request_fresh(void);  // Request a fresh cycle
void zgc_wait(zgc_cycle_number cycle);     // Wait for a specific cycle
void zscavenge_synchronously(void);   // Decommit freed pages to OS
```

---

## Two-Libc Design

### Why Two Libcs?

Fil-C uses two separate libc implementations because of a fundamental constraint: **Fil-C compiled code cannot link with regular (yolo) C code** due to incompatible pointer representations (the "ABI slice problem").

- **Yolo libc**: Normal C ABI. Used by the Fil-C runtime itself, which is compiled with a regular C compiler. The yolo libc provides raw syscall wrappers, threading primitives, and memory layout.
- **User libc**: Compiled with Fil-C itself. This is what user programs link against. It's heavily modified to go through Fil-C's safety checks on every syscall.

### Layer Responsibilities

**Yolo libc** (`projects/yolomusl/` or `projects/yolo-glibc-2.40/`):
- Provides the "unsafe layer" that the runtime builds upon
- Raw syscall wrappers (`__NR_*` syscalls)
- Thread primitives (clone, futex)
- Memory mapping primitives (mmap, munmap, mprotect)
- Signal infrastructure
- Low-level startup (ELF loading, TLS setup)
- This is the ONLY code in the system that is not memory-safe

**User libc** (`projects/usermusl/` or `projects/user-glibc-2.40/`):
- Compiled with the Fil-C compiler (fully pizlonated)
- `malloc`/`free`/`realloc` → forwards to `zgc_alloc`/`zgc_free`/`zgc_realloc` in the runtime
- `printf`/`scanf` → safe implementations that check buffer bounds
- `read`/`write`/`open`/etc. → syscall wrappers that validate buffer capabilities before passing to kernel
- `pthread_create`, signal handlers, `mmap`, `longjmp`/`setjmp` — all memory-safe

### musl vs glibc

Both musl and glibc are supported as the libc base:

| Distribution | Yolo libc | User libc | Build command |
|---|---|---|---|
| Classic (musl) | `projects/yolomusl/` | `projects/usermusl/` | `./build_all.sh` |
| /opt/fil (glibc) | `projects/yolo-glibc-2.40/` | `projects/user-glibc-2.40/` | `./build_all_glibc.sh` |

The binary releases come with musl as the default libc.

---

## Testing Infrastructure

### Test Structure

Tests live in `filc/tests/<testname>/` directories. Each test directory contains:

```
filc/tests/zreallocthread/
├── manifest        # YAML file defining expected behavior
└── zreallocthread.c  # The test source
```

### Manifest Format

The `manifest` is a YAML file that tells the test runner what to expect:

```yaml
# Test that should succeed and exit with code 0
return:
  success

# Test that should fail (panic)
return:
  failure

# Test with specific expected output
return:
  success
output-includes:
  - "expected string in stdout/stderr"

# Test that should panic with specific message
return:
  failure
output-includes:
  - "filc safety error"
  - "cannot read pointer with null object"
output-excludes:
  - "some string that must NOT appear"
```

Common manifest fields:
- `return: success` or `return: failure` — expected exit behavior
- `output-includes:` — list of strings that must appear in output
- `output-excludes:` — list of strings that must NOT appear

### Running Tests

```bash
# Run all tests
filc/run-tests

# Run tests matching a regex
filc/run-tests --filter regex

# Run a specific test
filc/run-tests --test testname

# Compile only, don't run
filc/run-tests --no-run

# Verbose output
filc/run-tests --verbose
```

### Sub-run Configurations

Test runner generates multiple build configurations for each test, output to `filc/test-output/<testname>/`:

| Configuration | Environment | Purpose |
|---|---|---|
| **default** | (none) | Standard concurrent GC |
| **scribble** | `FUGC_SCRIBBLE=1 FUGC_VERIFY=1` | Memory corruption debugging |
| **STW** | `FUGC_STW=1` | Stop-the-world GC (for triaging concurrency bugs) |
| **release** | Optimization flags | Production-like settings |

Generated scripts for each test:
- `compile.sh` — Build the test
- `justRun.sh` — Run with debug runtime
- `subRun*.sh` — Run with different GC configurations

### Writing a New Test

1. Create `filc/tests/mytest/mytest.c` with your test code
2. Create `filc/tests/mytest/manifest` describing expected behavior
3. Use `zprintf()` (not `printf()`!) for unbuffered output in tests
4. Run `filc/run-tests --test mytest`

Example test:
```c
// filc/tests/myalloc/myalloc.c
#include <stdfil.h>
#include <stdlib.h>
int main() {
    int* ptr = (int*)zgc_alloc(sizeof(int));
    *ptr = 42;
    ZASSERT(*ptr == 42);
    zprintf("ok\n");
    return 0;
}
```
```yaml
# filc/tests/myalloc/manifest
return:
  success
output-includes:
  - "ok"
```

---

## Contributing

### Setting Up a Dev Environment

```bash
# Install mise, then:
mise trust               # Trust this project's config
mise install             # Install cmake, ninja, ruby
mise run install-deps    # Install system packages

# Clone dependencies and build
./setup_gits.sh          # Clone all git sub-repos
mise run setup           # Fast build (build_all_fast.sh)

# Or build manually:
./build_all_fast.sh      # Essential components only
./build_all.sh           # Full build with all ported apps
```

### Using the Fil-C Compiler

```bash
# Basics
build/bin/clang  -o program program.c -g -O
build/bin/clang++ -o program program.cpp -g -O -std=c++20

# Always use -g (needed for meaningful error messages)
# Always use -O with -g (compiler crashes without optimization when debug info present)
```

### Using the filc CLI

```bash
# Run a program with the filc command
path/to/build/bin/clang -o prog prog.c -O -g
./prog    # runs with the filc runtime
```

### Common Debugging Techniques

**Debugging GC issues**:
```bash
FUGC_STW=1 ./prog              # Force stop-the-world (rules out store barrier bugs)
```

**Memory corruption debugging**:
```bash
FUGC_SCRIBBLE=1 FUGC_VERIFY=1 ./prog
```

**GC stress testing**:
```bash
FUGC_MIN_THRESHOLD=0 ./prog    # Maximize GC frequency
```

**Verifying configuration**:
```bash
FILC_DUMP_SETUP=1 FUGC_STW=1 ./prog   # See what env vars took effect
```

**Stack trace on panic**: Always compile with `-g`. The panic message includes:
- The violated safety rule (e.g., "cannot read pointer with ptr >= upper")
- The pointer value, lower, and upper bounds
- The semantic origin (source location where the pointer was created)
- The scheduled origin (source location where the check was placed)

### Where to Start Reading Code

| If you want to understand... | Read... |
|---|---|
| The overall design philosophy | `Manifesto.md` |
| The user-facing API | `filc/include/stdfil.h` (well-documented header) |
| Runtime type definitions | `libpas/src/libpas/filc_runtime.h` |
| How capabilities are checked | `filc_runtime_inlines.h` (inline access check functions) |
| The garbage collector | `libpas/src/libpas/fugc.c` |
| The compiler transformations | `llvm/lib/Transforms/Instrumentation/FilPizlonator.cpp` (start at `class Pizlonator`, line ~1431) |
| Test infrastructure | `filc/run-tests` (the test runner) |
| A simple test | `filc/tests/zversion/` |

---

## Safety Guarantees

### What Fil-C Catches

| Violation | Mechanism |
|---|---|
| **Out-of-bounds access (heap)** | Bounds check: `ptr >= lower && ptr + size <= upper` |
| **Out-of-bounds access (stack)** | Same bounds check via stack capability |
| **Use-after-free** | Free sets `upper = lower` (zero bounds); GC redirects capability to free singleton |
| **Type confusion (int as ptr)** | Loading an int as a ptr gives a NULL capability; dereferencing traps |
| **Type confusion (ptr as int)** | Allowed; just gives the pointer's integer value without capability |
| **Type errors from linking** | Function capabilities include type info; mismatched calls trap |
| **va_list misuse** | `va_arg` checks that the arg pointer is in bounds |
| **Pointer races** | Pointer races on non-atomic/non-volatile pointers cause panics |
| **System call buffer overflows** | All syscall buffers are bounds-checked before kernel handoff |
| **Stack buffer overflows** | alloca gets capabilities with correct bounds |
| **mmap misuse** | mmap'd regions get capabilities; munmap marks them free |

### The GIMSO Principle

"Garbage In, Memory Safety Out" means:

1. No program accepted by the compiler can escape the type system
2. Capabilities cannot be forged (they come from valid allocations only)
3. Type confusion cannot produce a usable pointer (ints loaded as ptrs have NULL capability)
4. At worst, the program's execution is **thwarted at runtime** with a descriptive panic
5. There is **no `unsafe` keyword**, no `__attribute__((unsafe))`, no way to bypass checks

### What's NOT Caught

- **Logic errors that don't involve memory safety**: An off-by-one on an array index that happens to stay within bounds will not be caught
- **Integer overflow within bounds**: `ptr[valid_index] = overflowed_value` is fine
- **Data races on non-pointer data**: Fil-C ensures memory safety even under data races, but doesn't prevent all race conditions
- **Resource leaks**: Memory leaks are benign (GC will eventually clean up); file descriptor leaks are not caught
- **Undefined behavior that doesn't violate capability rules**: Some UB (like strict aliasing violations) may not be caught if they don't violate pointer bounds or types
- **Inline assembly**: Currently disallowed entirely

### Yolo-C Interop

Fil-C programs are severely restricted in linking with regular (yolo) C code. This is fundamental: Fil-C pointers use a different calling convention and representation. The only interop points are:
- `zunsafe_call("symbol_name", args...)` — call a yolo function (used for crypto kernels, assembly)
- The entire dependency chain of a Fil-C program must be compiled with Fil-C

This is by design: any yolo code would be an escape hatch from safety.
