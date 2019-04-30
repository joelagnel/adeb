#!/bin/bash

# Utility to build kernel headers tar/zip file
# must be run from the top level of a kernel source directory
# and supplied an output file name(add supplied a kbuildout
# full path if you need)

MKTEMP=0; if [[ -z ${TDIR+x} ]]  || [[ ! -d "${TDIR}" ]]; then
	TDIR=`mktemp -d`; MKTEMP=1; fi
rm -rf $TDIR/*
TDIR_ABS=$( cd "$TDIR" ; pwd -P )


if [ $# -ne 1 ] && [ $# -ne 2 ]; then
  echo "usage: packheaders.sh <output file name>"
  echo "usage: or packheaders.sh <output file name> <kbuildout full path>"
  exit 0
fi

mkdir -p $TDIR_ABS/kernel-headers

find arch -name include -type d -print | xargs -n1 -i: find : -type f -exec cp --parents {} $TDIR_ABS/kernel-headers/ \;
find include -exec cp --parents {} $TDIR_ABS/kernel-headers/ 2> /dev/null \;
if [ $# -eq 2 ]; then
    cd $2/obj/KERNEL
    find arch -name include -type d -print | xargs -n1 -i: find : -type f -exec cp --parents {} $TDIR_ABS/kernel-headers/ \;
    find include -exec cp --parents {} $TDIR_ABS/kernel-headers/ 2> /dev/null \;
    cd -
fi
tar -zcf $1 --directory=$TDIR_ABS kernel-headers

zip -r $1.zip $1
rm -rf $TDIR/*; if [ $MKTEMP -eq 1 ]; then rm -rf $TDIR; fi
