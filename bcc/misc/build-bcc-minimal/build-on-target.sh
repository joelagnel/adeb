#!/bin/bash
# This is run in the bcc directory of the chroot

cd bcc-master
rm -rf build && mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=./future-usr -DCMAKE_C_COMPILER=clang-7 -DCMAKE_CXX_COMPILER=clang++-7
make -j90
make install
