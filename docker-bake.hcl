group "default" {
    targets = ["build-php", "php", "php-dev"]
}

variable "CPU" {
    default = "x86"
}
variable "CPU_PREFIX" {
    default = ""
}
variable "PHP_VERSION" {
    default = "80"
}
variable "IMAGE_VERSION_SUFFIX" {
    default = "x86_64"
}
variable "DOCKER_PLATFORM" {
    default = "linux/amd64"
}
variable "PHP_COMPILATION_FLAGS" {
  default = ""
}

target "build-php" {
    dockerfile = "php-${PHP_VERSION}/Dockerfile"
    target = "build-environment"
    tags = ["bref/${CPU_PREFIX}build-php-${PHP_VERSION}"]
    args = {
        "IMAGE_VERSION_SUFFIX" = "${IMAGE_VERSION_SUFFIX}"
        "PHP_COMPILATION_FLAGS" = "${PHP_COMPILATION_FLAGS}"
    }
    platforms = ["${DOCKER_PLATFORM}"]
}

target "php" {
    dockerfile = "php-${PHP_VERSION}/Dockerfile"
    target = "function"
    tags = ["bref/${CPU_PREFIX}php-${PHP_VERSION}"]
    args = {
        "IMAGE_VERSION_SUFFIX" = "${IMAGE_VERSION_SUFFIX}"
        "PHP_COMPILATION_FLAGS" = "${PHP_COMPILATION_FLAGS}"
    }
    contexts = {
        "bref/${CPU_PREFIX}build-php-${PHP_VERSION}" = "target:build-php"
    }
    platforms = ["${DOCKER_PLATFORM}"]
}

target "php-dev" {
    dockerfile = "php-${PHP_VERSION}/Dockerfile"
    target = "dev"
    tags = ["bref/${CPU_PREFIX}php-${PHP_VERSION}-dev"]
    args = {
        "IMAGE_VERSION_SUFFIX" = "${IMAGE_VERSION_SUFFIX}"
        "PHP_COMPILATION_FLAGS" = "${PHP_COMPILATION_FLAGS}"
    }
    contexts = {
        "bref/${CPU_PREFIX}build-php-${PHP_VERSION}" = "target:build-php"
        "bref/${CPU_PREFIX}php-${PHP_VERSION}" = "target:php"
        "bref/local-api-gateway" = "docker-image://bref/local-api-gateway:latest"
    }
    platforms = ["${DOCKER_PLATFORM}"]
}
