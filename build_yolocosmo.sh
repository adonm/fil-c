. libpas/common.sh

set -e
set -x

# Which cosmo mode to build. x86_64-optlinux is the Linux-only mode
# (SUPPORT_VECTOR=1, no ftrace, no tlscc), which is what we want for the yolo
# libc below libpizlo.
COSMOMODE=${COSMOMODE:-x86_64-optlinux}

# Build cosmo. This is a pure GNU-make build (no ./configure); the first run
# downloads its own GCC 14.1 toolchain into projects/yolocosmo/.cosmocc. The
# 'toolchain' target builds cosmopolitan.a, ape/ape.o, ape/ape.lds, and
# libc/crt/crt.o without running cosmo's own test suite.
cd projects/yolocosmo

$MAKE -j $NCPU m=$COSMOMODE toolchain

cd ../..

mkdir -p pizfix/lib

# The cosmo flavor marker file. Its existence in pizfix/lib flips the libpas
# Makefile into cosmo mode (COSMO != empty).
cp -f projects/yolocosmo/o/$COSMOMODE/cosmopolitan.a pizfix/lib/libyolocosmo.a
cp -f projects/yolocosmo/o/$COSMOMODE/ape/ape.o pizfix/lib/ape.o
cp -f projects/yolocosmo/o/$COSMOMODE/ape/ape.lds pizfix/lib/ape.lds
cp -f projects/yolocosmo/o/$COSMOMODE/libc/crt/crt.o pizfix/lib/cosmo-crt.o

# Install the cosmo headers into yolo-include, so that libpas can be compiled
# with:
#
#   clang -nostdinc -isystem pizfix/yolo-include \
#       -include pizfix/yolo-include/normalize.inc
#
# The layout is:
#
#   yolo-include/*.h           <- libc/isystem/*.h (the "system" headers)
#   yolo-include/<subdir>/*.h  <- libc/isystem/<subdir>/* (sys/, net/, etc.)
#   yolo-include/libc/...      <- header-only copies of cosmo's internal
#                                 trees, since cosmo's headers cross-include
#                                 each other like "libc/foo/bar.h" and
#                                 "ape/relocations.h"
#   yolo-include/ape/...
#   yolo-include/third_party/... and yolo-include/ctl/...  <- more internal
#                                 trees that cosmo's headers reach into
#   yolo-include/normalize.inc <- and the other libc/integral/*.inc, also
#                                 copied to the top for -include convenience
rm -rf pizfix/yolo-include
mkdir -p pizfix/yolo-include

(cd projects/yolocosmo/libc/isystem && tar -cf - .) | (cd pizfix/yolo-include && tar -xf -)
(cd projects/yolocosmo && find libc ape ctl third_party -name '*.h' -o -name '*.inc' | tar -cf - -T -) | (cd pizfix/yolo-include && tar -xf -)
cp -f projects/yolocosmo/libc/integral/*.inc pizfix/yolo-include/
