#!/bin/bash -x
set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# This is a WIP script to be build a minimal BCC rootfs image It works by using
# a 2-chroot technique. The first chroot is used to build BCC, The second
# chroot is used to install BCC in. The whole image should take around 35MB
# after compression.

SPATH="$(dirname "$(readlink -f "$0")")"

DIST=buster
RUN_DIR=$SPATH/bcc.run
BLD_DIR=$SPATH/bcc.bld

############## FIRST STAGE - Build the BCC build chroot
rm -rf $RUN_DIR && mkdir -p $RUN_DIR
rm -rf $BLD_DIR && mkdir -p $BLD_DIR

# Build a chroot for the build system to build BCC into
sudo qemu-debootstrap \
    --arch arm64 \
    --include=procps,git,clang-7,cmake,llvm-7-dev,libclang-7-dev,libelf-dev,libfl-dev,libunwind-dev,libdw-dev,git,libtool,autoconf,make,cmake,iperf,arping,ethtool,flex,bison,python,clang-7,python-netaddr,python-pyroute2 \
    --variant=minbase $DIST $BLD_DIR http://ftp.us.debian.org/debian

pushd $BLD_DIR
git clone --recurse-submodules https://github.com/iovisor/bcc.git bcc-master
popd

cp $SPATH/build-on-target.sh $BLD_DIR/
sudo chroot $BLD_DIR /build-on-target.sh

################ SECOND STAGE - BUILD the run chroot
qemu-debootstrap \
   --arch arm64 \
   --include=libelf1,python,python-netaddr,python-pyroute2 \
   --variant=minbase $DIST $RUN_DIR http://ftp.us.debian.org/debian

# Sync the built BCC from the build chroot onto the run chroot
rsync -rav $BLD_DIR/bcc-master/build/future-usr/ $RUN_DIR/usr/

# Clean up the chroot for whatever is not needed
find   $RUN_DIR -name "*.a" |xargs rm -rf
rm -rf $RUN_DIR/lib/udev/*
rm -rf $RUN_DIR/var/lib/apt/lists/*
rm -rf $RUN_DIR/var/cache/apt/archives/*deb

rm -rf $RUN_DIR/var/cache/debconf/*
rm -rf $RUN_DIR/var/cache/apt/*.bin

rm -rf $RUN_DIR/usr/share/locale/*
rm -rf $RUN_DIR/usr/lib/share/locale/*
rm -rf $RUN_DIR/usr/share/doc/*
rm -rf $RUN_DIR/usr/lib/share/doc/*
rm -rf $RUN_DIR/usr/share/ieee-data/*
rm -rf $RUN_DIR/usr/lib/share/ieee-data/*
rm -rf $RUN_DIR/usr/share/man/*
rm -rf $RUN_DIR/usr/lib/share/man/*

rm -rf $RUN_DIR/usr/lib/*/perl
rm -rf $RUN_DIR/usr/bin/perl*
rm -rf $RUN_DIR/usr/lib/perl*
rm -rf $RUN_DIR/usr/share/*perl*

rm -rf $RUN_DIR/usr/bin/qemu-aarch64-static
rm -rf $RUN_DIR/var/cache/apt/*bin
rm -rf $RUN_DIR/usr/lib/file/magic.mgc

tar -Jc -C $RUN_DIR -f bcc-rootfs.txz .
