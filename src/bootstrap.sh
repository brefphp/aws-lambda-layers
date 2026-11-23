#!/bin/sh

# Fail on error
set -e

# Lambda does not apply the image's ENV to custom runtimes: set what PHP needs here.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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
