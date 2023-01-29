# syntax = docker/dockerfile:1.4
ARG PHP_VERSION
ARG CPU_PREFIX

FROM alpine:3.14 as composer

RUN apk add composer

RUN mkdir -p /opt/bref/console-runtime
WORKDIR /opt/bref/console-runtime
COPY --link composer.json composer.json
RUN composer install --ignore-platform-req=ext-posix --ignore-platform-req=ext-simplexml


# This image only contains what's going in the layer zip file,
# i.e. the files specific to the console layer.
# It's used to create the layer zip file.
FROM scratch as console-zip

RUN mkdir -p /opt/bref

# Overwrite the "function" bootstrap file
COPY --link bref/bootstrap.php /opt/bref/bootstrap.php

COPY --link --from=composer /opt/bref/console-runtime /opt/bref/console-runtime


# This image is published to Docker Hub and replicates Lambda
FROM bref/${CPU_PREFIX}php-$PHP_VERSION as console

# Copy the console layer into /opt
COPY --link --from=console-zip /opt /opt
