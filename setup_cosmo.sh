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

# Cosmopolitan libc (cosmo) flavor.  Cosmo plays both roles that musl and
# glibc play in the other flavors: build_yolocosmo.sh builds cosmo with its
# own GCC toolchain to get the yolo (un-pizlonated) libc below libpizlo
# (pizfix/lib/libyolocosmo.a + ape.o + ape.lds + cosmo-crt.o), and
# build_usercosmo.sh rebuilds cosmo with the Fil-C compiler to get the user
# libc (pizfix/lib/libc.a + pizfix/lib/crt1.o + pizfix/include).  Cosmo mode
# links static, non-PIE executables via the cosmo APE linker script.

export ALTYOLO=./build_yolocosmo.sh
export ALTUSER=./build_usercosmo.sh

# Note: ALTLLVMLIBCOPT is deliberately not set and no libc++ is built for
# cosmo yet: build_cxx.sh (libc++/libc++abi against the user libc) and the
# minilute/sarcasm tools (which would have to be cosmo binaries themselves)
# are intentionally not part of the cosmo flow at this time.
