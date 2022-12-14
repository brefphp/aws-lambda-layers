#!/bin/sh

# Fail on error
set -e

# We don't compile PHP anymore, so the only way to configure where PHP looks for
# .ini files is via the PHP_INI_SCAN_DIR environment variable.
# Note: we use that weird syntax to set the variable only if it's not already set (can be overridden)
: "${PHP_INI_SCAN_DIR:=/opt/bref/etc/php/conf.d:/var/task/php/conf.d}"
export PHP_INI_SCAN_DIR

# We redirect stderr to stdout so that everything
# written on the output ends up in Cloudwatch automatically
/opt/bin/php "/opt/bref/php-fpm-runtime/vendor/bref/php-fpm-runtime/src/bootstrap.php" 2>&1
