#!/bin/bash

set -e
set -x

ulimit -c unlimited

cd /sources

# X11 libraries
for pkg in util-macros-1.20.1 xorgproto-2024.1 xtrans-1.5.0 xcb-proto-1.17.0 \
           libXau-1.0.11 libXdmcp-1.1.4 libxcb-1.17.0 libX11-1.8.10 \
           libICE-1.1.1 libSM-1.2.4 libXt-1.3.0 \
           libXext-1.3.6 libXrender-0.9.11 libXrandr-1.5.4 libXinerama-1.1.5; do
    rm -rf $pkg
    tar -xf $pkg.tar.xz
    cd $pkg
    ./configure --prefix=/usr --sysconfdir=/etc
    make -j$(nproc)
    make install
    cd ..
    rm -rf $pkg
done
hash -r

./build_postlc6_chroot_project_libepoxy.sh
hash -r

./build_postlc6_chroot_project_cairo.sh
hash -r

./build_postlc6_chroot_project_glstub.sh
hash -r

./build_postlc6_chroot_project_abseil.sh
hash -r

./build_postlc6_chroot_project_boost.sh
hash -r

./build_postlc6_chroot_project_libxslt.sh
hash -r

./build_postlc6_chroot_project_zip.sh
hash -r

./build_postlc6_chroot_project_unzip.sh
hash -r

./build_postlc6_chroot_project_libreoffice.sh
hash -r
