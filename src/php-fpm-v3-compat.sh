#!/bin/sh
# Bref v3 (bref/bref 3.x) starts `php-fpm --fpm-config /opt/bref/etc/php-fpm.conf`.
# Nothing is in /opt anymore: point it to /etc/php/php-fpm.conf.
# TODO remove once bref/bref v4 reads /etc/php/php-fpm.conf
set -e
for arg do
    shift
    if [ "$arg" = "/opt/bref/etc/php-fpm.conf" ]; then
        arg=/etc/php/php-fpm.conf
    fi
    set -- "$@" "$arg"
done
exec /usr/local/sbin/php-fpm "$@"
