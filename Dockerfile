# syntax = docker/dockerfile:1.4

# Bref v4 runtime images, for every PHP version (PHP_VERSION and FULL_PHP_VERSION are set by docker-bake.hcl).
#
# The image is the whole runtime: PHP, its configuration and Bref's bootstrap. The same image runs as:
# - a Lambda runtime (Lambda runs /var/runtime/bootstrap, the application code is in /var/task),
# - the base image of a Lambda container image (FROM bref/php-85, COPY the code to /var/task).
#
# Nothing is installed in /opt: Lambda mounts layers there, which would hide it.

# e.g. "85"
ARG PHP_VERSION
# e.g. "8.5.12", https://www.php.net/downloads
ARG FULL_PHP_VERSION


# Lambda's entrypoint and Runtime Interface Emulator (to run the image locally)
FROM public.ecr.aws/lambda/provided:al2023 AS lambda-runtime-interface


FROM ubuntu:26.04 AS build-environment

ARG DEBIAN_FRONTEND=noninteractive

RUN set -xe; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        # Generate the build scripts of PHP (./buildconf) and of extensions (phpize, pecl)
        autoconf \
        automake \
        libtool \
        # PHP's parser and lexer generators, checked by ./configure
        bison \
        re2c \
        # HTTPS certificates, to download PHP's source and PECL extensions
        ca-certificates \
        # Download PHP's source
        curl \
        # Compilers (C++ for intl)
        gcc \
        g++ \
        make \
        # Finds the libraries below for ./configure
        pkg-config \
        # Headers of the libraries PHP and its extensions use (runtime libraries in the `php` stage below)
        # curl
        libcurl4-openssl-dev \
        # ffi
        libffi-dev \
        # gd (fonts)
        libfreetype-dev \
        # gmp
        libgmp-dev \
        # intl
        libicu-dev \
        # gd (JPEG)
        libjpeg-dev \
        # mbstring (regular expressions)
        libonig-dev \
        # gd (PNG)
        libpng-dev \
        # pdo_pgsql
        libpq-dev \
        # readline (interactive shell `php -a`)
        libreadline-dev \
        # sodium
        libsodium-dev \
        # sqlite3, pdo_sqlite
        libsqlite3-dev \
        # openssl
        libssl-dev \
        # gd (WebP)
        libwebp-dev \
        # dom, simplexml, soap, xml, xmlreader, xmlwriter
        libxml2-dev \
        # xsl
        libxslt1-dev \
        # zip
        libzip-dev \
        # zlib
        zlib1g-dev

# Enable parallelism by default for make and cmake (like make -j)
ENV CMAKE_BUILD_PARALLEL_LEVEL=4
ENV MAKEFLAGS='-j4'


# PHP
# Download and unpack the source code
# --location will follow redirects
# --silent will hide the progress, but also the errors: we restore error messages with --show-error
# --fail makes sure that curl returns an error instead of fetching the 404 page
ARG FULL_PHP_VERSION
WORKDIR /tmp/php
# Pre-releases (alpha, beta, RC) are not on php.net/distributions: take the tag's source from GitHub
# (without the generated files, which `buildconf` below generates)
RUN case "${FULL_PHP_VERSION}" in \
        *alpha*|*beta*|*RC*) url="https://github.com/php/php-src/archive/refs/tags/php-${FULL_PHP_VERSION}.tar.gz" ;; \
        *) url="https://www.php.net/distributions/php-${FULL_PHP_VERSION}.tar.gz" ;; \
    esac; \
    curl --location --silent --show-error --fail --retry 3 "$url" | tar xzC . --strip-components=1

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
        --enable-gd=shared \
        --with-freetype \
        --with-jpeg \
        --with-webp \
        --with-gmp=shared \
        --enable-intl=shared \
        --enable-soap=shared \
        # Needed by `pecl` to install extensions (in this image and in images built on it)
        --with-pear
RUN make -j "$(nproc)"
# Override PEAR's PHAR URL because pear.php.net is down
RUN set -xe; \
    make install PEAR_INSTALLER_URL='https://github.com/pear/pearweb_phars/raw/master/install-pear-nozlib.phar'; \
    make clean

