FROM alpine:3.14

RUN apk add composer

RUN mkdir -p /opt/php-fpm-runtime
COPY composer.json /opt/php-fpm-runtime/composer.json
RUN cd /opt/php-fpm-runtime && composer install --ignore-platform-req=ext-posix --ignore-platform-req=ext-simplexml
