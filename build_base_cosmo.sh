#!/bin/sh
#
# Copyright (c) 2025 Epic Games, Inc. All Rights Reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
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

. ./setup_cosmo.sh

rm -rf pizfix

./build_projeny_yolo.sh
./build_compiler_rt.sh
./build_yolounwind.sh
./configure_llvm.sh
./build_clang.sh
./build_os_include.sh

if test "x$ALTYOLO" != "x"
then
    $ALTYOLO
else
    ./build_yolocosmo.sh
fi

./build_runtime.sh

if test "x$ALTUSER" != "x"
then
    $ALTUSER
else
    ./build_usercosmo.sh
fi

# Note: unlike build_base.sh, there is no ./build_cxx.sh, ./build_minilute.sh
# or ./build_sarcasm.sh here: there is no libc++ port for cosmo yet (and the
# sarcasm binary would itself have to be a cosmo binary in this flavor).
