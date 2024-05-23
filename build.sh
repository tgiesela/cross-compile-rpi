#!/bin/bash
# Source https://wiki.osdev.org/GCC_Cross-Compiler
set -e

sudo apt update && sudo apt install -y gawk bison texinfo git flex build-essential rsync

mkdir -p src
mkdir -p build
mkdir -p extract
mkdir -p output

rm -rf output/*

source_arch=$(uname -m)
source_os=linux-gnu
source_vendor=$(uname -i)
source_triplet=$(gcc -dumpmachine)
target_arch=aarch64
target_os=linux-gnu
target_vendor=rpi
target_triplet=${target_arch}-${target_vendor}-${target_os}
export PREFIX="${HOME}/opt/cross"
export TARGET=${target_triplet}
export PATH=${PREFIX}/bin:${PATH}
OUTPUT=${HOME}/output/
CONFIG_OPTIONS="--disable-multilib"

function __wget(){
    if [ ! -e "${HOME}/downloads/$2" ] ; then
        echo "Downloading $1"
	wget -P ${HOME}/downloads $1
        __untar ${2} 
    fi
}

function __untar(){
    filename=$(basename -- "$1")
    extension="${filename##*.}"
    filename="${filename%.*}"
    mkdir -p ${HOME}/extract/$2
    if [ ${extension} == 'bz2' ] ; then
        tar -xf ${HOME}/downloads/$1 -C ${HOME}/extract/$2
    else
        tar -xzf ${HOME}/downloads/$1 -C ${HOME}/extract/$2
    fi
}

function __skip_configure(){
    if [ "$1" == "force" ] ; then
	rm -f config.status
        rm -f config.cache
        return 1
    else
	if [ -f "config.status" ] ; then
            return 0
        else
            return 1
        fi
    fi
}

function build_binutils(){
    #---------------
    # build binutils
    #---------------
    cd ${HOME}
    rsync -au --delete "$HOME/extract/binutils-${binutils_version}/" "$HOME/src/binutils"
    mkdir -p build/binutils
    cd build/binutils

    if ! __skip_configure $1 ; then
        ${HOME}/src/binutils/configure --target=${target_triplet} \
                                       --prefix=${PREFIX} \
                                       ${CONFIG_OPTIONS} \
                                        > $OUTPUT/configure_binutils.txt
    fi
    make > $OUTPUT/make_binutils.txt
    make install > $OUTPUT/make_install_binutils.txt
}

function install_kernel_headers(){
    #------------------------------
    # Install target kernel headers
    #------------------------------
    cd ${HOME}
    rsync -au --delete "$HOME/extract/linux-${target_kernel_version}/" "$HOME/src/linux"

    cd src/linux
    make ARCH=arm64 \
         CROSS_COMPILE=${TARGET} \
         INSTALL_HDR_PATH=${PREFIX}/${TARGET} \
 	 headers_install > $OUTPUT/make_headers_install.txt
}
function patch_libsanitizer(){
    touch asan_linux_cpp.patch
#   First create the patch file
    cat << EOF > asan_linux_cpp.patch
--- src/gcc/libsanitizer/asan/asan_linux.cpp    2024-05-07 06:51:41.000000000 +0000
+++ asan_linux.cpp      2024-05-21 16:54:47.434811913 +0000
@@ -78,6 +78,10 @@
 asan_rt_version_t __asan_rt_version;
 }

+#ifndef PATH_MAX
+#define PATH_MAX 4096
+#endif
+
 namespace __asan {

 void InitializePlatformInterceptors() {}

EOF
    ASANLINUXCC=${HOME}/src/gcc/libsanitizer/asan/asan_linux.cpp
    if [ ! -f "$ASANLINUXCC".orig ]; then
       echo "Patching $ASANLINUXCC ..."
       patch -b "$ASANLINUXCC" asan_linux_cpp.patch || exit 1
       echo "$ASANLINUXCC has been PATCHED! ..."
       echo "Backup of original: $ASANLINUXCC.orig ..."
       sleep 10
    fi
}

function build_gcc_1(){
    #-------------
    # build gcc   
    #-------------
    rsync -au --delete "$HOME/extract/gcc-${gcc_version}/" "$HOME/src/gcc"

    cd ${HOME}/src/gcc
    contrib/download_prerequisites
    rm *.tar.*
    cd ${HOME}
    which -- $TARGET-as || echo $TARGET-as is not in the PATH 

    patch_libsanitizer

    mkdir -p ${HOME}/build/gcc
    cd ${HOME}/build/gcc

    if ! __skip_configure $1 ; then
       ${HOME}/src/gcc/configure --target=${target_triplet} \
                                 --prefix=${PREFIX} \
                                 --enable-languages=c,c++ \
				 ${CONFIG_OPTIONS} \
                                 > $OUTPUT/configure_gcc.txt
    fi
    make all-gcc > $OUTPUT/make_all_gcc.txt
    make install-gcc > $OUTPUT/make_install_gcc.txt
}
function build_gcc_2(){
    #----------------
    # Second step gcc
    #----------------
    cd ${HOME}/build/gcc
    make all-target-libgcc > $OUTPUT/make_all_target_libgcc.txt
    make install-target-libgcc > $OUTPUT/make_install_target_libgcc.txt
}
function build_glibc_1(){
    #-------------------
    # build glibc step-1
    #-------------------
    echo PATH=${PATH}
    cd ${HOME}
    rsync -au --delete "$HOME/extract/glibc-${glibc_version}/" "$HOME/src/glibc"
    mkdir -p build/glibc
    cd build/glibc
    if ! __skip_configure $1 ; then
        ${HOME}/src/glibc/configure --prefix=${PREFIX}/${TARGET} \
     			            --build=$MACHTYPE \
			            --host=${target_triplet} \
                                    --target=${target_triplet} \
                                    --with-headers=${PREFIX}/${TARGET}/include \
			    	    ${CONFIG_OPTIONS} \
                                    libc_cv_forced_unwind=yes \
                                    > $OUTPUT/configure_glibc.txt
    fi

    make install-bootstrap-headers=yes install-headers > $OUTPUT/make_install_bootstrap_headers.txt
    make -j4 csu/subdir_lib > $OUTPUT/make_csu_subdir_lib.txt
    install csu/crt1.o csu/crti.o csu/crtn.o ${PREFIX}/${TARGET}/lib
    ${TARGET}-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o ${PREFIX}/${TARGET}/lib/libc.so
    touch ${PREFIX}/${TARGET}/include/gnu/stubs.h
}
function build_stdc_lib(){
    #--------------------
    # build glibc stdclib
    #--------------------
    cd ${HOME}
    mkdir -p build/glibc
    cd build/glibc
    make > $OUTPUT/make_stdc_lib.txt
    make install > $OUTPUT/make_install_stdc_lib.txt
}
function build_stdcpp_lib(){
    cd ${HOME}
    cd build/gcc
    make > $OUTPUT/make_all_host.txt
    make install > $OUTPUT/make_install_stdcpp_lib.txt
}
function init_gcc_repo(){
    if [ -d $HOME/src/gcc/.git ] ; then
         cd $HOME/src/gcc
         git pull
    else
         cd $HOME/src
         git clone git://gcc.gnu.org/git/gcc.git gcc
    fi
    git checkout ${gcc_git_branch}
}

gcc_version=14.1.0	  # Gnu C++ compiler
gcc_git_branch=releases/gcc-14
binutils_version=2.42     # binutils (ar, ld etc)
glibc_version=2.39	  # glibc
target_kernel_version=6.6 # version for raspbian
debian_version=12.0       # raspbian debian version
gdb_version=14.2          # gdb version
raspbian_version=rpi-6.6.y
gcc_tarfile=gcc-${gcc_version}.tar.gz
binutils_tarfile=binutils-${binutils_version}.tar.gz
glibc_tarfile=glibc-${glibc_version}.tar.gz
target_kernel_tarfile=linux-${target_kernel_version}.tar.gz
gdb_tarfile=gdb-${gdb_version}.tar.gz

cd ${HOME}

#init_gcc_repo
__wget https://mirror.koddos.net/gcc/releases/gcc-${gcc_version}/${gcc_tarfile} ${gcc_tarfile}
__wget https://ftp.gnu.org/gnu/binutils//${binutils_tarfile} ${binutils_tarfile}
__wget http://ftpmirror.gnu.org/glibc/${glibc_tarfile} ${glibc_tarfile}
__wget https://www.kernel.org/pub/linux/kernel/v6.x/${target_kernel_tarfile} ${target_kernel_tarfile}

install_kernel_headers
build_binutils
build_gcc_1
build_glibc_1 force
build_gcc_2
build_stdc_lib
build_stdcpp_lib


