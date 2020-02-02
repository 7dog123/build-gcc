#!/usr/bin/env bash

source script/init.sh

PACKAGE_SOURCES="avr binutils common"
source script/parse-args.sh

TARGET="avr"

prepend BINUTILS_CONFIGURE_OPTIONS "--disable-werror
                                    --disable-nls"

prepend GCC_CONFIGURE_OPTIONS "--disable-nls
                               --enable-version-specific-runtime-libs
                               --enable-fat"

prepend GDB_CONFIGURE_OPTIONS "--disable-werror
                               --disable-nls"

prepend AVRLIBC_CONFIGURE_OPTIONS "--enable-device-lib"

DEPS=""
[ ! -z ${GCC_VERSION} ] && DEPS+=" avr-libc binutils"
[ ! -z ${BINUTILS_VERSION} ] && DEPS+=" "
[ ! -z ${GDB_VERSION} ] && DEPS+=" "
[ ! -z ${AVRLIBC_VERSION} ] && DEPS+=" gcc binutils"
[ ! -z ${AVRDUDE_VERSION} ] && DEPS+=" "
[ ! -z ${AVARICE_VERSION} ] && DEPS+=" "
[ ! -z ${SIMULAVR_VERSION} ] && DEPS+=" "

source ${BASE}/script/download.sh

source ${BASE}/script/build-tools.sh

cd ${BASE}/build/ || exit 1

if [ ! -z ${SIMULAVR_VERSION} ]; then
  download_git https://git.savannah.nongnu.org/git/simulavr.git master
fi

if [ ! -z ${BINUTILS_VERSION} ]; then
  if [ ! -e binutils-${BINUTILS_VERSION}/binutils-unpacked ]; then
    echo "Unpacking binutils..."
    untar ${BINUTILS_ARCHIVE} || exit 1
    touch binutils-${BINUTILS_VERSION}/binutils-unpacked
  fi

  cd binutils-${BINUTILS_VERSION} || exit 1
  source ${BASE}/script/build-binutils.sh
fi

source ${BASE}/script/build-avr-gcc.sh

cd ${BASE}/build/

if [ ! -z ${SIMULAVR_VERSION} ]; then
  echo "Building simulavr"
  cd simulavr/ || exit 1
  ./bootstrap || exit 1
  #mkdir -p build-avr/
  #cd build-avr/ || exit 1
  make distclean
  ./configure --prefix=${PREFIX} || exit 1
  ${MAKE} -j${MAKE_JOBS} || exit 1
  [ ! -z $MAKE_CHECK ] && ${MAKE} -j${MAKE_JOBS} -s check | tee ${BASE}/tests/simulavr.log
  echo "Installing simulavr"
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install || exit 1
  cd ${BASE}/build/ || exit 1
fi

if [ ! -z ${AVARICE_VERSION} ]; then
  echo "Building AVaRICE"
  untar ${AVARICE_ARCHIVE}
  cd avarice-${AVARICE_VERSION}
  [ -e ${BASE}/patch/patch-avarice-${AVARICE_VERSION}.txt ] && patch -p1 -u < ${BASE}/patch/patch-avarice-${AVARICE_VERSION}.txt || exit 1
  mkdir -p build-avr/
  cd build-avr/ || exit 1
  rm -rf *
  ../configure --prefix=${PREFIX} || exit 1
  ${MAKE} -j${MAKE_JOBS} || exit 1
  [ ! -z $MAKE_CHECK ] && ${MAKE} -j${MAKE_JOBS} -s check | tee ${BASE}/tests/avarice.log
  echo "Installing AVaRICE"
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install || exit 1
  cd ${BASE}/build/ || exit 1
fi

if [ ! -z ${AVRDUDE_VERSION} ]; then
  echo "Building AVRDUDE"
  untar ${AVRDUDE_ARCHIVE}
  cd avrdude-${AVRDUDE_VERSION}
  mkdir -p build-avr/
  cd build-avr/ || exit 1
  rm -rf *
  ../configure --prefix=${PREFIX} || exit 1
  ${MAKE} -j${MAKE_JOBS} || exit 1
  [ ! -z $MAKE_CHECK ] && ${MAKE} -j${MAKE_JOBS} -s check | tee ${BASE}/tests/avrdude.log
  echo "Installing AVRDUDE"
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install || exit 1
  cd ${BASE}/build/ || exit 1
fi

source ${BASE}/script/build-gdb.sh

source ${BASE}/script/finalize.sh
