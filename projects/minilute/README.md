# minilute

**minilute** is a minimal, lute-compatible runtime for [Luau](https://luau.org)
scripts. It provides just enough of [lute](https://github.com/luau-lang/lute)'s
API surface — `require`, `@lute/fs`, and `@lute/process` — to run the
**sarcasm** memory-safe assembler (`projects/sarcasm`, written in Luau) without
building all of lute (which needs cmake, libuv, OpenSSL, curl, and a two-stage
bootstrap).

minilute does **not** vendor a copy of luau or lute. Its Makefile builds the
luau tree that lute vendors (`../lute-1.0.0/extern/luau`, Luau 0.716) in release
mode via luau's own Makefile, and links against the resulting static libraries
(`libluauvm`, `libluaucompiler`, `libluauast`, `libluauconfig`, `libluaurequire`,
`libluaucommon`). The require-by-string machinery is Luau's own Require library
(`libluaurequire.a`) driven by a minilute VFS modeled on lute's
(`lute/require/src/`), so module resolution behaves exactly like lute's.

## Building

```sh
cd projects/minilute
make -j$(nproc)                                        # host toolchain (cc/c++)
make -j$(nproc) CC=$FILC/build/bin/clang CXX=$FILC/build/bin/clang++   # Fil-C
```

`CC`/`CXX` select the toolchain used for **both** minilute itself and the luau
sub-build (they are forwarded to luau's Makefile); different Fil-C build modes
name/place the compiler differently, so always pass both explicitly when
building for Fil-C. Other variables:

- `LUAU_DIR` (default `../lute-1.0.0/extern/luau`) — the luau source tree.
  Building creates `LUAU_DIR/build/` in-tree; `make distclean` removes it.
- `CONFIG` (default `release`) — luau's build configuration.

Targets: `all` (default), `clean` (minilute artifacts only), `distclean` (also
removes `LUAU_DIR/build`).

From the repo root, `./build_minilute.sh` does all of this with the Fil-C
toolchain (`build/bin/clang`/`build/bin/clang++`), installs the binary into
`pizfix/bin/`, and runs the smoke test plus a sarcasm invocation.
`build_base.sh` runs it right after `build_cxx.sh`.

## Usage

```sh
minilute path/to/script.luau [args...]
```

The script path may be extensionless (`minilute script` finds `script.luau`,
then `script.lua`, then `script/init.luau`, then `script/init.lua`), exactly
like `lute run`. Inside the script, `process.args[1]` is the script path as
typed on the command line, and the remaining arguments follow. Example:

```sh
pizfix/bin/minilute projects/sarcasm/sarcasm-cli.luau --version   # prints: sarcasm 0.1.0
```

## Supported API surface

### `require`

Luau's require-by-string, resolved exactly like lute:

- Relative requires (`"./name"`, `"../name"`) resolve relative to the
  **requiring module's** directory, with suffix probe order `<path>.luau`,
  `<path>.lua`, `<path>/init.luau`, `<path>/init.lua`; ambiguous resolutions are
  an error. Modules are cached by absolute path and must return exactly one
  value.
- `@lute/fs` and `@lute/process` load the builtin C modules described below.
- Any other `@alias` is rejected ("`@foo is not a valid alias`").
- `.luaurc`/`.config.luau` files are ignored entirely (treated as absent).

### `@lute/fs`

Synchronous POSIX reimplementation of lute's fs module:

`open`, `read`, `write`, `close`, `remove`, `stat`, `exists`, `type`, `link`,
`symlink`, `copy`, `mkdir`, `listdir`, `rmdir`.

- `open(path, mode?)` returns a lightuserdata handle; mode strings follow lute
  (`r`/`w`/`x`/`a`/`+` semantics, including lute's creation modes). `write` goes
  straight to `write(2)` (unbuffered), so a `close` is never required for data
  to land; `read` reads from the current offset to EOF and returns one string.
- `exists(path)` → boolean (`false` only on ENOENT; other errors raise).
- `type(path)` → `"file"|"dir"|"link"|"fifo"|"socket"|"char"|"block"|"unknown"`.
- `stat(path)` → `{ type, size, created, accessed, modified, permissions = { readonly } }`.
  Timestamps are plain tables `{ seconds =, nanoseconds = }` (lute uses a
  `@lute/time` duration userdata, which minilute does not have; `created` is
  always zero on Linux since plain `lstat` has no birth time).
- `listdir(path)` → array of `{ name =, type = }`.
- Omitted: `watch` (needs libuv).
- Deliberate difference from lute: minilute does not free the handle struct on
  `close`, so use-after-close raises the same clean Lua errors lute intends
  ("File handle is closed" / "File handle is already closed") instead of
  dereferencing freed memory (which the Fil-C build of lute traps on).

### `@lute/process`

Synchronous reimplementation (fork/execve/poll/waitpid) of lute's process
module. Functions: `run`, `system`, `homedir`, `cwd`, `exit`, `execPath`.
Properties: `env`, `args`.

- `process.run({ cmd, arg1, ... }, options?)` spawns `cmd` (PATH search like
  execvp when `cmd` has no slash) and returns
  `{ ok = (exitcode == 0 and signal == 0), exitcode, stdout, stderr, signal }`.
  Captured output gets CRLF→LF conversion; when the child dies by signal,
  `exitcode` is 0 and `signal` is the signal number as a string. Options:
  `cwd` (string), `stdio` (`"default"` = capture pipes, `"inherit"`, `"none"` =
  /dev/null), `env` (string→string table merged over a copy of the current
  environment). Spawn failure raises `"Failed to spawn process: %s"`.
- `process.system(cmd, options?)` runs `cmd` via `$SHELL -c` (fallback
  `/bin/sh`); option `system` overrides the shell.
- `process.exit(code = 0)` exits immediately.
- `process.cwd()`, `process.homedir()`, `process.execPath()` return strings.
- `process.env` is a table backed by the real environment: reads call `getenv`
  (nil if unset), writes call `setenv` (assigning nil unsets), and iteration
  (`for k, v in process.env`) walks all `KEY=VALUE` pairs.
- `process.args` is a readonly 1-based array; `args[1]` is the script path as
  typed.

The child of `fork()` only calls async-signal-safe functions (`dup2`, `chdir`,
`execve`, `write`, `_exit`); all argv/envp construction and PATH resolution
happens in the parent before the fork, and an `O_CLOEXEC` error pipe reports
exec failure back to the parent.

## Limitations

- No libuv and no event loop: lute's async/concurrent APIs (`@lute/task`,
  `@lute/net`, `fs.watch`, ...) do not exist, and a script that yields its main
  thread is an error.
- No `@std/*` modules, no other `@lute/*` modules (no `crypto`, `io`, `luau`,
  `system`, `time`, `vm`), no `lute` CLI subcommands (`check`, `compile`,
  `test`, ...). `minilute` only runs scripts.
- No `.luaurc` alias/config support (config files are treated as absent).
- No native codegen (interpreted bytecode only); compile options match lute
  (`optimizationLevel=2, debugLevel=2, typeInfoLevel=1`).
- `fs.stat` timestamps are `{ seconds, nanoseconds }` tables, not lute duration
  objects; `created` is always zero on Linux.
- `fs.type`/`fs.stat` use `lstat` (do not follow symlinks); lute uses `stat`.
- `process.run` uses `execve` directly: no shell fallback for scripts lacking a
  shebang (ENOEXEC).

## Files

- `minilute.cpp` — main: Luau FFlags (like lute's `luauflags.cpp`), VM setup
  (`luaL_openlibs`, nil `setfenv`/`getfenv`, `luaL_sandbox`), script path
  resolution, compile/run, error reporting.
- `require.cpp` — `luarequire_Configuration` vtable driving Luau's Require
  library; disk + `@lute` VFS (modeled on lute's `filevfs.cpp`/`lutevfs.cpp`/
  `requirevfs.cpp`).
- `modulepath.h` — lute's `ModulePath` (require-by-string path resolution).
- `fs.cpp` — the `@lute/fs` module.
- `process.cpp` — the `@lute/process` module.
- `pathutils.cpp` — path/file helpers ported from Luau's `CLI/src/FileUtils.cpp`
  (so path normalization matches lute byte-for-byte, `./` prefix included).
- `tests/smoke.luau`, `tests/smokelib.luau` — self-test run by
  `build_minilute.sh` (also passes under real lute).

## Testing

```sh
pizfix/bin/minilute projects/minilute/tests/smoke.luau        # from repo root
pizfix/bin/minilute projects/sarcasm/sarcasm-cli.luau --version
```
