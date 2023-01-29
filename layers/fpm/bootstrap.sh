#!/bin/sh

# Fail on error
set -e

# We redirect stderr to stdout so that everything
# written on the output ends up in Cloudwatch automatically
/opt/bin/php "/opt/bref/php-fpm-runtime/vendor/bref/php-fpm-runtime/src/bootstrap.php" 2>&1
