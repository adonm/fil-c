#!/bin/bash

set -e
set -x

ulimit -c unlimited

test $EUID -eq 0
id -u lfs

export LFS=/mnt/lfs

test -d $LFS

export FILCSRC=..
test -d $FILCSRC/projects

test -e $LFS/sources/lfsbuildstate
lfsbuildstate=`cat $LFS/sources/lfsbuildstate`
test "x$lfsbuildstate" = "xpostlc5"

SRCDIR=$PWD

echo "postlc6-part" > $LFS/sources/lfsbuildstate

FILCOWNER=`stat -c %U $FILCSRC`
id -u $FILCOWNER
su $FILCOWNER ./build_postlc6_sub1_packaging.sh

./build_unmount.sh
./build_mount.sh

cp -v $FILCSRC/projects/*/pizlonated-*.tar.gz $LFS/sources
cp -v build_postlc6_sub2_chroot.sh $LFS/sources
cp -v boost_1_86_0.tar.bz2 $LFS/sources
cp -v boost-filc.patch $LFS/sources
cp -v zip30.tar.gz $LFS/sources
cp -v unzip60.tar.gz $LFS/sources
cp -v util-macros-*.tar.xz $LFS/sources
cp -v xorgproto-*.tar.xz $LFS/sources
cp -v xtrans-*.tar.xz $LFS/sources
cp -v xcb-proto-*.tar.xz $LFS/sources
cp -v libxcb-*.tar.xz $LFS/sources
cp -v libX*.tar.xz $LFS/sources
cp -v libICE-*.tar.xz $LFS/sources
cp -v libSM-*.tar.xz $LFS/sources
cp -v libepoxy-1.5.10.tar.xz $LFS/sources
cp -v gl_stub.c $LFS/sources
cp -v libreoffice-24.8.0.3.tar.xz $LFS/sources
cp -v libreoffice-dictionaries-24.8.0.3.tar.xz $LFS/sources
cp -v libreoffice-help-24.8.0.3.tar.xz $LFS/sources
cp -v libreoffice-translations-24.8.0.3.tar.xz $LFS/sources
cp -v libreoffice-24.8.0.3-boost_fixes-1.patch $LFS/sources
cp -v libreoffice-filc.patch $LFS/sources
cp -v libreoffice-filc.autogen.flags $LFS/sources
cp -v build_postlc6_chroot_project_*.sh $LFS/sources

./build_chroot_late.sh /sources/build_postlc6_sub2_chroot.sh

echo "postlc6" > $LFS/sources/lfsbuildstate

./build_unmount.sh

cd $LFS
tar -czpf $SRCDIR/lfs-postlc6.tar.gz --exclude='var/coredumps/*' .

echo Post-libc part 6 OK
