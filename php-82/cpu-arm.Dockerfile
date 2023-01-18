# syntax = docker/dockerfile:1.4
FROM bref/base-devel-arm as build-environment

ENV VERSION_PHP=8.2.0

RUN mkdir -p /tmp/php
WORKDIR /tmp/php

# PHP Build
# https://github.com/php/php-src/releases
# Needs:
#   - zlib
#   - libxml2
#   - openssl
#   - readline
#   - sodium

# Download and unpack the source code
# --location will follow redirects
# --silent will hide the progress, but also the errors: we restore error messages with --show-error
# --fail makes sure that curl returns an error instead of fetching the 404 page
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
        # necessary for `pecl` to work (to install PHP extensions)
        --with-pear
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


# ---------------------------------------------------------------
# Now we copy everything we need for the layers into /opt (location of the layers)
RUN mkdir /opt/bin \
&&  mkdir /opt/lib \
&&  mkdir -p /opt/bref/extensions

# Copy the PHP binary into /opt/bin
RUN cp ${INSTALL_DIR}/bin/php /opt/bin/php && chmod +x /opt/bin/php

# Copy all the external PHP extensions
RUN cp $(php -r 'echo ini_get("extension_dir");')/* /opt/bref/extensions/

# Copy all the required system libraries from:
# - /lib | /lib64 (system libraries installed with `yum`)
# - /tmp/bref/bin | /tmp/bref/lib | /tmp/bref/lib64 (libraries compiled from source)
# into `/opt` (the directory of Lambda layers)
COPY --link utils/lib-check /bref/lib-copy
RUN php /bref/lib-copy/copy-dependencies.php /opt/bin/php /opt/lib
RUN php /bref/lib-copy/copy-dependencies.php /opt/bref/extensions/apcu.so /opt/lib
RUN php /bref/lib-copy/copy-dependencies.php /opt/bref/extensions/intl.so /opt/lib
RUN php /bref/lib-copy/copy-dependencies.php /opt/bref/extensions/opcache.so /opt/lib
RUN php /bref/lib-copy/copy-dependencies.php /opt/bref/extensions/pdo_mysql.so /opt/lib
RUN php /bref/lib-copy/copy-dependencies.php /opt/bref/extensions/pdo_pgsql.so /opt/lib


# ---------------------------------------------------------------
# Start from a clean image to copy only the files we need
FROM public.ecr.aws/lambda/provided:al2-arm64 as isolation

COPY --link --from=build-environment /opt /opt

FROM isolation as function

COPY --link layers/function/bref.ini /opt/bref/etc/php/conf.d/
COPY --link layers/function/bref-extensions.ini /opt/bref/etc/php/conf.d/

COPY --link layers/function/bootstrap.sh /opt/bootstrap
# Copy files to /var/runtime to support deploying as a Docker image
COPY --link layers/function/bootstrap.sh /var/runtime/bootstrap
RUN chmod +x /opt/bootstrap && chmod +x /var/runtime/bootstrap

COPY --link layers/function/bootstrap.php /opt/bref/bootstrap.php


# Up until here the entire file has been designed as a top-down reading/execution.
# Everything necessary for the `function` layer has been installed, isolated and
# packaged. Now we'll go back one step and start from the extensions so that we
# can install fpm. Then we'll start the fpm layer and quickly isolate fpm.

FROM build-environment as fpm-extension

RUN cp ${INSTALL_DIR}/sbin/php-fpm /opt/bin/php-fpm
RUN php /bref/lib-copy/copy-dependencies.php /opt/bin/php-fpm /opt/lib


FROM isolation as fpm

COPY --link --from=fpm-extension /opt /opt

COPY --link layers/fpm/bref.ini /opt/bref/etc/php/conf.d/
# TODO merge in the first file now that it's a much simpler file?
COPY --link layers/fpm/bref-extensions.ini /opt/bref/etc/php/conf.d/

COPY --link layers/fpm/bootstrap.sh /opt/bootstrap
# Copy files to /var/runtime to support deploying as a Docker image
COPY --link layers/fpm/bootstrap.sh /var/runtime/bootstrap
RUN chmod +x /opt/bootstrap && chmod +x /var/runtime/bootstrap

COPY --link layers/fpm/php-fpm.conf /opt/bref/etc/php-fpm.conf

COPY --link --from=bref/fpm-internal-src /opt/bref/php-fpm-runtime /opt/bref/php-fpm-runtime
