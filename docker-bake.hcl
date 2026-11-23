group "default" {
    targets = ["build-php", "php", "php-dev"]
}

# e.g. "85", see FULL_PHP_VERSIONS below
variable "PHP_VERSION" {
    default = "85"
}
# Comma-separated, e.g. "linux/arm64" for a local build, both for a release
variable "DOCKER_PLATFORM" {
    default = "linux/amd64,linux/arm64"
}

# Supported PHP versions: https://www.php.net/downloads
variable "FULL_PHP_VERSIONS" {
    default = {
        "83" = "8.3.37"
        "84" = "8.4.28"
        "85" = "8.5.13"
    }
}

target "base" {
    dockerfile = "Dockerfile"
    args = {
        "PHP_VERSION" = "${PHP_VERSION}"
        "FULL_PHP_VERSION" = "${FULL_PHP_VERSIONS[PHP_VERSION]}"
    }
    platforms = split(",", "${DOCKER_PLATFORM}")
}

target "build-php" {
    inherits = ["base"]
    target = "build-php"
    tags = ["bref/build-php-${PHP_VERSION}"]
}

target "php" {
    inherits = ["base"]
    target = "php"
    tags = ["bref/php-${PHP_VERSION}"]
}

target "php-dev" {
    inherits = ["base"]
    target = "dev"
    tags = ["bref/php-${PHP_VERSION}-dev"]
    contexts = {
        "bref/local-api-gateway" = "docker-image://bref/local-api-gateway:latest"
    }
}
