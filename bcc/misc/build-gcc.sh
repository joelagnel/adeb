#!/bin/bash -x
set -e

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# This is a WIP script to be build a minimal GCC rootfs image
SPATH="$(dirname "$(readlink -f "$0")")"

DIST=buster
BLD_DIR=$SPATH/gcc.bld

rm -rf $BLD_DIR && mkdir -p $BLD_DIR

# Build a chroot for the build system to build BCC into
sudo qemu-debootstrap \
    --arch amd64 \
    --include=gcc,make,libc6-dev \
    --variant=minbase $DIST $BLD_DIR http://ftp.us.debian.org/debian

# Clean up the chroot for whatever is not needed
# find   $BLD_DIR -name "*.a" |xargs rm -rf
rm -rf $BLD_DIR/lib/udev/*
rm -rf $BLD_DIR/var/lib/apt/lists/*
rm -rf $BLD_DIR/var/cache/apt/archives/*deb

rm -rf $BLD_DIR/var/cache/debconf/*
rm -rf $BLD_DIR/var/cache/apt/*.bin

rm -rf $BLD_DIR/usr/share/locale/*
rm -rf $BLD_DIR/usr/lib/share/locale/*
rm -rf $BLD_DIR/usr/share/doc/*
rm -rf $BLD_DIR/usr/lib/share/doc/*
rm -rf $BLD_DIR/usr/share/ieee-data/*
rm -rf $BLD_DIR/usr/lib/share/ieee-data/*
rm -rf $BLD_DIR/usr/share/man/*
rm -rf $BLD_DIR/usr/lib/share/man/*

rm -rf $BLD_DIR/usr/lib/*/perl
rm -rf $BLD_DIR/usr/bin/perl*
rm -rf $BLD_DIR/usr/lib/perl*
rm -rf $BLD_DIR/usr/share/*perl*

rm -rf $BLD_DIR/usr/bin/qemu-aarch64-static
rm -rf $BLD_DIR/var/cache/apt/*bin
rm -rf $BLD_DIR/usr/lib/file/magic.mgc

tar -Jc -C $BLD_DIR -f gcc-rootfs.txz .
