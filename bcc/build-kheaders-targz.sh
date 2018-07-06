#!/bin/bash
KHEADERS_TMP=/tmp/kheaders.tar

script_full_path=$( cd "$(dirname "$0")" ; pwd -P )

if [ $# -lt 2 ]; then
    >&2 echo "illegal number of parameters, usage: ./build out.tar.gz KERNEL_PATH ..."
    exit 1
fi

# Please provide absolute paths
OUT_TAR=$1
shift

rm -f $KHEADERS_TMP

while (( "$#" )); do
  KERNEL_SRC_PATH="$(dirname $(readlink -e $1))/$(basename $1)"
    if [ ! -d "$KERNEL_SRC_PATH" ]; then
        >&2 echo "Kernel src directory '$KERNEL_SRC_PATH' couldn't be found"
        exit 2
    fi

    pushd $KERNEL_SRC_PATH > /dev/null
    find arch -ipath "*/include/*" -type f -not -empty -exec tar -rf $KHEADERS_TMP {} +
    findret=$?
    if [ $findret -ne 0 ]; then
        >&2 echo "Kernel src directory '$KERNEL_SRC_PATH' does not contain expected 'arch' subdirectory"
        exit $findret
    fi
    find include -type f -not -empty -exec tar -rf $KHEADERS_TMP {} +
    findret=$?
    if [ $findret -ne 0 ]; then
        >&2 echo "Kernel src directory '$KERNEL_SRC_PATH' does not contain expected 'include' subdirectory"
        exit $findret
    fi
    popd > /dev/null

    shift
done

# Check that tar contains expected 'include/generated/autoconf.h'
tar -tf $KHEADERS_TMP | grep "include/generated/autoconf.h" > /dev/null 2>&1
retgrep=$?
if [ $retgrep -ne 0 ]; then
    >&2 echo ""
    >&2 echo "The kernel sources you pointed to aren't configured and built."
    >&2 echo "Please atleast run in your kernel sources:"
    >&2 echo $'make defconfig\nmake'
    >&2 echo $'\nNote: You dont need to do the full build since headers are generated early on.\n'
    >&2 echo ""
    exit $retgrep
fi

gzip -c $KHEADERS_TMP > $OUT_TAR
gzipret=$?
if [ $gzipret -ne 0 ]; then
    >&2 echo "Failed to compress kernel headers from '$KHEADERS_TMP' to '$OUT_TAR'"
    exit $gzipret
fi

rm -f $KHEADERS_TMP

