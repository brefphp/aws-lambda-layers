# The container we build here contains everything needed to compile PHP.
# We build in here everything that is stable (e.g. system tools) so that we don't
# recompile them every time we change PHP.


# Lambda uses a custom AMI named Amazon Linux 2
# https://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html
# AWS provides a Docker image that we use here:
# https://github.com/amazonlinux/container-images/tree/amzn2
FROM public.ecr.aws/lambda/provided:al2-arm64


# Temp directory in which all compilation happens
WORKDIR /tmp


RUN set -xe \
    # Download yum repository data to cache
 && yum makecache \
    # Default Development Tools
 && yum groupinstall -y "Development Tools" --setopt=group_package_types=mandatory,default


# The default version of cmake is 2.8.12. We need cmake to build a few of
# our libraries, and at least one library requires a version of cmake greater than that.
# Needed to build:
# - libzip: minimum required CMAKE version 3.0.
RUN LD_LIBRARY_PATH= yum install -y cmake3
# Override the default `cmake`
RUN ln -s /usr/bin/cmake3 /usr/bin/cmake

# Use the bash shell, instead of /bin/sh
# Why? We need to document this.
SHELL ["/bin/bash", "-c"]

# We need a base path for all the sourcecode we will build from.
ENV BUILD_DIR="/tmp/build"

# Target installation path for all the packages we will compile
ENV INSTALL_DIR="/tmp/bref"

# We need some default compiler variables setup
ENV PKG_CONFIG_PATH="${INSTALL_DIR}/lib64/pkgconfig:${INSTALL_DIR}/lib/pkgconfig" \
    PKG_CONFIG="/usr/bin/pkg-config" \
    PATH="${INSTALL_DIR}/bin:${PATH}"

ENV LD_LIBRARY_PATH="${INSTALL_DIR}/lib64:${INSTALL_DIR}/lib"

# Enable parallelism by default for make and cmake (like make -j)
# See https://stackoverflow.com/a/50883540/245552
ENV CMAKE_BUILD_PARALLEL_LEVEL=4
ENV MAKEFLAGS='-j4'

# Ensure we have all the directories we require in the container.
RUN mkdir -p ${BUILD_DIR}  \
    ${INSTALL_DIR}/bin \
    ${INSTALL_DIR}/doc \
    ${INSTALL_DIR}/etc/php \
    ${INSTALL_DIR}/etc/php/conf.d \
    ${INSTALL_DIR}/include \
    ${INSTALL_DIR}/lib \
    ${INSTALL_DIR}/lib64 \
    ${INSTALL_DIR}/libexec \
    ${INSTALL_DIR}/sbin \
    ${INSTALL_DIR}/share


###############################################################################
# ZLIB
# https://github.com/madler/zlib/releases
# Needed for:
#   - openssl
#   - curl
#   - php
# Used By:
#   - xml2
ENV VERSION_ZLIB=1.2.13
ENV ZLIB_BUILD_DIR=${BUILD_DIR}/zlib
RUN set -xe; \
    mkdir -p ${ZLIB_BUILD_DIR}; \
    curl -Ls https://zlib.net/zlib-${VERSION_ZLIB}.tar.xz \
  | tar xJC ${ZLIB_BUILD_DIR} --strip-components=1
WORKDIR  ${ZLIB_BUILD_DIR}/
RUN set -xe; \
    make distclean \
 && CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure --prefix=${INSTALL_DIR} --64
RUN set -xe; \
    make install \
 && rm ${INSTALL_DIR}/lib/libz.a


###############################################################################
# OPENSSL
# https://github.com/openssl/openssl/releases
# Needs:
#   - zlib
# Needed by:
#   - curl
#   - php
ENV VERSION_OPENSSL=1.1.1s
ENV OPENSSL_BUILD_DIR=${BUILD_DIR}/openssl
ENV CA_BUNDLE_SOURCE="https://curl.se/ca/cacert.pem"
ENV CA_BUNDLE="${INSTALL_DIR}/ssl/cert.pem"
RUN set -xe; \
    mkdir -p ${OPENSSL_BUILD_DIR}; \
    curl -Ls  https://github.com/openssl/openssl/archive/OpenSSL_${VERSION_OPENSSL//./_}.tar.gz \
  | tar xzC ${OPENSSL_BUILD_DIR} --strip-components=1
