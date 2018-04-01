#!/bin/bash
script_full_path=$( cd "$(dirname "$0")" ; pwd -P )

if [ $# -ne 2 ]; then
    echo "illegal number of parameters, usage: ./build KERNEL_PATH out.tar.gz"
    exit 1
fi

# Please provide absolute paths
KERNEL_PATH=$1
OUT_TAR=$2

KERNEL_PATH="$(dirname $(readlink -e $KERNEL_PATH))/$(basename $KERNEL_PATH)"
if [ ! -d "$KERNEL_PATH" ]; then
        echo "Kernel directory couldn't be found"
        exit 3
fi

kdir=$(basename $KERNEL_PATH)

cd $KERNEL_PATH/..
find $kdir/arch -name include -type d -print | xargs -n1 -i: find : -type f > /tmp/kernel-headers.h
find $kdir/include >> /tmp/kernel-headers.h

grep "include/generated/autoconf.h" /tmp/kernel-headers.h > /dev/null 2>&1
retgrep=$?
if [ $retgrep -ne 0 ]; then
	echo ""
	echo "The kernel sources at ${KERNEL_PATH} you pointed to aren't configured and built."
	echo "Please atleast run in your kernel sources:"
	echo $'make defconfig\nmake'
	echo $'\nNote: You dont need to do the full build since headers are generated early on.\n'
	exit $retgrep
fi

cat /tmp/kernel-headers.h | tar -zcf $OUT_TAR -T -
# rm /tmp/kernel-headers.h
