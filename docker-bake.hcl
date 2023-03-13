group "default" {
    targets = ["build-php", "php", "php-fpm", "console-zip", "console", "php-fpm-dev"]
}

variable "PHP_VERSION" {
    default = "80"
}

target "build-php" {
    dockerfile = "php-${PHP_VERSION}/Dockerfile"
    target     = "build-environment"
    tags       = ["bref/build-php-${PHP_VERSION}"]
    platforms  = ["linux/arm64", "linux/amd64"]
}

target "php" {
    dockerfile = "php-${PHP_VERSION}/Dockerfile"
    target     = "function"
    tags       = ["bref/php-${PHP_VERSION}"]
    contexts   = {
        "bref/build-php-${PHP_VERSION}" = "target:build-php"
    }
    platforms = ["linux/arm64", "linux/amd64"]
}

target "php-fpm" {
    dockerfile = "php-${PHP_VERSION}/Dockerfile"
    target     = "fpm"
    tags       = ["bref/php-${PHP_VERSION}-fpm"]
    contexts   = {
        "bref/build-php-${PHP_VERSION}" = "target:build-php"
        "bref/php-${PHP_VERSION}"       = "target:php"
    }
    platforms = ["linux/arm64", "linux/amd64"]
}

target "console-zip" {
    context = "layers/console"
    target  = "console-zip"
    tags    = ["bref/console-zip"]
    args    = {
        PHP_VERSION = "${PHP_VERSION}"
    }
    platforms = ["linux/arm64", "linux/amd64"]
}

target "console" {
    context = "layers/console"
    target  = "console"
    tags    = ["bref/php-${PHP_VERSION}-console"]
    args    = {
        PHP_VERSION = "${PHP_VERSION}"
    }
    contexts = {
        "bref/build-php-${PHP_VERSION}" = "target:build-php"
        "bref/php-${PHP_VERSION}"       = "target:php"
    }
    platforms = ["linux/arm64", "linux/amd64"]
}

target "php-fpm-dev" {
    context = "layers/fpm-dev"
    tags    = ["bref/php-${PHP_VERSION}-fpm-dev"]
    args    = {
        PHP_VERSION = "${PHP_VERSION}"
    }
    contexts = {
        "bref/build-php-${PHP_VERSION}" = "target:build-php"
        "bref/php-${PHP_VERSION}"       = "target:php"
        "bref/php-${PHP_VERSION}-fpm"   = "target:php-fpm"
        "bref/local-api-gateway"        = "docker-image://bref/local-api-gateway:latest"
    }
    platforms = ["linux/arm64", "linux/amd64"]
}
