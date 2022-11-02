FROM alpine:3.14

RUN apk add composer

RUN mkdir -p /opt/bref/php-fpm-runtime
WORKDIR /opt/bref/php-fpm-runtime

COPY composer.json composer.json
RUN composer install --ignore-platform-req=ext-posix --ignore-platform-req=ext-simplexml
