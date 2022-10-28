ARG PHP_VERSION
ARG CPU_PREFIX

FROM alpine:3.14 as composer

RUN apk add composer

RUN mkdir -p /opt/bref/console-runtime
WORKDIR /opt/bref/console-runtime
COPY composer.json composer.json
RUN composer install --ignore-platform-req=ext-posix --ignore-platform-req=ext-simplexml

FROM bref/${CPU_PREFIX}php-$PHP_VERSION

# Overwrite the "function" bootstrap file
COPY bootstrap.php /opt/bref/bootstrap.php

COPY --from=composer /opt/bref/console-runtime /opt/bref/console-runtime
