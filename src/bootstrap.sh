#!/bin/sh

# Fail on error
set -e

# Lambda does not apply the image's ENV to custom runtimes: set what PHP needs here.
# /usr/local/bin first: it holds the php-fpm wrapper for Bref v3, see php-fpm-v3-compat.sh
export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export LAMBDA_TASK_ROOT="${LAMBDA_TASK_ROOT:-/var/task}"
# The handler is passed as the first argument (Lambda container images get it from
# /lambda-entrypoint.sh, which sets _HANDLER)
export _HANDLER="${_HANDLER:-$1}"

while true
do
    # We redirect stderr to stdout so that everything
    # written on the output ends up in Cloudwatch automatically
    php "/var/runtime/bootstrap.php" 2>&1
done
