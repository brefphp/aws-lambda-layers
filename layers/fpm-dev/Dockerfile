ARG CPU_PREFIX
ARG PHP_VERSION


FROM bref/${CPU_PREFIX}build-php-$PHP_VERSION as build_extensions

ARG PHP_VERSION

RUN mkdir -p /opt/bref/extensions

# Install xdebug
RUN pecl install xdebug
RUN cp $(php -r "echo ini_get('extension_dir');")/xdebug.so /opt/bref/extensions

# Install Blackfire
# https://blackfire.io/docs/up-and-running/installation?action=install&mode=full&version=latest&mode=full&location=server&os=manual&language=php#install-the-php-probe
ARG BLACKFIRE_VERSION=1.86.1
RUN if [[ $CPU_PREFIX == "" ]]; then curl -A "Docker" -o /opt/bref/extensions/blackfire.so -L -s "https://packages.blackfire.io/binaries/blackfire-php/$BLACKFIRE_VERSION/blackfire-php-linux_amd64-php-"$PHP_VERSION".so"; fi
RUN if [[ $CPU_PREFIX == "arm-" ]]; then curl -A "Docker" -o /opt/bref/extensions/blackfire.so -L -s "https://packages.blackfire.io/binaries/blackfire-php/$BLACKFIRE_VERSION/blackfire-php-linux_arm64-php-"$PHP_VERSION".so"; fi


FROM bref/${CPU_PREFIX}php-${PHP_VERSION}-fpm

COPY --from=build_extensions  /opt /opt
COPY bref-entrypoint.sh /
RUN chmod +x /bref-entrypoint.sh

# Install node to run the JS app below
RUN curl --silent --location https://rpm.nodesource.com/setup_16.x | bash -
RUN yum install --setopt=skip_missing_names_on_install=False -y nodejs

# Install the bref/local-api-gateway app in our container (avoids running 2 containers)
COPY --from=bref/local-api-gateway /app /local-api-gateway
EXPOSE 8000

# Add `php/conf.dev.d` to the path where PHP looks for configuration files
ENV PHP_INI_SCAN_DIR="$PHP_INI_SCAN_DIR:/var/task/php/conf.dev.d"

# Originally the entrypoint is `/lambda-entrypoint.sh` and CMD contains the handler name
# We override the entrypoint to run our own logic
ENTRYPOINT [ "/bref-entrypoint.sh" ]
