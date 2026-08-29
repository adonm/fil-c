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
# THIS SOFTWARE IS PROVIDED BY FILIP PIZLO ``AS IS AND ANY
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

# Install sarcasm into a pizfix-style prefix.
#
# Usage: install.sh PREFIX
#
# This installs:
#
#   PREFIX/lib/sarcasm/  - the sarcasm Luau modules (copied from this directory).
#
#   PREFIX/bin/sarcasm   - a 755 mode Luau script whose #! runs
#                          PREFIX/bin/minilute and which uses Luau's relative
#                          require to load the sarcasm logic from
#                          ../lib/sarcasm. It is otherwise modeled after
#                          sarcasm-cli.luau in this directory.
#
# The entry script is interpreted by minilute, so PREFIX/bin/minilute must
# already be installed (build_minilute.sh does that).

set -e

if [ $# -ne 1 ]
then
    echo "usage: $0 PREFIX" >&2
    exit 1
fi

PREFIX="$1"

if [ ! -x "$PREFIX/bin/minilute" ]
then
    echo "$0: $PREFIX/bin/minilute does not exist; run build_minilute.sh first" >&2
    exit 1
fi

mkdir -p "$PREFIX/bin"

rm -rf "$PREFIX/lib/sarcasm"
cp -r "$(cd "$(dirname "$0")" && pwd)/sarcasm" "$PREFIX/lib/sarcasm"

cat > "$PREFIX/bin/sarcasm" <<EOF
#!$PREFIX/bin/minilute
local sarcasm = require("../lib/sarcasm/sarcasm")
local process = require("@lute/process")
process.exit(sarcasm.main(process.args))
EOF

chmod 755 "$PREFIX/bin/sarcasm"
