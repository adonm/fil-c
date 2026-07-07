#!/bin/bash

set -e
set -x

ulimit -c unlimited

test "x$FILCSRC" != "x"
test -d $FILCSRC
test -d $FILCSRC/projects

test $EUID -eq `stat -c %u $FILCSRC`

cd $FILCSRC

rm -vf projects/*/pizlonated-*.tar.gz
./package-source.sh projects/abseil-cpp-20260107.1 pizlonated-abseil
./package-source.sh projects/cairo-1.18.0 pizlonated-cairo
./package-source.sh projects/libxslt-1.1.42 pizlonated-libxslt
./package-source.sh projects/zip-3.0 pizlonated-zip
