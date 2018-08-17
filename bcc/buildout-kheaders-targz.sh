#! /bin/bash

script_full_path=$( cd "$(dirname "$0")" ; pwd -P )

if [ $# -ne 2 ]; then
	echo "illegal number of parameters, usage: $0 KBUILD_OUTPUT full_path_out.tar.gz"
	exit 1
fi

# Please provide absolute paths
KBUILD_OUTPUT=$1
OUT_TAR=$2
OUT_KHDIR=`mktemp -d`

if [ ! -d $OUT_KHDIR ]; then
	>&2 echo ""
	>&2 echo "failed to create temporary directory"
	>&2 echo "exit"
	exit 1
fi

KBUILD_OUTPUT="$(dirname $(readlink -e $KBUILD_OUTPUT))/$(basename $KBUILD_OUTPUT)"
if [ ! -d "$KBUILD_OUTPUT" ]; then
	echo "Kernel build out-of-tree directory couldn't be found"
	exit 3
fi

cd $KBUILD_OUTPUT

if [ ! -f include/generated/autoconf.h -o ! -d source ]; then
	>&2 echo ""
	>&2 echo "The kernel isn't built out-of-tree"
	>&2 echo "One example to build out-of-tree is:"
	>&2 echo "export KBUILD_OUTPUT=${KBUILD_OUTPUT}"
	>&2 echo "mkdir -p ${KBUILD_OUTPUT}"
	>&2 echo "make -C kernel_source_dir defconfig"
	>&2 echo "make -C kernel_source_dir"
	>&2 echo ""
	exit 1
fi

rm -rf $OUT_KHDIR
mkdir -p $OUT_KHDIR/{include,arch}

cp -arf source/include $OUT_KHDIR/
cp -arf include/* $OUT_KHDIR/include/

for dirdoc in `find arch/ -maxdepth 1  -type d | xargs -I '{}' basename {} | grep -v arch`
do
	if [ -d source/arch/$dirdoc ]
	then
		cp -arf source/arch/$dirdoc $OUT_KHDIR/arch
	fi
done

for filedoc in `find arch -name '*.h'`; do dir_base=$(dirname ${filedoc}); mkdir -p $OUT_KHDIR/$dir_base; cp $filedoc $OUT_KHDIR/$dir_base; done

tar -czf $OUT_TAR -C $OUT_KHDIR .
rm -rf $OUT_KHDIR
