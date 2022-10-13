#!/bin/sh

# Fail on error
set -e

# We don't compile PHP anymore, so the only way to configure where PHP should be looking for
# .ini files is via the PHP_INI_SCAN_DIR environment variable.
export PHP_INI_SCAN_DIR="/opt/php-ini/:/var/task/php/conf.d/"

# We redirect stderr to stdout so that everything
# written on the output ends up in Cloudwatch automatically
/opt/bin/php "/opt/php-fpm-runtime/vendor/bref/php-fpm-runtime/src/bootstrap.php" 2>&1
