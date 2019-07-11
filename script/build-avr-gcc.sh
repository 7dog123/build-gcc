cd ${BASE}/build/

if [ ! -z ${AVRLIBC_VERSION} ]; then
  if [ ! -e avr-libc-${AVRLIBC_VERSION}/avr-libc-unpacked ]; then
    echo "Unpacking avr-libc..."
    untar ${AVRLIBC_ARCHIVE}
    cd avr-libc-${AVRLIBC_VERSION}/
    untar ${AVRLIBC_DOC_ARCHIVE}
    touch avr-libc-unpacked
    cd ..
  fi
  cd avr-libc-${AVRLIBC_VERSION}/
  #${SUDO} mkdir -p ${PREFIX}/${TARGET}/sys-include/
  #${SUDO} cp -rv include/* ${PREFIX}/${TARGET}/sys-include/ | exit 1
  ${SUDO} mkdir -p ${PREFIX}/${TARGET}/share/man/
  ${SUDO} cp -rv man/* ${PREFIX}/${TARGET}/share/man/ | exit 1
  cd ..
fi

if [ ! -z ${GCC_VERSION} ]; then
  if [ ! -e gcc-${GCC_VERSION}/gcc-unpacked ]; then
    echo "Unpacking gcc..."
    untar ${GCC_ARCHIVE}

    # download mpc/gmp/mpfr/isl libraries
    echo "Downloading gcc dependencies"
    cd gcc-${GCC_VERSION}/
    ./contrib/download_prerequisites
    touch gcc-unpacked
    cd -
  fi

  echo "Building gcc"

  mkdir -p gcc-${GCC_VERSION}/build-${TARGET}
  cd gcc-${GCC_VERSION}/build-${TARGET} || exit 1

  TEMP_CFLAGS="$CFLAGS"
  export CFLAGS="$CFLAGS $GCC_EXTRA_CFLAGS"
  
  GCC_CONFIGURE_OPTIONS+=" --target=${TARGET} --prefix=${PREFIX} ${HOST_FLAG} ${BUILD_FLAG}
                           --enable-languages=${ENABLE_LANGUAGES} --with-avrlibc --with-headers"
  strip_whitespace GCC_CONFIGURE_OPTIONS

  if [ ! -e configure-prefix ] || [ ! "`cat configure-prefix`" == "${GCC_CONFIGURE_OPTIONS}" ]; then
    rm -rf *
    rm -rf ${BASE}/build/avr-libc-${AVRLIBC_VERSION}/build-${TARGET}/*
    ../configure ${GCC_CONFIGURE_OPTIONS} || exit 1
    echo ${GCC_CONFIGURE_OPTIONS} > configure-prefix
  else
    echo "Note: gcc already configured. To force a rebuild, use: rm -rf $(pwd)"
    sleep 5
  fi

  ${MAKE} -j${MAKE_JOBS} all-gcc || exit 1
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install-gcc || exit 1

  export CFLAGS="$TEMP_CFLAGS"
fi

cd ${BASE}/build/

if [ ! -z ${AVRLIBC_VERSION} ]; then
  mkdir -p avr-libc-${AVRLIBC_VERSION}/build-${TARGET}
  cd avr-libc-${AVRLIBC_VERSION}/build-${TARGET} || exit 1
  
  AVRLIBC_CONFIGURE_OPTIONS+=" --host=${TARGET} --prefix=${PREFIX} ${BUILD_FLAG}"
  strip_whitespace AVRLIBC_CONFIGURE_OPTIONS
  
  if [ ! -e configure-prefix ] || [ ! "`cat configure-prefix`" == "${AVRLIBC_CONFIGURE_OPTIONS}" ]; then
    rm -rf *
    CC=avr-gcc ../configure ${AVRLIBC_CONFIGURE_OPTIONS} || exit 1
    echo ${AVRLIBC_CONFIGURE_OPTIONS} > configure-prefix
  else
    echo "Note: avr-libc already configured. To force a rebuild, use: rm -rf $(pwd)"
    sleep 5
  fi
  
  ${MAKE} -j${MAKE_JOBS} || exit 1
  [ ! -z $MAKE_CHECK ] && ${MAKE} -j${MAKE_JOBS} -s check | tee ${BASE}/tests/avr-libc.log
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install || exit 1
fi

cd ${BASE}/build/

if [ ! -z ${GCC_VERSION} ]; then
  cd gcc-${GCC_VERSION}/build-${TARGET} || exit 1
  
  ${MAKE} -j${MAKE_JOBS} || exit 1
  [ ! -z $MAKE_CHECK_GCC ] && ${MAKE} -j${MAKE_JOBS} -s check-gcc | tee ${BASE}/tests/gcc.log
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install-strip || \
  ${SUDO} ${MAKE} -j${MAKE_JOBS} install-strip || exit 1
  ${SUDO} ${MAKE} -j${MAKE_JOBS} -C mpfr install
  
  ${SUDO} rm -f ${PREFIX}/${TARGET}/etc/gcc-*-installed
  ${SUDO} touch ${PREFIX}/${TARGET}/etc/gcc-${GCC_VERSION}-installed
fi
