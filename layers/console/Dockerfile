# syntax = docker/dockerfile:1.4
ARG PHP_VERSION
ARG CPU_PREFIX

FROM alpine:3.14 as composer

RUN apk add composer

RUN mkdir -p /opt/bref/console-runtime
WORKDIR /opt/bref/console-runtime
COPY --link composer.json composer.json
RUN composer install --ignore-platform-req=ext-posix --ignore-platform-req=ext-simplexml

FROM bref/${CPU_PREFIX}php-$PHP_VERSION as console

# Overwrite the "function" bootstrap file
COPY --link bref/bootstrap.php /opt/bref/bootstrap.php

COPY --link --from=composer /opt/bref/console-runtime /opt/bref/console-runtime
