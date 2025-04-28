# syntax = docker/dockerfile:1.4

# Can be "x86_64" or "arm64"
ARG IMAGE_VERSION_SUFFIX

# https://www.php.net/downloads
ARG VERSION_PHP=8.3.20


# Lambda uses a custom AMI named Amazon Linux 2
# https://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html
# AWS provides a Docker image that we use here:
# https://github.com/amazonlinux/container-images/tree/amzn2
FROM public.ecr.aws/lambda/provided:al2-${IMAGE_VERSION_SUFFIX} as build-environment


RUN set -xe \
    # Download yum repository data to cache
 && yum makecache \
    # Install default development tools (gcc, make, etc)
 && yum groupinstall -y "Development Tools" --setopt=group_package_types=mandatory,default


# The default version of cmake is 2.8.12. We need cmake to build a few of
# our libraries, and at least one library requires a version of cmake greater than that.
# Needed to build:
# - libzip: minimum required CMAKE version 3.0.
RUN LD_LIBRARY_PATH= yum install -y cmake3
# Override the default `cmake`
RUN ln -s /usr/bin/cmake3 /usr/bin/cmake


# We need a base path for all the sourcecode we will build from.
ENV BUILD_DIR="/tmp/build"

# Target installation path for all the binaries and libraries we will compile.
# We need to use /opt because that's where AWS Lambda layers are unzipped,
# and we need binaries (e.g. /opt/bin/php) to look for libraries in /opt/lib.
# Indeed, `/opt/lib` is a path Lambda looks for libraries by default (it is in `LD_LIBRARY_PATH`)
# AND the `/opt/lib` path will be hardcoded in the compiled binaries and libraries (called "rpath").
#
# Note: the /opt directory will be completely recreated from scratch in the final images,
# so it's ok at this stage if we "pollute" it with plenty of extra libs/build artifacts.
ENV INSTALL_DIR="/opt"

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
# ZLIB Build
# We compile a newer version because Lambda uses an old version (1.2.7) that
# has a security vulnerability (CVE-2022-37434).
# See https://github.com/brefphp/aws-lambda-layers/pull/110
# Can be removed once Lambda updates their version.
# https://github.com/madler/zlib/releases
ENV VERSION_ZLIB=1.3.1
ENV ZLIB_BUILD_DIR=${BUILD_DIR}/zlib
RUN set -xe; \
    mkdir -p ${ZLIB_BUILD_DIR}; \
    curl -Ls https://github.com/madler/zlib/releases/download/v${VERSION_ZLIB}/zlib-${VERSION_ZLIB}.tar.gz \
  | tar xzC ${ZLIB_BUILD_DIR} --strip-components=1
WORKDIR ${ZLIB_BUILD_DIR}/
RUN set -xe; \
    make distclean \
 && CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include  -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure \
    --prefix=${INSTALL_DIR}
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
RUN yum install -y perl-IPC-Cmd
ENV VERSION_OPENSSL=3.3.3
ENV OPENSSL_BUILD_DIR=${BUILD_DIR}/openssl
ENV CA_BUNDLE_SOURCE="https://curl.se/ca/cacert.pem"
ENV CA_BUNDLE="${INSTALL_DIR}/bref/ssl/cert.pem"
RUN set -xe; \
    mkdir -p ${OPENSSL_BUILD_DIR}; \
    curl -Ls https://github.com/openssl/openssl/releases/download/openssl-${VERSION_OPENSSL}/openssl-${VERSION_OPENSSL}.tar.gz \
  | tar xzC ${OPENSSL_BUILD_DIR} --strip-components=1
