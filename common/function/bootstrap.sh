#!/bin/sh

# Fail on error
set -e

# We don't compile PHP anymore, so the only way to configure where PHP looks for
# .ini files is via the PHP_INI_SCAN_DIR environment variable.
export PHP_INI_SCAN_DIR="/opt/bref/etc/php/conf.d/:/var/task/php/conf.d/"

while true
do
    if [ -z "${EXPERIMENTAL_AWS_LAMBDA_EXEC_WRAPPER}" ]; then
        # Default behavior

        # We redirect stderr to stdout so that everything
        # written on the output ends up in Cloudwatch automatically
        /opt/bin/php "/opt/bref/bootstrap.php" 2>&1
    else
        # A wrapper script is configured
        # See https://docs.aws.amazon.com/lambda/latest/dg/runtimes-modify.html#runtime-wrapper
        # NOTE: EXPERIMENTAL FEATURE, DO NOT USE!!!
        # Note: If you do use it, open an issue or GitHub discussion or Slack thread
        # and let us know why it's useful to you, we might turn it into an official feature
        "${EXPERIMENTAL_AWS_LAMBDA_EXEC_WRAPPER}" /opt/bin/php "/opt/bref/bootstrap.php" 2>&1
    fi
done
