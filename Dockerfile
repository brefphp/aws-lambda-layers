# syntax = docker/dockerfile:1.4

# Bref v4 runtime images, for every PHP version (PHP_VERSION and VERSION_PHP are set by docker-bake.hcl).
#
# The image is the whole runtime: PHP, its configuration and Bref's bootstrap. The same image runs as:
# - a Lambda runtime (Lambda runs /var/runtime/bootstrap, the application code is in /var/task),
# - the base image of a Lambda container image (FROM bref/php-85, COPY the code to /var/task).
#
# Nothing is installed in /opt: Lambda mounts layers there, which would hide it.

# e.g. "85"
ARG PHP_VERSION
# e.g. "8.5.12", https://www.php.net/downloads
ARG VERSION_PHP


# Lambda's entrypoint and Runtime Interface Emulator (to run the image locally)
FROM public.ecr.aws/lambda/provided:al2023 AS lambda-runtime-interface


FROM ubuntu:26.04 AS build-environment

ARG DEBIAN_FRONTEND=noninteractive

RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        bison \
        ca-certificates \
        curl \
        g++ \
        gcc \
        libtool \
        make \
        patch \
        perl \
        pkg-config \
        re2c \
        xz-utils \
        # PHP's dependencies
        libbz2-dev \
        libcurl4-openssl-dev \
        libffi-dev \
        libicu-dev \
        libonig-dev \
        libpq-dev \
        libreadline-dev \
        libsodium-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        libzip-dev \
        zlib1g-dev

# Enable parallelism by default for make and cmake (like make -j)
ENV CMAKE_BUILD_PARALLEL_LEVEL=4
ENV MAKEFLAGS='-j4'


# PHP
# Download and unpack the source code
# --location will follow redirects
# --silent will hide the progress, but also the errors: we restore error messages with --show-error
# --fail makes sure that curl returns an error instead of fetching the 404 page
ARG VERSION_PHP
WORKDIR /tmp/php
RUN curl --location --silent --show-error --fail --retry 3 "https://www.php.net/distributions/php-${VERSION_PHP}.tar.gz" \
    | tar xzC . --strip-components=1

# One binary for php and php-fpm: `php` runs FPM when invoked as `php-fpm` (--enable-cli-fpm,
# https://github.com/php/php-src/pull/23558, not in PHP yet). FPM then maps the file that the CLI
# (Bref's bootstrap) already loaded: -12 to -16 ms of FPM cold start and 8 MB less memory.
# Applied when src/cli-fpm has a patch for this PHP version.
ARG PHP_VERSION
COPY --link src/cli-fpm /tmp/cli-fpm
RUN if [ -f "/tmp/cli-fpm/php-${PHP_VERSION}.patch" ]; then patch -p1 < "/tmp/cli-fpm/php-${PHP_VERSION}.patch"; fi

# Configure the build
# -fstack-protector-strong : Be paranoid about stack overflows
# -fpic : Make PHP's main executable position-independent (improves ASLR security mechanism, and has no performance impact on x86_64)
# -fpie : Support Address Space Layout Randomization (see -fpic)
# -O2 : Optimal configuration for AWS Lambda.
# --enable-option-checking=fatal: make sure invalid --configure-flags are fatal errors instead of just warnings
# --enable-ftp: because ftp_ssl_connect() needs ftp to be compiled statically (see https://github.com/docker-library/php/issues/236)
# --with-zlib: See https://stackoverflow.com/a/42978649/245552
# Extensions enabled by default are compiled statically: loading .so files costs time at every PHP start.
# Optional extensions are compiled as shared extensions, users enable them in `php/conf.d/*.ini`.
RUN ./buildconf --force
RUN CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -ffunction-sections -fdata-sections" \
    CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2 -ffunction-sections -fdata-sections" \
    LDFLAGS="-Wl,-O1 -Wl,--strip-all -Wl,--hash-style=both -pie" \
    ./configure \
        --prefix=/usr/local \
        --enable-option-checking=fatal \
        --with-config-file-path=/etc/php \
        # Extension layers (e.g. bref/extra-php-extensions) install their configuration in /opt/bref/etc/php/conf.d
        --with-config-file-scan-dir=/etc/php/conf.d:/opt/bref/etc/php/conf.d:/var/task/php/conf.d \
        --enable-cli \
        --enable-fpm \
        $([ -f "/tmp/cli-fpm/php-${PHP_VERSION}.patch" ] && echo --enable-cli-fpm) \
        --disable-cgi \
        --disable-phpdbg \
        --with-openssl \
        --with-zlib \
        --with-curl \
        --with-sodium \
        --with-ffi \
        --with-readline \
        --enable-bcmath \
        --enable-exif \
        --enable-ftp \
        --with-gettext \
        --enable-mbstring \
        --enable-pcntl \
        --enable-sockets \
        --with-pdo-mysql=mysqlnd \
        --with-mysqli \
        --with-pdo-pgsql \
        --with-zip \
        --with-xsl \
        --with-sqlite3 \
        --with-pdo-sqlite \
        # Separate .so extensions so that they are not loaded by default
        --enable-intl=shared \
        --enable-soap=shared \
        # Needed by `pecl` to install extensions (in this image and in images built on it)
        --with-pear
