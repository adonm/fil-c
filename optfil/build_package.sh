#!/bin/bash
#
# Copyright (c) 2025 Epic Games, Inc. All Rights Reserved.
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
# THIS SOFTWARE IS PROVIDED BY EPIC GAMES, INC. ``AS IS'' AND ANY
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

set -e
set -x

ulimit -c unlimited

test `id -u` -eq 0

export FILCSRC=$PWD/..

test -d $FILCSRC/filc
test -d $FILCSRC/projects

FILCOWNER=`stat -c %U $FILCSRC`
FILCGROUP=`stat -c %G $FILCSRC`
id -u $FILCOWNER

cd /opt/fil

# OK, we need to strip everything, but:
#
# - We cannot use the system's strip, because it might not be the right version. We know which strip
#   version we need. In fact, the one we built would work great.
# - But we cannot use that strip unless we do the LFS section 8.84 hack. That hack is gross, and I'm
#   worried it's a bit flaky. Basically - we cannot use the strip we built to strip the strip we built
#   or any libraries that the strip we built depends on.
#
# So, we build ourselves our own strip! And we build it using Yolo-C, so that we can be sure that it
# doesn't depend on any of the libraries we are about to strip.
rm -rf binutils
mkdir -v binutils
cd binutils
tar -xf $FILCSRC/pizlix/binutils-2.43.1.tar.xz
cd binutils-2.43.1
mkdir -v build
cd build
../configure --prefix=/opt/fil/binutils \
    --disable-gold \
    --enable-ld=default \
    --enable-shared \
    --disable-werror \
    --enable-64-bit-bfd \
    --enable-new-dtags \
    --with-system-zlib \
    --enable-default-hash-style=gnu \
    --disable-gprofng
make -j `nproc` tooldir=/opt/fil/binutils
make -j `nproc` tooldir=/opt/fil/binutils install
cd ../..
test -d binutils-2.43.1
rm -rf binutils-2.43.1
cd ..
test -d binutils
test -d ../fil

for x in $(find lib -type f -name \*.so*) \
         $(find lib -type f -name \*a) \
         $(find {bin,sbin,libexec} -type f)
do
    LD_LIBRARY_PATH=/opt/fil/binutils/lib /opt/fil/binutils/bin/strip --strip-unneeded $x || echo whatever
done

rm -rf binutils

cd ..
tar -cJf $FILCSRC/optfil/fil.tar.xz fil
chown $FILCOWNER:$FILCGROUP $FILCSRC/optfil/fil.tar.xz

cd $FILCSRC/optfil
su $FILCOWNER ./build_finish.sh


