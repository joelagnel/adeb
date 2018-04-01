#!/bin/bash -x
script_full_path=$( cd "$(dirname "$0")" ; pwd -P )

if [ $# -ne 1 ]; then
    echo "illegal number of parameters, usage: ./build-kernel-headers-tar.sh KERNEL_PATH"
    exit 1
fi

KERNEL_PATH=$1
KERNEL_PATH="$(dirname $(readlink -e $KERNEL_PATH))/$(basename $KERNEL_PATH)"
if [ ! -d "$KERNEL_PATH" ]; then
        echo "Kernel directory couldn't be found"
        exit 3
fi

kdir=$(basename $KERNEL_PATH)

cd $KERNEL_PATH/..
find $kdir/arch -name include -type d -print | xargs -n1 -i: find : -type f > /tmp/kernel-headers.h
find $kdir/include >> /tmp/kernel-headers.h

cat /tmp/kernel-headers.h | tar -zcf $KERNEL_PATH/../$kdir.tar.gz -T -
rm /tmp/kernel-headers.h