RUN make -j "$(nproc)"
# Override PEAR's PHAR URL because pear.php.net is down
RUN set -xe; \
    make install PEAR_INSTALLER_URL='https://github.com/pear/pearweb_phars/raw/master/install-pear-nozlib.phar'; \
    make clean; \
    if [ -f "/tmp/cli-fpm/php-${PHP_VERSION}.patch" ]; then ln -sf ../bin/php /usr/local/sbin/php-fpm; fi

# Optional extensions installed with `pecl`, not enabled by default
RUN pecl install APCu
RUN pecl install redis-6.3.0

# Gather all extensions in one directory, independent of PHP's internal API version
RUN set -xe; \
    mkdir -p /usr/local/lib/php/extensions; \
    cp "$(php -r 'echo ini_get("extension_dir");')"/*.so /usr/local/lib/php/extensions/; \
    find /usr/local/lib/php/extensions /usr/local/bin/php /usr/local/sbin/php-fpm -type f -exec strip --strip-all {} +


# ----------------------------------------------------------------------------
# The runtime image: Ubuntu, the libraries PHP needs, PHP and Bref's bootstrap
FROM ubuntu:26.04 AS php

ARG DEBIAN_FRONTEND=noninteractive
ARG PHP_VERSION

RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        libbz2-1.0 \
        libcurl4t64 \
        libffi8 \
        libicu78 \
        libonig5 \
        libpq5 \
        libreadline8t64 \
        libsodium23 \
        libsqlite3-0 \
        libssl3t64 \
        libxml2-16 \
        libxslt1.1 \
        libzip5 \
        zlib1g; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /usr/share/doc/* /usr/share/man/*; \
    chmod 1777 /tmp

RUN set -xe; \
    # Certificates: Ubuntu's bundle where OpenSSL looks for it (OPENSSLDIR), and where Bref v3 (Amazon Linux) had it
    mkdir -p /usr/lib/ssl /etc/pki/tls; \
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/ssl/cert.pem; \
    [ -e /usr/lib/ssl/certs ] || ln -s /etc/ssl/certs /usr/lib/ssl/certs; \
    ln -sf /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/cert.pem

COPY --link --from=build-environment /usr/local/bin/php /usr/local/bin/php
# php-fpm is either a binary or a symlink to php (--enable-cli-fpm): copy the directory to keep symlinks
COPY --link --from=build-environment /usr/local/sbin/ /usr/local/sbin/
COPY --link --from=build-environment /usr/local/lib/php/extensions /usr/local/lib/php/extensions

COPY --link src/php.ini /etc/php/conf.d/50-bref.ini
# Before PHP 8.5, opcache is a shared extension
RUN if [ "${PHP_VERSION}" -lt 85 ]; then echo 'zend_extension=opcache' > /etc/php/conf.d/10-opcache.ini; fi
COPY --link src/php-fpm.conf /etc/php/php-fpm.conf
# TODO remove once bref/bref v4 reads /etc/php/php-fpm.conf: Bref v3 starts php-fpm with /opt/bref/etc/php-fpm.conf
COPY --link src/php-fpm-v3-compat.sh /usr/local/bin/php-fpm
RUN chmod +x /usr/local/bin/php-fpm

COPY --link src/bootstrap.sh /var/runtime/bootstrap
RUN chmod +x /var/runtime/bootstrap
COPY --link src/bootstrap.php /var/runtime/bootstrap.php
# /tmp must stay writable by everyone (e.g. PHP-FPM workers run as nobody), whatever the COPYs above did
RUN chmod 1777 /tmp

# Lambda needs these to exist in the image (the code is mounted on /var/task, /etc/hosts is
# rewritten at startup): without them, the execution environment never starts
COPY --link src/empty /etc/hosts
WORKDIR /var/task

# To run the image as a Lambda container image (and locally, with the emulator)
COPY --link --from=lambda-runtime-interface /lambda-entrypoint.sh /lambda-entrypoint.sh
COPY --link --from=lambda-runtime-interface /usr/local/bin/aws-lambda-rie /usr/local/bin/aws-lambda-rie
ENTRYPOINT [ "/lambda-entrypoint.sh" ]


# ----------------------------------------------------------------------------
# The image to build extra extensions: PHP's headers, phpize and pecl on the same base
FROM build-environment AS build-php


# ----------------------------------------------------------------------------
# Build the dev image with xdebug
FROM build-environment AS build-dev

RUN pecl install xdebug-3.5.0 && cp "$(php -r 'echo ini_get("extension_dir");')"/xdebug.so /tmp/xdebug.so


FROM php AS dev

ARG DEBIAN_FRONTEND=noninteractive

COPY --link --from=build-dev /tmp/xdebug.so /usr/local/lib/php/extensions/xdebug.so
COPY --link src/dev-entrypoint.sh /bref-entrypoint.sh
RUN chmod +x /bref-entrypoint.sh

# Install node to run the JS app below
RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Install the bref/local-api-gateway app in our container (avoids running 2 containers)
COPY --link --from=bref/local-api-gateway /app /local-api-gateway
EXPOSE 8000

# Add `php/conf.dev.d` to the path where PHP looks for configuration files
ENV PHP_INI_SCAN_DIR="/etc/php/conf.d:/opt/bref/etc/php/conf.d:/var/task/php/conf.d:/var/task/php/conf.dev.d"

# Add composer
COPY --link --from=composer/composer:2-bin /composer /usr/bin/composer

# Originally the entrypoint is `/lambda-entrypoint.sh` and CMD contains the handler name
# We override the entrypoint to run our own logic
ENTRYPOINT [ "/bref-entrypoint.sh" ]
