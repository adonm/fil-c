#!/bin/sh
#
# Copyright (c) 2026 Filip Pizlo. All Rights Reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY FILIP PIZLO ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL FILIP PIZLO OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Builds the yolo (un-pizlonated) cosmopolitan libc that sits below libpizlo
# in the cosmo flavor of Fil-C, and installs it into pizfix together with the
# APE bootloader bits and the yolo-include headers.
#
# Only a slim subset of cosmo is built: the objects whose symbols the Fil-C
# runtime (libpizlo.a), the yolo crt chain, the pizlonated user libc, and the
# pizlonated C++ runtimes can reference.  That subset is enumerated in
# projects/yolocosmo/filc/filc-objects.mk, which projects/yolocosmo/filc/
# compute-closure.py regenerates from the full cosmopolitan.a when cosmo or
# the runtime changes (see that script for the exact method).  zlib, ncurses,
# mbedtls, the cosmo test/tool trees, etc. are not built and not installed.

. libpas/common.sh

set -e
set -x

# Which cosmo mode to build. x86_64-optlinux is the Linux-only mode
# (SUPPORT_VECTOR=1, no ftrace, no tlscc), which is what we want for the yolo
# libc below libpizlo.
COSMOMODE=${COSMOMODE:-x86_64-optlinux}

# Build cosmo. This is a pure GNU-make build (no ./configure); the first run
# downloads its own GCC 14.1 toolchain into projects/yolocosmo/.cosmocc. The
# 'filcyolo' target builds the slim libyolocosmo.a (see above), ape/ape.o,
# ape/ape.lds, and libc/crt/crt.o without running cosmo's own test suite.
cd projects/yolocosmo

$MAKE -j $NCPU m=$COSMOMODE filcyolo

cd ../..

mkdir -p pizfix/lib

# The cosmo flavor marker file. Its existence in pizfix/lib flips the libpas
# Makefile into cosmo mode (COSMO != empty).
cp -f projects/yolocosmo/o/$COSMOMODE/filc/libyolocosmo.a pizfix/lib/libyolocosmo.a
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
