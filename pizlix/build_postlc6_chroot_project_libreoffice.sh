#!/bin/bash
set -e
set -x

# LibreOffice build script for Pizlix (Fil-C)
# This script is NOT linked into the main build chain - run manually
# It assumes all dependencies (abseil, boost, libxslt, X11 libs, etc.) are already installed

rm -rf libreoffice-24.8.0.3
tar -xf libreoffice-24.8.0.3.tar.xz
cd libreoffice-24.8.0.3

# Apply BLFS boost fix patch
patch -Np1 -i ../libreoffice-24.8.0.3-boost_fixes-1.patch

# Apply Fil-C patch
patch -Np1 -i ../libreoffice-filc.patch

# Fix zlib linking bug (from BLFS)
sed -i '/icuuc \\/a zlib\\' writerperfect/Library_wpftdraw.mk

# Fix desktop integration (from BLFS)
sed -e "/gzip -f/d" \
    -e "s|.1.gz|.1|g" \
    -i bin/distro-install-desktop-integration

sed -e "/distro-install-file-lists/d" -i Makefile.in

# Set up external tarballs
install -dm755 external/tarballs
ln -sv ../libreoffice-dictionaries-24.8.0.3.tar.xz external/tarballs/
ln -sv ../libreoffice-help-24.8.0.3.tar.xz external/tarballs/
ln -sv ../libreoffice-translations-24.8.0.3.tar.xz external/tarballs/

# Fix sha256sum (Fil-C's shasum crashes)
sed -i 's/shasum -a 256/sha256sum/g' configure.ac || true

# Configure
./autogen.sh $(cat ../libreoffice-filc.autogen.flags | tr '\n' ' ')

# Fetch external tarballs
make fetch

# Build (use -j16 to avoid OOM on Fil-C)
make build -j16

# Install
make distro-pack-install

cd ..
rm -rf libreoffice-24.8.0.3
