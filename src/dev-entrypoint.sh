#!/bin/sh

set -e

# If a command is passed, run it (like "php artisan")
if [ "$1" ];
then
    exec "$@"
    exit 0
fi

# Check that the $HANDLER variable is set
if [ -z "$HANDLER" ];
then
    echo "The HANDLER environment variable is not set and no command was provided."
    echo ""
    echo "If you want to run the web server, set the of the Lambda handler in HANDLER,"
    echo "for example 'index.php' or 'public/index.php'."
    echo ""
    echo "If you want to run a command, provide it as a Docker command."
    exit 1
fi

# Run the fake API Gateway
# (forces fake AWS credentials so that the Lambda client works)
# We point it to the local Lambda RIE and run in the background.
# Yes, 2 processes in 1 container is bad. Guess what, I have flaws.
# What are they? Oh, I don't know. I sing in the shower. Sometimes
# I spend too much time volunteering. Occasionally I'll hit somebody
# with my car. So sue me... No, don't sue me. That is the opposite
# of the point that I'm trying to make.
AWS_ACCESS_KEY_ID='fake' AWS_SECRET_ACCESS_KEY='fake' \
    TARGET=localhost:8080 \
    node /local-api-gateway/dist/index.js &

# Run the original AWS Lambda entrypoint (RIE) with the handler argument
/lambda-entrypoint.sh "$HANDLER"