# Optional extensions installed with `pecl`, not enabled by default
ARG PHP_VERSION
# APCu's latest release (5.1.28) does not compile with PHP 8.6: use its main branch (pinned) until 5.1.29
RUN if [ "${PHP_VERSION}" -ge 86 ]; then \
        mkdir -p /tmp/apcu && cd /tmp/apcu \
        && curl --location --silent --show-error --fail --retry 3 https://github.com/krakjoe/apcu/archive/fb2c942552a3f5dab7f4dea4afb5cf0831222c57.tar.gz \
            | tar xzC . --strip-components=1 \
        && phpize && ./configure && make && make install && cd / && rm -rf /tmp/apcu; \
    else \
        pecl install APCu; \
    fi
# phpredis' latest release (6.3.0) does not compile with PHP 8.6: use its develop branch (pinned) until the next release
RUN if [ "${PHP_VERSION}" -ge 86 ]; then \
        mkdir -p /tmp/redis && cd /tmp/redis \
        && curl --location --silent --show-error --fail --retry 3 https://github.com/phpredis/phpredis/archive/959dee1ca9ed55500cf90365419f8232eca3a99c.tar.gz \
            | tar xzC . --strip-components=1 \
        && phpize && ./configure && make && make install && cd / && rm -rf /tmp/redis; \
    else \
        pecl install redis-6.3.0; \
    fi

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
        # HTTPS certificates (curl, openssl, HTTP clients)
        ca-certificates \
        # The libraries PHP and its extensions are linked to (see the headers in `build-environment`)
        # curl
        libcurl4t64 \
        # ffi
        libffi8 \
        # gd (fonts)
        libfreetype6 \
        # gmp
        libgmp10 \
        # intl
        libicu78 \
        # gd (JPEG)
        libjpeg-turbo8 \
        # mbstring (regular expressions)
        libonig5 \
        # gd (PNG)
        libpng16-16t64 \
        # pdo_pgsql
        libpq5 \
        # readline (interactive shell `php -a`)
        libreadline8t64 \
        # sodium
        libsodium23 \
        # sqlite3, pdo_sqlite
        libsqlite3-0 \
        # openssl
        libssl3t64 \
        # gd (WebP)
        libwebp7 \
        # gd (animated WebP, PHP 8.6+)
        libwebpdemux2 \
        libwebpmux3 \
        # dom, simplexml, soap, xml, xmlreader, xmlwriter
        libxml2-16 \
        # xsl
        libxslt1.1 \
        # zip
        libzip5 \
        # zlib
        zlib1g; \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /usr/share/doc/* /usr/share/man/*; \
    chmod 1777 /tmp

RUN set -xe; \
    # Certificates: Ubuntu's bundle where OpenSSL looks for it (OPENSSLDIR)
    mkdir -p /usr/lib/ssl; \
    ln -sf /etc/ssl/certs/ca-certificates.crt /usr/lib/ssl/cert.pem; \
    [ -e /usr/lib/ssl/certs ] || ln -s /etc/ssl/certs /usr/lib/ssl/certs

COPY --link --from=build-environment /usr/local/bin/php /usr/local/bin/php
COPY --link --from=build-environment /usr/local/sbin/php-fpm /usr/local/sbin/php-fpm
# Only the .so files: the build stage also keeps them in PHP's own extension directory (for pecl and phpize)
COPY --link --from=build-environment /usr/local/lib/php/extensions/*.so /usr/local/lib/php/extensions/

COPY --link src/php.ini /etc/php/conf.d/50-bref.ini
# Before PHP 8.5, opcache is a shared extension
RUN if [ "${PHP_VERSION}" -lt 85 ]; then echo 'zend_extension=opcache' > /etc/php/conf.d/10-opcache.ini; fi
COPY --link src/php-fpm.conf /etc/php/php-fpm.conf

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

ARG PHP_VERSION
# xdebug's latest release (3.5.3) supports PHP up to 8.5: use its main branch (pinned) for PHP 8.6
RUN if [ "${PHP_VERSION}" -ge 86 ]; then \
        mkdir -p /tmp/xdebug && cd /tmp/xdebug \
        && curl --location --silent --show-error --fail --retry 3 https://github.com/xdebug/xdebug/archive/64007df3a0925808022fb87b6c6f06febf058ee2.tar.gz \
            | tar xzC . --strip-components=1 \
        && phpize && ./configure --enable-xdebug && make && make install && cd / && rm -rf /tmp/xdebug; \
    else \
        pecl install xdebug-3.5.0; \
    fi; \
    cp "$(php -r 'echo ini_get("extension_dir");')"/xdebug.so /tmp/xdebug.so


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
