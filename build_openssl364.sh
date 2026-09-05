#!/bin/sh

#

# Copyright (c) 2023-2025 Epic Games, Inc. All Rights Reserved.

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

# THIS SOFTWARE IS PROVIDED BY EPIC GAMES, INC. ``AS IS AND ANY

# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE

# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR

# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL EPIC GAMES, INC. OR

# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,

# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,

# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR

# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY

# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT

# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE

# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 



. libpas/common.sh



set -e

set -x



# Builds OpenSSL 3.6.4 (vendored at projects/openssl-3.6.4, so unlike

# build_openssl.sh there is no extract_source step and the relative paths go

# up two levels, not three) with assembly enabled: the perlasm generators

# emit sarcasm annotations (gated on SARCASM=1) and Fil-C clang assembles the

# generated .s/.S files with sarcasm (no -yolo-assembler!).

#

# no-padlockeng: the padlock engine's rep-movsq/xcrypt implicit-memory

# instructions are unmodelable in sarcasm (documented decision).

#

# This deliberately does NOT run make install: OpenSSL 3.5.7 (built by

# build_openssl.sh) still owns pizfix's libcrypto.so.3/libssl.so.3.

cd projects/openssl-3.6.4



# If a previous configure (e.g. a no-asm one) left configdata.pm behind,

# distclean it away so that everything, including the perlasm-generated

# assembly, is rebuilt with the configuration below.

if test -f configdata.pm

then

    make distclean || true

    rm -f configdata.pm

fi



# The perlasm .pl files gate their sarcasm hunks (page-walk removals, frame

# restructures, avx2 delegations) on this; x86_64-xlate.pl's signature/global

# annotations are always emitted as gas-compatible `#!' comments.

export SARCASM=1



CC="$PWD/../../build/bin/clang -g -O2" ./Configure \
    zlib no-padlockeng --prefix=$PWD/../../pizfix --libdir=lib
make -j $NCPU > /tmp/openssl364-build.log 2>&1 || {
    tail -200 /tmp/openssl364-build.log
    exit 1
}



# Only run the test suite in a glibc build. There are a bunch of failures in the test suite in a musl

# build.

#

# Retry the suite once if it fails: 70-test_quic_radix.t (check_pc_flood) has a flaky

# wall-clock timeout ("timed out while executing op 33" in test/radix/terp.c) when the

# whole suite runs with full parallelism; it passes reliably on a re-run.

if test -e ../../pizfix/lib/libc.so.6666

then

    HARNESS_JOBS=${HARNESS_JOBS:-$NCPU} make test > /tmp/openssl364-test.log 2>&1 || {
        tail -100 /tmp/openssl364-test.log
        HARNESS_JOBS=${HARNESS_JOBS:-$NCPU} make test > /tmp/openssl364-test-retry.log 2>&1
    } || {
        tail -100 /tmp/openssl364-test-retry.log
        exit 1
    }

fi
