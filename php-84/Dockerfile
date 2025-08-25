# syntax = docker/dockerfile:1.4

# Can be "x86_64" or "arm64"
ARG IMAGE_VERSION_SUFFIX

# https://www.php.net/downloads
ARG VERSION_PHP=8.4.11


# Lambda uses a custom AMI named Amazon Linux 2023
# https://docs.aws.amazon.com/lambda/latest/dg/current-supported-versions.html
# AWS provides a Docker image that we use here:
# https://github.com/amazonlinux/container-images/tree/amzn2
FROM public.ecr.aws/lambda/provided:al2023-${IMAGE_VERSION_SUFFIX} as build-environment


RUN set -xe \
    # Download dnf repository data to cache
 && dnf makecache \
    # Install default development tools (gcc, make, etc)
 && dnf install -y make gcc gcc-c++ autoconf automake libtool


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
# SQLite
# Since PHP 7.4, libsqlite must be installed (https://github.com/php/php-src/blob/99b8e67615159fc600a615e1e97f2d1cf18f14cb/UPGRADING#L616-L619)
# Laravel 11 requires SQLite 3.35+ https://laravel.com/docs/11.x/upgrade#sqlite-minimum-version
# Drupal 11 requires SQLite 3.45+ https://www.drupal.org/docs/getting-started/system-requirements/database-server-requirements
# The AL2023 built-in version is 3.40.0, so we compile a newer version.
# https://www.sqlite.org/changes.html
# Needed by:
#   - php
RUN LD_LIBRARY_PATH= dnf install -y tcl
ENV VERSION_SQLITE=3.50.4
ENV SQLITE_BUILD_DIR=${BUILD_DIR}/sqlite
RUN set -xe; \
    mkdir -p ${SQLITE_BUILD_DIR}; \
    curl -Ls https://github.com/sqlite/sqlite/archive/refs/tags/version-${VERSION_SQLITE}.tar.gz \
    | tar xzC ${SQLITE_BUILD_DIR} --strip-components=1
WORKDIR ${SQLITE_BUILD_DIR}
RUN CFLAGS="-Os" CPPFLAGS="-Os" ./configure --prefix=${INSTALL_DIR}
RUN make && make install


###############################################################################
# Install some dev files for using old libraries already on the system
# libcurl-devel : needed for the curl extension
# zlib-devel : needed for zlib/gz in PHP
# readline-devel : needed for the readline extension
# gettext-devel : needed for the --with-gettext flag
# libicu-devel : needed for intl
# libxslt-devel : needed for the XSL extension
# libsodium-devel : needed for the sodium extension
# libffi-devel : needed for the FFI extension
RUN LD_LIBRARY_PATH= dnf install -y libcurl-devel zlib-devel readline-devel gettext-devel libicu-devel libxslt-devel libzip-devel oniguruma-devel libpq-devel openssl-devel libsodium-devel libffi-devel


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
# --with-zlib: See https://stackoverflow.com/a/42978649/245552
ARG PHP_COMPILATION_FLAGS
RUN ./buildconf --force
RUN CFLAGS="-fstack-protector-strong -fpic -fpie -Os -I${INSTALL_DIR}/include -I/usr/include -ffunction-sections -fdata-sections" \
        CPPFLAGS="-fstack-protector-strong -fpic -fpie -Os -I${INSTALL_DIR}/include -I/usr/include -ffunction-sections -fdata-sections" \
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
        --with-curl \
        --enable-exif \
        --enable-ftp \
        --with-gettext \
        --enable-mbstring=shared \
        --with-pdo-mysql=mysqlnd \
        --with-mysqli \
        --enable-pcntl \
        --with-zip \
        --enable-bcmath \
        --with-pdo-pgsql \
        # Separate .so extension so that it is not loaded by default
        --enable-intl=shared \
        # Separate .so extension so that it is not loaded by default
        --enable-soap=shared \
        --with-xsl \
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
RUN pecl install APCu
RUN pecl install redis-6.2.0


