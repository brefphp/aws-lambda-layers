FROM alpine:3.14

RUN apk add composer

RUN mkdir -p /opt/bref-internal-src

RUN cd /opt/bref-internal-src && composer require bref/bref:^1 --ignore-platform-reqs
