#!/bin/sh
#
# Builds "usercosmo": cosmopolitan libc compiled BY the Fil-C compiler.
#
# This mirrors build_usermusl.sh (the musl flavor) for the cosmo flavor.  It
# compiles a curated subset of cosmo's C sources with build/bin/clang (which
# pizlonates everything), producing:
#
#   pizfix/lib/libc.a   the pizlonated cosmo libc (static)
#   pizfix/lib/crt1.o   the process entry object (yolo cosmo crt + yolo glue)
#   pizfix/include/     cosmo public headers (the flavor switch for the driver)
#
# Preconditions (see the verification flow in the repo docs):
#   1. build/bin/clang exists (Fil-C compiler)
#   2. ./build_yolocosmo.sh has run (installs libyolocosmo.a + ape.o + ape.lds
#      + cosmo-crt.o + pizfix/yolo-include, flipping libpas into cosmo mode)
#   3. (cd libpas && ./clean.sh && ./build.sh)  (cosmo-mode libpizlo.a)
#
# The generated syscall shims land in projects/usercosmo/o-filc/ together with
# all the object files, so the checked-in source diff stays small.

. libpas/common.sh

set -e

ROOT=$PWD
COSMO=$ROOT/projects/usercosmo
BUILD=$COSMO/o-filc
PFX=$ROOT/pizfix

if [ ! -x "$ROOT/build/bin/clang" ]; then
    echo "error: build/bin/clang not found; build the Fil-C compiler first" >&2
    exit 1
fi
if [ ! -e "$PFX/lib/libyolocosmo.a" ]; then
    echo "error: pizfix/lib/libyolocosmo.a missing; run ./build_yolocosmo.sh first" >&2
    exit 1
fi
if [ ! -e "$PFX/lib/libpizlo.a" ] || [ -e "$PFX/lib/libpizlo.so" ]; then
    echo "error: pizfix/lib/libpizlo.a is not the cosmo-mode build;" >&2
    echo "       run ./build_yolocosmo.sh && (cd libpas && ./clean.sh && ./build.sh)" >&2
    exit 1
fi

mkdir -p "$BUILD" "$PFX/lib"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Compile flags.  The Fil-C driver gets -nostdinc plus explicit include
#    paths: stdfil-include (stdfil.h + pizlonated_*.h), then cosmo's own
#    headers.  SUPPORT_VECTOR=1 is the "optlinux" configuration: Linux-only,
#    which makes every Windows/XNU/BSD/Metal branch fold away at compile time
#    (crucial: those branches reference raw asm and Win32 APIs).
# ─────────────────────────────────────────────────────────────────────────────
FILC_CLANG="$ROOT/build/bin/clang"
CLANG_RES="$ROOT/build/lib/clang/20/include"
COSMO_INC="-nostdinc \
 -isystem $PFX/stdfil-include \
 -isystem $COSMO \
 -isystem $COSMO/libc/isystem \
 -isystem $CLANG_RES \
 -include $COSMO/libc/integral/normalize.inc"

