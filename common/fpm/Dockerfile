FROM alpine:3.14

RUN apk add composer

RUN mkdir -p /opt/php-fpm-runtime

RUN cd /opt/php-fpm-runtime && composer require bref/php-fpm-runtime:dev-main --ignore-platform-reqs
