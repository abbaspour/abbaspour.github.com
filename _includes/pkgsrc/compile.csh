#!/bin/csh
MAKE_JOBS=`sysctl -n hw.ncpu` 
STRIPFLAG=-s 
CC=/usr/bin/clang
CFLAGS="-pipe -march=x86_64 -fomit-frame-pointer -fno-stack-protector -fstrict-aliasing"
./bootstrap --prefix=/Volumes/pkgsrc/pkg --pkgdbdir=/Volumes/pkgsrc/pkg/db \
            --abi=64 --compiler=clang --unprivileged