CFLAGS="-O2 -g -std=gnu23 \
 -DSUPPORT_VECTOR=1 -D_COSMO_SOURCE -DNDEBUG -DMODE=\"filc\" \
 -march=x86-64 -mavx \
 -fno-omit-frame-pointer -fno-stack-protector -fwrapv \
 -fno-common -w \
 $COSMO_INC"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Generate the syscall shims (replacements for libc/sysv/calls/*.S).
#    They are extracted from cosmo's own headers via the compiler's AST, so
#    every definition is type-checked against cosmo's own prototypes.
# ─────────────────────────────────────────────────────────────────────────────
python3 "$COSMO/filc/gen_shims.py" "$BUILD/shims.c" "$BUILD/consts.c"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Collect the sources to compile.
#
#    Exclusions (each with a reason):
#      libc/intrin/mmap.c munmap.c mprotect.c msync.c madvise.c mincore.c
#                         cosmo's public memory APIs keep bookkeeping in the
#                         __maps RB-tree, which packs tag bits into pointers
#                         (ABA()), a capability no-no.  filc_mmap.c provides
#                         thin zsys_*-based replacements instead.
#      libc/intrin/maps.c the __maps machinery itself (ABA pointer tagging)
#      libc/intrin/stack.c, permalloc.c, describefds.c
#                         more __maps-machinery users (cosmo_stack and
#                         permalloc have Fil-C replacements/stubs)
#      libc/intrin/brain16.c float16.c   bf16/f16 compiler runtime; clang
#                         under Fil-C has no _Float32/__bf16 types and
#                         compiler-rt provides these routines anyway
#      libc/intrin/describe*.c, demangle.c, printmapswin32.c,
#      printwindowsmemory.c, leaklocks.c, showcrashreports.c
#                         STRACE/crash-report debug helpers; several crash
#                         the FilPizlonator (constant-relocation assertion)
#      libc/runtime/cosmo2.c, enable_tls.c
#                         aarch64 boot / yolo kernel-TLS boot (yolo side has
#                         its own; Fil-C TLS needs no kernel setup)
#      libc/intrin/tprecode8to16.c, printwindowsmemory.c
#                         pull the vendored aarch64 NEON headers
#      libc/proc/fork-nt.c vfork-nt.c msync-nt.c posix_madvise-nt.c
#                         Windows-only wrappers
#      libc/thread/pthread_cancel.c   raw asm + SIGTHR machinery; stub in filc_stub.c
#      libc/intrin/x86.c   defines __cpu_model/__cpu_indicator_init/__cpu_features2,
#                         which libpizlo.a already provides for pizlonated code
#                         (filc_native___cpu_indicator_init); including both
#                         makes every __builtin_cpu_supports() user hit a
#                         multiple-definition link error
#      libc/str/qsort.c    cosmo's introsort does unchecked pointer arithmetic
#                         on the array bounds that the filc runtime rejects on
#                         ordinary inputs; filc_extra.c provides a plain
#                         (correct, if unglamorous) qsort/qsort_r instead
#      libc/calls/madvise.c only knows the five original MADV_* advices and
#                         rejects (EINVAL) everything else before the call
#                         reaches the runtime; filc_mmap.c's madvise() forwards
#                         everything to zsys_madvise(), whose per-advice
#                         checking is what the test suite expects
#      libc/nexgen32e/envp.c duplicates the pizlonated __envp that
#                         filc_libc_start_main.c defines and fills; if both
#                         land in the link (assert() pulls envp.c.o via the
#                         crash-report helpers) every such program dies with
#                         a multiple-definition error
#      kprintf.greg.c, clone.c, seccomp.c, pledge-linux.c, islinux.c
#                         raw `syscall` inline asm without shims
#                         (islinux.c: __is_linux_2_6_23 has a C replacement in
#                         libc/calls/filc_islinux.c)
#      mman.greg.c        bare-metal page-table code with module asm
# ─────────────────────────────────────────────────────────────────────────────
EXCLUDE_DIRS="libc/testbed libc/irq libc/dsp libc/vga libc/x8664"
EXCLUDE_FILES="
libc/intrin/mman.greg.c
libc/intrin/x86.c
libc/str/qsort.c
libc/calls/madvise.c
libc/mem/aligned_alloc.c
libc/mem/posix_memalign.c
libc/mem/malloc_usable_size.c
libc/mem/leaks.c
libc/mem/mallopt.c
libc/mem/mallinfo.c
libc/mem/malloc_trim.c
libc/mem/malloc_usable_size.c
libc/mem/memalign.c
libc/mem/free.c
libc/mem/realloc_in_place.c
libc/mem/realloc.c
libc/mem/calloc.c
libc/mem/malloc.c
third_party/dlmalloc/dlmalloc_abort.c
third_party/dlmalloc/dlmalloc.c
libc/str/wcsstr.c
libc/str/strrchr16.c
libc/str/strchrnul16.c
libc/str/rawmemchr32.c
libc/intrin/strlen16.c
libc/str/memcasecmp.c
libc/str/memrchr16.c
libc/str/strstr16.c
libc/str/rawmemchr16.c
libc/str/memchr16.c
libc/str/strncmp16.c
libc/str/strnlen16.c
libc/str/wcscpy.c
libc/str/wcscmp.c
libc/str/wcsrchr.c
libc/str/wcschr.c
libc/str/wcslen.c
libc/str/strncat16.c
libc/str/strcat16.c
libc/str/strcpy16.c
libc/str/strcmp16.c
libc/str/strchr16.c
libc/str/strlen16.c
libc/str/memmem.c
libc/str/strcasestr.c
libc/str/strstr.c
libc/str/strncpy.c
libc/str/strncat.c
libc/str/strcat.c
libc/intrin/memchr.c
libc/intrin/strcpy.c
libc/intrin/strncmp.c
libc/intrin/strcmp.c
libc/intrin/strchrnul.c
libc/intrin/strrchr.c
libc/intrin/strchr.c
libc/intrin/strnlen.c
libc/intrin/strlen.c
libc/intrin/kprintf.greg.c
libc/intrin/exit1.greg.c
libc/intrin/mmap.c
libc/intrin/munmap.c
libc/intrin/mprotect.c
libc/intrin/msync.c
libc/intrin/madvise.c
libc/intrin/mincore.c
libc/intrin/mremap.c
libc/intrin/mlock.c
libc/intrin/munlock.c
libc/intrin/mlockall.c
libc/intrin/munlockall.c
libc/intrin/msync.c
libc/intrin/maps.c
libc/intrin/stack.c
libc/intrin/permalloc.c
libc/intrin/describefds.c
libc/intrin/brain16.c
libc/intrin/float16.c
libc/intrin/leaklocks.c
libc/intrin/demangle.c
libc/intrin/tprecode8to16.c
libc/intrin/printmapswin32.c
libc/intrin/describentpageflags.c
libc/intrin/describemremapflags.c
libc/intrin/describeallocationtype.c
libc/intrin/describecontrolkeystate.c
libc/intrin/describednotify.c
libc/intrin/describecapability.c
libc/intrin/describethreadcreationflags.c
libc/intrin/describepersonalityflags.c
libc/intrin/describentfilemapflags.c
libc/intrin/describentfileflagattr.c
libc/intrin/describentsymlinkflags.c
libc/intrin/describentstartflags.c
libc/intrin/describentpipemodeflags.c
libc/intrin/describentprocaccessflags.c
libc/intrin/describentpipeopenflags.c
libc/intrin/describentmovfileinpflags.c
libc/intrin/describentlockfileflags.c
libc/intrin/describentfileshareflags.c
libc/intrin/describentfiletypeflags.c
libc/intrin/describentfileaccessflags.c
libc/intrin/describentconsolemodeoutputflags.c
libc/intrin/describentconsolemodeinputflags.c
libc/runtime/clone.c
libc/runtime/cosmo2.c
libc/runtime/enable_tls.c
libc/runtime/utmp.c
libc/nexgen32e/environ2.c
libc/nexgen32e/auxv2.c
libc/runtime/fork-nt.c
libc/calls/pledge-linux.c
libc/calls/seccomp.c
libc/calls/islinux.c
libc/calls/sigaction.c
libc/runtime/zipos-stat.c
libc/runtime/zipos-stat-impl.c
libc/runtime/zipos-seek.c
libc/runtime/zipos-read.c
libc/runtime/zipos-parseuri.c
libc/runtime/zipos-open.c
libc/runtime/zipos-notat.c
libc/runtime/zipos-normpath.c
libc/runtime/zipos-mmap.c
libc/runtime/zipos-inode.c
libc/runtime/zipos-get.c
libc/runtime/zipos-fstat.c
libc/runtime/zipos-find.c
libc/runtime/zipos-close.c
libc/runtime/zipos-access.c
libc/calls/uname.c
libc/thread/pthread_cancel.c
libc/thread/makecontext.c
libc/thread/pthread_getaffinity_np.c
libc/thread/pthread_setaffinity_np.c
libc/proc/getpriority.c
libc/proc/fork-nt.c
libc/proc/vfork-nt.c
libc/nexgen32e/envp.c
libc/log/printwindowsmemory.c
libc/intrin/posix_madvise-nt.c
libc/intrin/msync-nt.c
libc/dlopen/dlopen.c
libc/dlopen/dlclose.c
libc/dlopen/dlsym.c
"

# third_party trees that are part of the v1 library
THIRD_PARTY_DIRS="third_party/nsync third_party/gdtoa third_party/tz"

SRCS=$BUILD/sources.txt
: > "$SRCS"
for dir in $EXCLUDE_DIRS; do :; done  # (placeholder for readability)

cd "$COSMO"

# core libc
find libc -name '*.c' | LC_ALL=C sort > "$SRCS"
for dir in $EXCLUDE_DIRS; do
    grep -v "^$dir/" "$SRCS" > "$SRCS.tmp" && mv "$SRCS.tmp" "$SRCS"
done
for f in $EXCLUDE_FILES; do
    grep -v "^$f\$" "$SRCS" > "$SRCS.tmp" && mv "$SRCS.tmp" "$SRCS"
done
# tool directories that require the cosmo build machinery / yolo-only
grep -v "^libc/sysv/calls/" "$SRCS" > "$SRCS.tmp" && mv "$SRCS.tmp" "$SRCS"  # .S thunks (no .c here, belt & braces)
grep -v "^libc/crt/" "$SRCS" > "$SRCS.tmp" && mv "$SRCS.tmp" "$SRCS"         # cosmo's asm crt (yolo crt1.o is used)
# third_party
for dir in $THIRD_PARTY_DIRS; do
    find "$dir" -name '*.c' | LC_ALL=C sort >> "$SRCS"
done
# third_party/getopt: the __optarg/__optind/__getopt implementation that the
# sed/tr applets use; third_party/regex: POSIX regcomp/regexec used by sed
# (and by glob-style tools); musl's pwd.c backs getpwnam_r/getpwuid_r which
# glob.c calls.
find third_party/getopt third_party/regex -name '*.c' | LC_ALL=C sort >> "$SRCS"
for m in pwd.c fgetspent.c getspnam_r.c putspent.c; do
    find third_party/musl -name "$m" >> "$SRCS" 2>/dev/null || true
done
# selected musl bits.  cosmo vendors chunks of musl in third_party/musl/ and
# uses them as the canonical implementations of the corresponding APIs; the
# files below are the pieces the test suite needs (search tree, netdb/
# resolver, locale, wctype, glob), plus the previously present strftime/
# langinfo group.  Everything here is plain C that compiles under Fil-C.
MUSL_FILES="strftime*.c wcsftime*.c timelocal*.c langinfo.c asctime*.c \
__tm_to_secs.c lctrans.c __mo_lookup.c locinfo.c __month_to_secs.c \
__year_to_secs.c __secs_to_tm.c __days_from_civil.c \
tsearch.c tfind.c tdelete.c tdestroy.c twalk.c \
getaddrinfo.c freeaddrinfo.c gai_strerror.c getnameinfo.c \
getservbyname.c getservbyname_r.c getservbyport.c getservbyport_r.c \
gethostbyname.c gethostbyname_r.c gethostbyname2.c gethostbyname2_r.c \
gethostbyaddr.c gethostbyaddr_r.c h_errno.c herror.c hstrerror.c \
lookup_name.c lookup_ipliteral.c lookup_serv.c \
res_mkquery.c res_msend.c res_send.c res_query.c res_querydomain.c \
res_state.c res_init.c resolvconf.c dns_parse.c dn_comp.c dn_expand.c \
dn_skipname.c proto.c serv.c \
setlocale.c locale_map.c newlocale.c duplocale.c freelocale.c uselocale.c \
iswctype.c iswalnum.c iswalpha.c iswpunct.c wctrans.c towctrans.c \
catopen.c catgets.c catclose.c \
btowc.c wctob.c \
mbrtowc.c wcrtomb.c mbsinit.c mbstowcs.c wcstombs.c mbsrtowcs.c \
mbsnrtowcs.c wcsnrtombs.c wcsrtombs.c mbrlen.c mblen.c mbtowc.c \
wctomb.c mbrtoc16.c mbrtoc32.c c16rtomb.c c32rtomb.c multibyte.c \
mapfile.c \
glob.c fnmatch.c"
for m in $MUSL_FILES; do
    find third_party/musl -name "$m" >> "$SRCS" 2>/dev/null || true
done
# The embedded sed/tr applets that cosmo's system()/popen() shell (cocmd)
# dispatches to; without them every system() user has undefined symbols.
find third_party/sed third_party/tr -name '*.c' | LC_ALL=C sort >> "$SRCS"

cd "$ROOT"

echo "compiling $(wc -l < "$SRCS") sources with Fil-C clang on $NCPU cores..."
printf '%s\n%s\n%s\n' "$BUILD/shims.c" "$BUILD/consts.c" "$BUILD/errfuns.c" >> "$SRCS"

# ─────────────────────────────────────────────────────────────────────────────
# 4. Parallel compile.  Each source becomes o-filc/<path>.o.  Errors are
#    collected so the failing files are easy to see afterwards.
# ─────────────────────────────────────────────────────────────────────────────
compile_one() {
    src="$1"
    out="o-filc/$src.o"
    mkdir -p "$(dirname "$out")"
    if ! $FILC_CLANG $CFLAGS -c -o "$out" "$src" 2>> "$BUILD/compile-errors.log"; then
        echo "FAILED: $src" >> "$BUILD/compile-failures.txt"
        rm -f "$out"
        return 1
    fi
    return 0
}
export FILC_CLANG CFLAGS BUILD COSMO FORCE

rm -f "$BUILD/compile-failures.txt" "$BUILD/compile-errors.log"

cat > "$BUILD/compile.sh" <<'EOF'
#!/bin/sh
src="$1"
cd "$COSMO"
case "$src" in
    /*) out="o-filc/generated/$(basename "$src" .c).o" ;;
    *)  out="o-filc/$src.o" ;;
esac
mkdir -p "$(dirname "$out")"
# Incremental: skip the compile when the object is newer than the source.
# Force a full rebuild with FORCE=1 (e.g. after editing a widely-included
# header); headers alone are not tracked.
if [ -z "$FORCE" ] && [ "$out" -nt "$src" ]; then
    exit 0
fi
if ! "$FILC_CLANG" $CFLAGS -c -o "$out" "$src" 2>> "$BUILD/compile-errors.log"; then
    echo "FAILED: $src" >> "$BUILD/compile-failures.txt"
    rm -f "$out"
    exit 1
fi
EOF
chmod +x "$BUILD/compile.sh"

# xargs -P does the parallelism; -P $NCPU
FORCE="$FORCE" xargs -P "$NCPU" -n 1 -I {} "$BUILD/compile.sh" {} < "$SRCS" || true

# Remove stale objects: files that used to be compiled but are now excluded
# would otherwise keep landing in libc.a.
cd "$COSMO"
for obj in $(cd "$BUILD" && find . -name '*.c.o' ); do
    src="${obj#./}"
    src="${src%.o}"
    case "$src" in
        generated/*) continue ;;
    esac
    if ! grep -qxF "$src" "$SRCS"; then
        rm -f "$BUILD/$obj"
    fi
done
cd "$ROOT"

# ─────────────────────────────────────────────────────────────────────────────
# 4b. A few cosmo sources are C++ (.cc): libc/str/isw{lower,upper,separator}.cc
#     implement the wide-char classification tables with a C++ template
#     (libc/str/has_char.h).  They compile fine with the Fil-C C++ front end;
#     the public declarations are extern "C" via COSMOPOLITAN_C_START_, so the
#     symbols land unmangled as pizlonated_<name>.
# ─────────────────────────────────────────────────────────────────────────────
CCXX="libc/str/iswlower.cc libc/str/iswupper.cc libc/str/iswseparator.cc"
for cc in $CCXX; do
    out="$BUILD/$cc.o"
    if [ "$FORCE" ] || [ ! -f "$out" ] || [ "$COSMO/$cc" -nt "$out" ]; then
        mkdir -p "$(dirname "$out")"
        (cd "$COSMO" && "$FILC_CLANG++" -O2 -g -std=gnu++20 \
            -DSUPPORT_VECTOR=1 -D_COSMO_SOURCE -DNDEBUG -DMODE=\"filc\" \
            -march=x86-64 -mavx \
            -fno-omit-frame-pointer -fno-stack-protector -fwrapv \
            -fno-common -w -fno-exceptions -fno-rtti -nostdinc++ \
            $COSMO_INC -c -o "$out" "$cc" 2>> "$BUILD/compile-errors.log") || {
            echo "FAILED: $cc" >> "$BUILD/compile-failures.txt"
            rm -f "$out"
        }
    fi
done

if [ -s "$BUILD/compile-failures.txt" ]; then
    echo ""
    echo "=== $(wc -l < "$BUILD/compile-failures.txt") files FAILED to compile ==="
    cat "$BUILD/compile-failures.txt"
    echo "=== details in $BUILD/compile-errors.log ==="
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Archive everything into pizfix/lib/libc.a (the cosmo flavor's -lc).
# ─────────────────────────────────────────────────────────────────────────────
echo "building $PFX/lib/libc.a..."
find "$BUILD" -name '*.o' | LC_ALL=C sort > "$BUILD/objects.txt"
rm -f "$PFX/lib/libc.a"
# shellcheck disable=SC2046
ar crs "$PFX/lib/libc.a" $(cat "$BUILD/objects.txt" | sed "s|^$BUILD/||") || {
    # ar wants to run in the build dir so member names are relative
    (cd "$BUILD" && ar crs "$PFX/lib/libc.a" $(cat objects.txt | sed "s|^$BUILD/||"))
}

# ─────────────────────────────────────────────────────────────────────────────
# 5b. libm.a: cosmo folds all of libm into libc.a, but portable programs (and
#     the test suite) link with -lm.  musl's flavor ships a real libm.a; give
#     the cosmo flavor an empty one so that -lm resolves.
# ─────────────────────────────────────────────────────────────────────────────
if [ ! -e "$PFX/lib/libm.a" ] || [ "$PFX/lib/libc.a" -nt "$PFX/lib/libm.a" ]; then
    rm -f "$PFX/lib/libm.a"
    ar crs "$PFX/lib/libm.a"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. crt1.o: the cosmo yolo crt (raw _start → cosmo() boot, installed by
#    build_yolocosmo.sh as cosmo-crt.o) fused with yolo glue.  The glue
#    provides plain (un-pizlonated) symbols that libpizlo.a's yolo side
#    references but that libyolocosmo doesn't define (llrintl).  It has to be
#    fused into crt1.o because the link order is crt1.o … -lc … -lpizlo, and
#    an archive member of libc.a is only pulled when its symbols are already
#    referenced — which for llrintl happens later, inside libpizlo.a.
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: the glue must be compiled by the HOST compiler: the Fil-C clang would
# pizlonate it into pizlonated_* symbols, and the whole point is to provide
# plain ones for the yolo side.
clang -c -o "$BUILD/yologlue.o" "$COSMO/filc/yologlue.c" \
    -nostdinc -isystem "$PFX/yolo-include" \
    -include "$PFX/yolo-include/normalize.inc" -D__COSMOPOLITAN__ \
    -w
ld -r -o "$BUILD/crt1.fused.o" "$PFX/lib/cosmo-crt.o" "$BUILD/yologlue.o"
cp -f "$BUILD/crt1.fused.o" "$PFX/lib/crt1.o"

# ─────────────────────────────────────────────────────────────────────────────
# 7. Install the cosmo public headers into pizfix/include (what cosmocc ships
#    as include/: the isystem headers at the top level plus the internal
#    header trees that cosmo headers cross-include).
#
#    cosmo's isystem headers assume that normalize.inc was force-included
#    first (cosmocc does `-include libc/integral/normalize.inc`), which is
#    what provides COSMOPOLITAN_C_START_/bool32/libcesque/etc.  The Fil-C
#    driver has no equivalent of that wrapper flag, so every installed
#    isystem header gets the normalize include prepended.  normalize.inc is
#    idempotent (c.inc and friends have proper include guards), so multiple
#    inclusions are harmless.
# ─────────────────────────────────────────────────────────────────────────────
echo "installing cosmo headers into $PFX/include..."
rm -rf "$PFX/include"
mkdir -p "$PFX/include"
(cd "$COSMO/libc/isystem" && find . -type f) | LC_ALL=C sort > "$BUILD/headers.txt"
(cd "$COSMO/libc/isystem" && tar -cf - .) | (cd "$PFX/include" && tar -xf -)
(cd "$COSMO" && find libc ape ctl third_party -name '*.h' -o -name '*.inc' | tar -cf - -T -) | (cd "$PFX/include" && tar -xf -)
cp -f "$COSMO/libc/integral/"*.inc "$PFX/include/" 2>/dev/null || true
while read -r h; do
    h="${h#./}"
    target="$PFX/include/$h"
    [ -f "$target" ] || continue
    if ! grep -q "libc/integral/normalize.inc" "$target"; then
        printf '#ifdef __FILC__\n/* Fil-C port: force-include normalize.inc (see build_usercosmo.sh). */\n/* Also default to _GNU_SOURCE: the test suite and portable Linux code\n * expect the POSIX+BSD+GNU declaration surface that musl (whose headers\n * are the musl flavor'"'"'s default) exposes without explicit feature-test\n * macros.  cosmo hides those declarations unless a feature macro is set,\n * which would turn a large class of otherwise-fine programs into compile\n * errors for no good reason. */\n#ifndef _GNU_SOURCE\n#define _GNU_SOURCE 1\n#endif\n#include "libc/integral/normalize.inc"\n#endif\n' > "$target.new"
        cat "$target" >> "$target.new"
        mv "$target.new" "$target"
    fi
done < "$BUILD/headers.txt"

echo ""
echo "usercosmo build complete:"
echo "  libc.a  = $(ls -la "$PFX/lib/libc.a" | awk '{print $5}') bytes, $(ar t "$PFX/lib/libc.a" | wc -l) members"
echo "  crt1.o  = yolo cosmo crt + yolo glue"
echo "  headers = $PFX/include (cosmo flavor)"
echo ""
echo "Try: build/bin/clang -o /tmp/cosmohello /tmp/hello.c && /tmp/cosmohello"