WORKDIR  ${OPENSSL_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./config \
        --prefix=${INSTALL_DIR} \
        --openssldir=${INSTALL_DIR}/bref/ssl \
        --release \
        enable-tls1_3 \
        no-tests \
        shared \
        zlib
# Explicitly compile make without parallelism because it fails if we use -jX (no error message)
# I'm not 100% sure why, and I already lost 4 hours on this, but I found this:
# https://github.com/openssl/openssl/issues/9931
# https://stackoverflow.com/questions/28639207/why-cant-i-compile-openssl-with-multiple-threads-make-j3
# Run `make install_sw install_ssldirs` instead of `make install` to skip installing man pages https://github.com/openssl/openssl/issues/8170
RUN make -j1 install_sw install_ssldirs
RUN mkdir -p ${INSTALL_DIR}/bref/ssl && curl -Lk -o ${CA_BUNDLE} ${CA_BUNDLE_SOURCE}


###############################################################################
# LIBXML2
# https://gitlab.gnome.org/GNOME/libxml2/-/releases
# Uses:
#   - zlib
# Needed by:
#   - php
#   - libnghttp2
ENV VERSION_XML2=2.13.8
ENV XML2_BUILD_DIR=${BUILD_DIR}/xml2
RUN set -xe; \
    mkdir -p ${XML2_BUILD_DIR}; \
    curl -Ls https://download.gnome.org/sources/libxml2/${VERSION_XML2%.*}/libxml2-${VERSION_XML2}.tar.xz \
  | tar xJC ${XML2_BUILD_DIR} --strip-components=1
WORKDIR  ${XML2_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
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
    --with-zlib \
    --without-python
RUN make install \
 && cp xml2-config ${INSTALL_DIR}/bin/xml2-config


###############################################################################
# LIBSSH2
# https://github.com/libssh2/libssh2/releases
# Needs:
#   - zlib
#   - OpenSSL
# Needed by:
#   - curl
ENV VERSION_LIBSSH2=1.11.1
ENV LIBSSH2_BUILD_DIR=${BUILD_DIR}/libssh2
RUN set -xe; \
    mkdir -p ${LIBSSH2_BUILD_DIR}/bin; \
    curl -Ls https://github.com/libssh2/libssh2/releases/download/libssh2-${VERSION_LIBSSH2}/libssh2-${VERSION_LIBSSH2}.tar.gz \
  | tar xzC ${LIBSSH2_BUILD_DIR} --strip-components=1
WORKDIR  ${LIBSSH2_BUILD_DIR}/bin/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
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
#   - libxml2
# Needed by:
#   - curl
ENV VERSION_NGHTTP2=1.65.0
ENV NGHTTP2_BUILD_DIR=${BUILD_DIR}/nghttp2
RUN set -xe; \
    mkdir -p ${NGHTTP2_BUILD_DIR}; \
    curl -Ls https://github.com/nghttp2/nghttp2/releases/download/v${VERSION_NGHTTP2}/nghttp2-${VERSION_NGHTTP2}.tar.gz \
    | tar xzC ${NGHTTP2_BUILD_DIR} --strip-components=1
WORKDIR  ${NGHTTP2_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure \
    --enable-lib-only \
    --prefix=${INSTALL_DIR}
RUN make install


###############################################################################
# LIBPSL
# This adds support for the public suffix list in curl.
# https://github.com/rockdaboot/libpsl/releases
# Needed by:
#   - curl
ENV VERSION_LIBPSL=0.21.5
ENV LIBPSL_BUILD_DIR=${BUILD_DIR}/libpsl
RUN set -xe; \
    mkdir -p ${LIBPSL_BUILD_DIR}; \
    curl -Ls https://github.com/rockdaboot/libpsl/releases/download/${VERSION_LIBPSL}/libpsl-${VERSION_LIBPSL}.tar.gz \
    | tar xzC ${LIBPSL_BUILD_DIR} --strip-components=1
WORKDIR  ${LIBPSL_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure \
    --prefix=${INSTALL_DIR}
RUN make -j $(nproc) && make install


###############################################################################
# CURL
# # https://github.com/curl/curl/releases
# # Needs:
# #   - zlib
# #   - OpenSSL
# #   - libssh2
# #   - libnghttp2
# # Needed by:
# #   - php
ENV VERSION_CURL=8.12.1
ENV CURL_BUILD_DIR=${BUILD_DIR}/curl
RUN set -xe; \
    mkdir -p ${CURL_BUILD_DIR}/bin; \
    curl -Ls https://github.com/curl/curl/archive/curl-${VERSION_CURL//./_}.tar.gz \
    | tar xzC ${CURL_BUILD_DIR} --strip-components=1
WORKDIR  ${CURL_BUILD_DIR}/
RUN ./buildconf \
 && CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
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
# LIBZIP
# https://github.com/nih-at/libzip/releases
# Needed by:
#   - php
ENV VERSION_ZIP=1.11.3
ENV ZIP_BUILD_DIR=${BUILD_DIR}/zip
RUN set -xe; \
    mkdir -p ${ZIP_BUILD_DIR}/bin/; \
    curl -Ls https://github.com/nih-at/libzip/releases/download/v${VERSION_ZIP}/libzip-${VERSION_ZIP}.tar.gz \
  | tar xzC ${ZIP_BUILD_DIR} --strip-components=1
WORKDIR  ${ZIP_BUILD_DIR}/bin/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
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
ENV VERSION_LIBSODIUM=1.0.20
ENV LIBSODIUM_BUILD_DIR=${BUILD_DIR}/libsodium
RUN set -xe; \
    mkdir -p ${LIBSODIUM_BUILD_DIR}; \
    curl -Ls https://github.com/jedisct1/libsodium/archive/${VERSION_LIBSODIUM}-RELEASE.tar.gz \
  | tar xzC ${LIBSODIUM_BUILD_DIR} --strip-components=1
WORKDIR  ${LIBSODIUM_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./autogen.sh \
&& ./configure --prefix=${INSTALL_DIR}
RUN make install


###############################################################################
# Postgres
# https://github.com/postgres/postgres/tags
# Needs:
#   - OpenSSL
# Needed by:
#   - php
ENV VERSION_POSTGRES=17.4
ENV POSTGRES_BUILD_DIR=${BUILD_DIR}/postgres
RUN set -xe; \
    mkdir -p ${POSTGRES_BUILD_DIR}/bin; \
    curl -Ls https://github.com/postgres/postgres/archive/REL_${VERSION_POSTGRES//./_}.tar.gz \
    | tar xzC ${POSTGRES_BUILD_DIR} --strip-components=1
WORKDIR  ${POSTGRES_BUILD_DIR}/
RUN CFLAGS="" \
    CPPFLAGS="-I${INSTALL_DIR}/include -I/usr/include" \
    LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib" \
    ./configure --prefix=${INSTALL_DIR} --with-openssl --without-icu --without-readline
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
ENV VERSION_ONIG=6.9.10
ENV ONIG_BUILD_DIR=${BUILD_DIR}/oniguruma
RUN set -xe; \
    mkdir -p ${ONIG_BUILD_DIR}; \
    curl -Ls https://github.com/kkos/oniguruma/releases/download/v${VERSION_ONIG}/onig-${VERSION_ONIG}.tar.gz \
    | tar xzC ${ONIG_BUILD_DIR} --strip-components=1
WORKDIR  ${ONIG_BUILD_DIR}
RUN ./configure --prefix=${INSTALL_DIR}
RUN make && make install


###############################################################################
# SQLite
# Since PHP 7.4, libsqlite must be installed (https://github.com/php/php-src/blob/99b8e67615159fc600a615e1e97f2d1cf18f14cb/UPGRADING#L616-L619)
# Laravel 11 requires SQLite 3.35.0 or higher and Drupal 10 also requires a
# newer version than the system version of 3.7.17.
# https://laravel.com/docs/11.x/upgrade#sqlite-minimum-version
# https://www.sqlite.org/changes.html
# Needed by:
#   - php
RUN LD_LIBRARY_PATH= yum install -y tcl
ENV VERSION_SQLITE=3.49.1
ENV SQLITE_BUILD_DIR=${BUILD_DIR}/sqlite
RUN set -xe; \
    mkdir -p ${SQLITE_BUILD_DIR}; \
    curl -Ls https://github.com/sqlite/sqlite/archive/refs/tags/version-${VERSION_SQLITE}.tar.gz \
    | tar xzC ${SQLITE_BUILD_DIR} --strip-components=1
WORKDIR ${SQLITE_BUILD_DIR}
RUN ./configure --prefix=${INSTALL_DIR}
RUN make && make install


###############################################################################
# Install some dev files for using old libraries already on the system
# readline-devel : needed for the readline extension
# gettext-devel : needed for the --with-gettext flag
# libicu-devel : needed for intl
# libxslt-devel : needed for the XSL extension
# libffi-devel : needed for the FFI extension
RUN LD_LIBRARY_PATH= yum install -y readline-devel gettext-devel libicu-devel libxslt-devel libffi-devel


# Note: this variable is used when building extra/custom extensions, do not remove
ENV PHP_BUILD_DIR=/tmp/php

# PHP Build
# https://github.com/php/php-src/releases
# Needs:
#   - zlib
#   - libxml2
#   - openssl
#   - readline
#   - sodium
RUN mkdir -p ${PHP_BUILD_DIR}
WORKDIR ${PHP_BUILD_DIR}

# Download and unpack the source code
# --location will follow redirects
# --silent will hide the progress, but also the errors: we restore error messages with --show-error
# --fail makes sure that curl returns an error instead of fetching the 404 page
ARG VERSION_PHP
RUN curl --location --silent --show-error --fail https://www.php.net/get/php-${VERSION_PHP}.tar.gz/from/this/mirror \
  | tar xzC . --strip-components=1

# Configure the build
# -fstack-protector-strong : Be paranoid about stack overflows
# -fpic : Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# -fpie : Support Address Space Layout Randomization (see -fpic)
# -O3 : Optimize for fastest binaries possible.
# -I : Add the path to the list of directories to be searched for header files during preprocessing.
# --enable-option-checking=fatal: make sure invalid --configure-flags are fatal errors instead of just warnings
# --enable-ftp: because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
# --enable-mbstring: because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
# --with-zlib and --with-zlib-dir: See https://stackoverflow.com/a/42978649/245552
ARG PHP_COMPILATION_FLAGS
RUN ./buildconf --force
RUN CFLAGS="-fstack-protector-strong -fpic -fpie -O3 -I${INSTALL_DIR}/include -I/usr/include -ffunction-sections -fdata-sections" \
        CPPFLAGS="-fstack-protector-strong -fpic -fpie -O3 -I${INSTALL_DIR}/include -I/usr/include -ffunction-sections -fdata-sections" \
        LDFLAGS="-L${INSTALL_DIR}/lib64 -L${INSTALL_DIR}/lib -Wl,-O1 -Wl,--strip-all -Wl,--hash-style=both -pie" \
    ./configure \
        --prefix=${INSTALL_DIR} \
        --enable-option-checking=fatal \
        --enable-sockets \
        --with-config-file-path=/opt/bref/etc/php \
        --with-config-file-scan-dir=/opt/bref/etc/php/conf.d:/var/task/php/conf.d \
        --enable-fpm \
        --disable-cgi \
        --enable-cli \
        --disable-phpdbg \
        --with-sodium \
        --with-readline \
        --with-openssl \
        --with-zlib \
        --with-zlib-dir \
        --with-curl \
        --enable-exif \
        --enable-ftp \
        --with-gettext \
        --enable-mbstring \
        --with-pdo-mysql=shared,mysqlnd \
        --with-mysqli \
        --enable-pcntl \
        --with-zip \
        --enable-bcmath \
        --with-pdo-pgsql=shared,${INSTALL_DIR} \
        --enable-intl=shared \
        --enable-soap \
        --with-xsl=${INSTALL_DIR} \
        --with-ffi \
        # necessary for `pecl` to work (to install PHP extensions)
        --with-pear \
        # extra compilation flags
        ${PHP_COMPILATION_FLAGS}
RUN make -j $(nproc)
# Run `make install` and override PEAR's PHAR URL because pear.php.net is down
RUN set -xe; \
    make install PEAR_INSTALLER_URL='https://github.com/pear/pearweb_phars/raw/master/install-pear-nozlib.phar'; \
    { find ${INSTALL_DIR}/bin ${INSTALL_DIR}/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; }; \
    make clean; \
    cp php.ini-production ${INSTALL_DIR}/etc/php/php.ini


# Install extensions
# We can install extensions manually or using `pecl`
ENV VERSION_APCU=5.1.24
RUN pecl install apcu-${VERSION_APCU}


# ---------------------------------------------------------------
# Now we copy everything we need for the layers into /bref-layer (which will be used for the real /opt later)
RUN mkdir -p /bref-layer/bin \
&&  mkdir -p /bref-layer/lib \
&&  mkdir -p /bref-layer/bref/extensions \
&&  mkdir -p /bref-layer/bref/ssl

# Copy the PHP binary
RUN cp ${INSTALL_DIR}/bin/php /bref-layer/bin/php && chmod +x /bref-layer/bin/php

# Copy all the external PHP extensions
RUN cp $(php -r 'echo ini_get("extension_dir");')/* /bref-layer/bref/extensions/

# Copy all the required system libraries from:
# - /lib | /lib64 (system libraries installed with `yum`)
# - /opt/bin | /opt/lib | /opt/lib64 (libraries compiled from source)
# into `/bref-layer` (the temp directory for the future Lambda layer)
COPY --link utils/lib-copy /bref/lib-copy
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bin/php /bref-layer/lib
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bref/extensions/apcu.so /bref-layer/lib
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bref/extensions/intl.so /bref-layer/lib
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bref/extensions/opcache.so /bref-layer/lib
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bref/extensions/pdo_mysql.so /bref-layer/lib
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bref/extensions/pdo_pgsql.so /bref-layer/lib

# Copy the OpenSSL certificates file
RUN cp ${CA_BUNDLE} /bref-layer/bref/ssl/cert.pem

# Copy the OpenSSL config
RUN cp ${INSTALL_DIR}/bref/ssl/openssl.cnf /bref-layer/bref/ssl/openssl.cnf


# ---------------------------------------------------------------
# Start from a clean image to copy only the files we need
FROM public.ecr.aws/lambda/provided:al2-${IMAGE_VERSION_SUFFIX} as isolation

# We selected the files in /bref-layer, now we copy them to /opt (the real directory for the Lambda layer)
COPY --link --from=build-environment /bref-layer /opt

COPY --link layers/bootstrap.php /opt/bref/bootstrap.php


FROM isolation as function

COPY --link layers/function/bref.ini /opt/bref/etc/php/conf.d/

COPY --link layers/function/bootstrap.sh /opt/bootstrap
# Copy files to /var/runtime to support deploying as a Docker image
COPY --link layers/function/bootstrap.sh /var/runtime/bootstrap
RUN chmod +x /opt/bootstrap && chmod +x /var/runtime/bootstrap


# Up until here the entire file has been designed as a top-down reading/execution.
# Everything necessary for the `function` layer has been installed, isolated and
# packaged. Now we'll go back one step and start from the extensions so that we
# can install fpm. Then we'll start the fpm layer and quickly isolate fpm.

FROM build-environment as fpm-extension

RUN cp ${INSTALL_DIR}/sbin/php-fpm /bref-layer/bin/php-fpm
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bin/php-fpm /bref-layer/lib


FROM isolation as fpm

COPY --link --from=fpm-extension /bref-layer /opt

COPY --link layers/fpm/bref.ini /opt/bref/etc/php/conf.d/

COPY --link layers/fpm/bootstrap.sh /opt/bootstrap
# Copy files to /var/runtime to support deploying as a Docker image
COPY --link layers/fpm/bootstrap.sh /var/runtime/bootstrap
RUN chmod +x /opt/bootstrap && chmod +x /var/runtime/bootstrap

COPY --link layers/fpm/php-fpm.conf /opt/bref/etc/php-fpm.conf