WORKDIR  ${OPENSSL_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./config \
        --prefix=${INSTALL_DIR} \
        --openssldir=${INSTALL_DIR}/ssl \
        --release \
        no-tests \
        shared \
        zlib
# Explicitly compile make without parallelism because it fails if we use -jX (no error message)
# I'm not 100% sure why, and I already lost 4 hours on this, but I found this:
# https://github.com/openssl/openssl/issues/9931
# https://stackoverflow.com/questions/28639207/why-cant-i-compile-openssl-with-multiple-threads-make-j3
# Run `make install_sw install_ssldirs` instead of `make install` to skip installing man pages https://github.com/openssl/openssl/issues/8170
RUN make -j1 install_sw install_ssldirs
RUN curl -Lk -o ${CA_BUNDLE} ${CA_BUNDLE_SOURCE}


###############################################################################
# LIBSSH2
# https://github.com/libssh2/libssh2/releases
# Needs:
#   - zlib
#   - OpenSSL
# Needed by:
#   - curl
ENV VERSION_LIBSSH2=1.10.0
ENV LIBSSH2_BUILD_DIR=${BUILD_DIR}/libssh2
RUN set -xe; \
    mkdir -p ${LIBSSH2_BUILD_DIR}/bin; \
    curl -Ls https://github.com/libssh2/libssh2/releases/download/libssh2-${VERSION_LIBSSH2}/libssh2-${VERSION_LIBSSH2}.tar.gz \
  | tar xzC ${LIBSSH2_BUILD_DIR} --strip-components=1
WORKDIR  ${LIBSSH2_BUILD_DIR}/bin/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    cmake .. \
        # Build as a shared library (.so) instead of a static one
        -DBUILD_SHARED_LIBS=ON \
        # Build with OpenSSL support
        -DCRYPTO_BACKEND=OpenSSL \
        # Build with zlib support
        -DENABLE_ZLIB_COMPRESSION=ON \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
        -DCMAKE_BUILD_TYPE=RELEASE
RUN cmake  --build . --target install


###############################################################################
# LIBNGHTTP2
# This adds support for HTTP 2 requests in curl.
# See https://github.com/brefphp/bref/issues/727 and https://github.com/brefphp/bref/pull/740
# https://github.com/nghttp2/nghttp2/releases
# Needs:
#   - zlib
#   - OpenSSL
# Needed by:
#   - curl
ENV VERSION_NGHTTP2=1.51.0
ENV NGHTTP2_BUILD_DIR=${BUILD_DIR}/nghttp2
RUN set -xe; \
    mkdir -p ${NGHTTP2_BUILD_DIR}; \
    curl -Ls https://github.com/nghttp2/nghttp2/releases/download/v${VERSION_NGHTTP2}/nghttp2-${VERSION_NGHTTP2}.tar.gz \
    | tar xzC ${NGHTTP2_BUILD_DIR} --strip-components=1
WORKDIR  ${NGHTTP2_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure \
    --enable-lib-only \
    --prefix=${INSTALL_DIR}
RUN make install


###############################################################################
# CURL
# # https://github.com/curl/curl/releases
# # Needs:
# #   - zlib
# #   - OpenSSL
# #   - libssh2
# # Needed by:
# #   - php
ENV VERSION_CURL=7.85.0
ENV CURL_BUILD_DIR=${BUILD_DIR}/curl
RUN set -xe; \
    mkdir -p ${CURL_BUILD_DIR}/bin; \
    curl -Ls https://github.com/curl/curl/archive/curl-${VERSION_CURL//./_}.tar.gz \
    | tar xzC ${CURL_BUILD_DIR} --strip-components=1
WORKDIR  ${CURL_BUILD_DIR}/
RUN ./buildconf \
 && CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure \
    --prefix=${INSTALL_DIR} \
    --with-ca-bundle=${CA_BUNDLE} \
    --enable-shared \
    --disable-static \
    --enable-optimize \
    --disable-warnings \
    --disable-dependency-tracking \
    --with-zlib \
    --enable-http \
    --enable-ftp  \
    --enable-file \
    --enable-proxy  \
    --enable-tftp \
    --enable-ipv6 \
    --enable-openssl-auto-load-config \
    --enable-cookies \
    --with-gnu-ld \
    --with-ssl \
    --with-libssh2 \
    --with-nghttp2
RUN make install


###############################################################################
# LIBXML2
# https://github.com/GNOME/libxml2/releases
# Uses:
#   - zlib
# Needed by:
#   - php
ENV VERSION_XML2=2.10.3
ENV XML2_BUILD_DIR=${BUILD_DIR}/xml2
RUN set -xe; \
    mkdir -p ${XML2_BUILD_DIR}; \
    curl -Ls https://download.gnome.org/sources/libxml2/${VERSION_XML2%.*}/libxml2-${VERSION_XML2}.tar.xz \
  | tar xJC ${XML2_BUILD_DIR} --strip-components=1
WORKDIR  ${XML2_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure \
    --prefix=${INSTALL_DIR} \
    --with-sysroot=${INSTALL_DIR} \
    --enable-shared \
    --disable-static \
    --with-html \
    --with-history \
    --enable-ipv6=no \
    --with-icu \
    --with-zlib=${INSTALL_DIR} \
    --without-python
RUN make install \
 && cp xml2-config ${INSTALL_DIR}/bin/xml2-config


###############################################################################
# LIBZIP
# https://github.com/nih-at/libzip/releases
# Needed by:
#   - php
ENV VERSION_ZIP=1.9.2
ENV ZIP_BUILD_DIR=${BUILD_DIR}/zip
RUN set -xe; \
    mkdir -p ${ZIP_BUILD_DIR}/bin/; \
    curl -Ls https://github.com/nih-at/libzip/releases/download/v${VERSION_ZIP}/libzip-${VERSION_ZIP}.tar.gz \
  | tar xzC ${ZIP_BUILD_DIR} --strip-components=1
WORKDIR  ${ZIP_BUILD_DIR}/bin/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
        -DCMAKE_BUILD_TYPE=RELEASE
RUN cmake  --build . --target install


###############################################################################
# LIBSODIUM
# https://github.com/jedisct1/libsodium/releases
# Needed by:
#   - php
ENV VERSION_LIBSODIUM=1.0.18
ENV LIBSODIUM_BUILD_DIR=${BUILD_DIR}/libsodium
RUN set -xe; \
    mkdir -p ${LIBSODIUM_BUILD_DIR}; \
    curl -Ls https://github.com/jedisct1/libsodium/archive/${VERSION_LIBSODIUM}.tar.gz \
  | tar xzC ${LIBSODIUM_BUILD_DIR} --strip-components=1
WORKDIR  ${LIBSODIUM_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./autogen.sh \
&& ./configure --prefix=${INSTALL_DIR}
RUN make install


###############################################################################
# Postgres
# https://github.com/postgres/postgres/releases
# Needs:
#   - OpenSSL
# Needed by:
#   - php
ENV VERSION_POSTGRES=15.1
ENV POSTGRES_BUILD_DIR=${BUILD_DIR}/postgres
RUN set -xe; \
    mkdir -p ${POSTGRES_BUILD_DIR}/bin; \
    curl -Ls https://github.com/postgres/postgres/archive/REL_${VERSION_POSTGRES//./_}.tar.gz \
    | tar xzC ${POSTGRES_BUILD_DIR} --strip-components=1
WORKDIR  ${POSTGRES_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure --prefix=${INSTALL_DIR} --with-openssl --without-readline
RUN cd ${POSTGRES_BUILD_DIR}/src/interfaces/libpq && make && make install
RUN cd ${POSTGRES_BUILD_DIR}/src/bin/pg_config && make && make install
RUN cd ${POSTGRES_BUILD_DIR}/src/backend && make generated-headers
RUN cd ${POSTGRES_BUILD_DIR}/src/include && make install


###############################################################################
# Oniguruma
# This library is not packaged in PHP since PHP 7.4.
# See https://github.com/php/php-src/blob/43dc7da8e3719d3e89bd8ec15ebb13f997bbbaa9/UPGRADING#L578-L581
# We do not install the system version because I didn't manage to make it work...
# Ideally we shouldn't compile it ourselves.
# https://github.com/kkos/oniguruma/releases
# Needed by:
#   - php mbstring
ENV VERSION_ONIG=6.9.8
ENV ONIG_BUILD_DIR=${BUILD_DIR}/oniguruma
RUN set -xe; \
    mkdir -p ${ONIG_BUILD_DIR}; \
    curl -Ls https://github.com/kkos/oniguruma/releases/download/v${VERSION_ONIG}/onig-${VERSION_ONIG}.tar.gz \
    | tar xzC ${ONIG_BUILD_DIR} --strip-components=1
WORKDIR  ${ONIG_BUILD_DIR}
RUN ./configure --prefix=${INSTALL_DIR}
RUN make && make install


###############################################################################
# Install some dev files for using old libraries already on the system
# readline-devel : needed for the readline extension
# gettext-devel : needed for the --with-gettext flag
# libicu-devel : needed for intl
# libxslt-devel : needed for the XSL extension
# sqlite-devel : Since PHP 7.4 this must be installed (https://github.com/php/php-src/blob/99b8e67615159fc600a615e1e97f2d1cf18f14cb/UPGRADING#L616-L619)
RUN LD_LIBRARY_PATH= yum install -y readline-devel gettext-devel libicu-devel libxslt-devel sqlite-devel
