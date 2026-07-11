#!/bin/bash

set -e
set -x

rm -rf graphite2-1.3.14
tar -xf graphite2-1.3.14.tgz
cd graphite2-1.3.14

# Apply Fil-C patch (skip realloc in Pass::readRules that breaks Fil-C
# pointer capabilities)
patch -Np1 -i ../graphite2-filc.patch

mkdir -v build
cd build
cmake -D CMAKE_INSTALL_PREFIX=/usr ..
make
make install
cd ../..
rm -rf graphite2-1.3.14