# ---------------------------------------------------------------
# Now we copy everything we need for the layers into /bref-layer (which will be used for the real /opt later)
RUN mkdir -p /bref-layer/bin \
&&  mkdir -p /bref-layer/lib \
&&  mkdir -p /bref-layer/bref/extensions \
&&  mkdir -p /bref-layer/bref/ssl

# Copy the PHP binary
RUN cp ${INSTALL_DIR}/bin/php /bref-layer/bin/php && chmod +x /bref-layer/bin/php

# Copy the PHP-FPM binary
RUN cp ${INSTALL_DIR}/sbin/php-fpm /bref-layer/bin/php-fpm

# Copy all the external PHP extensions
RUN cp $(php -r 'echo ini_get("extension_dir");')/* /bref-layer/bref/extensions/

# Copy all the required system libraries from:
# - /lib | /lib64 (system libraries installed with `dnf`)
# - /opt/bin | /opt/lib | /opt/lib64 (libraries compiled from source)
# into `/bref-layer` (the temp directory for the future Lambda layer)
COPY --link utils/lib-copy /bref/lib-copy
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bin /bref-layer/lib
RUN php /bref/lib-copy/copy-dependencies.php /bref-layer/bref/extensions /bref-layer/lib

# Create a symbolic link to the OpenSSL certificates file for BC purposes
RUN ln -s /etc/ssl/cert.pem /bref-layer/bref/ssl/cert.pem

# Run `strip` over all libraries and extensions to reduce their size
RUN find /bref-layer/bref/extensions -type f -exec strip --strip-all {} +
RUN find /bref-layer/lib -type f -exec strip --strip-all {} +


# ----------------------------------------------------------------------------
# Start from a clean image to copy only the files we need for the Lambda layer
FROM public.ecr.aws/lambda/provided:al2023-${IMAGE_VERSION_SUFFIX} as function

# We selected the files in /bref-layer, now we copy them to /opt (the real directory for the Lambda layer)
COPY --link --from=build-environment /bref-layer /opt

COPY --link src/php.ini /opt/bref/etc/php/conf.d/bref.ini
COPY --link src/php-fpm.conf /opt/bref/etc/php-fpm.conf

COPY --link src/bootstrap.sh /opt/bootstrap
# Copy files to /var/runtime to support deploying as a Docker image
COPY --link src/bootstrap.sh /var/runtime/bootstrap
RUN chmod +x /opt/bootstrap && chmod +x /var/runtime/bootstrap
COPY --link src/bootstrap.php /opt/bref/bootstrap.php


# ----------------------------------------------------------------------------
# Build the dev image with xdebug
FROM build-environment as build_dev

RUN mkdir -p /opt/bref/extensions

# Install xdebug
RUN pecl install xdebug-3.4.2
RUN cp $(php -r "echo ini_get('extension_dir');")/xdebug.so /opt/bref/extensions


FROM function as dev

COPY --link --from=build_dev /opt /opt
COPY --link src/dev-entrypoint.sh /bref-entrypoint.sh
RUN chmod +x /bref-entrypoint.sh

# Install node to run the JS app below
RUN dnf install -y nodejs

# Install the bref/local-api-gateway app in our container (avoids running 2 containers)
COPY --link --from=bref/local-api-gateway /app /local-api-gateway
EXPOSE 8000

# Add `php/conf.dev.d` to the path where PHP looks for configuration files
ENV PHP_INI_SCAN_DIR="/opt/bref/etc/php/conf.d:/var/task/php/conf.d:/var/task/php/conf.dev.d"

# Add composer
COPY --link --from=composer/composer:2-bin /composer /usr/bin/composer

# Originally the entrypoint is `/lambda-entrypoint.sh` and CMD contains the handler name
# We override the entrypoint to run our own logic
ENTRYPOINT [ "/bref-entrypoint.sh" ]
