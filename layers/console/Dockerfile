# syntax = docker/dockerfile:1.4
ARG PHP_VERSION
ARG CPU_PREFIX


# This image only contains what's going in the layer zip file,
# i.e. the files specific to the console layer.
# It's used to create the layer zip file.
FROM alpine:3.14 as console-zip

# Overwrite the "function" bootstrap
COPY --link bootstrap.sh /opt/bootstrap
# Copy files to /var/runtime to support deploying as a Docker image
COPY --link bootstrap.sh /var/runtime/bootstrap


# This image is published to Docker Hub and replicates Lambda
FROM bref/${CPU_PREFIX}php-$PHP_VERSION as console

# Copy the console layer into /opt
COPY --link --from=console-zip /opt /opt
COPY --link --from=console-zip /var/runtime/bootstrap /var/runtime/bootstrap
