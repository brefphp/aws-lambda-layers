group "default" {
  targets = ["build-php", "php", "php-fpm", "console", "php-fpm-dev"]
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

target "base-devel" {
  dockerfile = "base-devel/cpu-${CPU}.Dockerfile"
  tags = ["bref/base-devel-${CPU}"]
}

target "build-php" {
  dockerfile = "php-${PHP_VERSION}/cpu-${CPU}.Dockerfile"
  target = "build-environment"
  tags = ["bref/${CPU_PREFIX}build-php-${PHP_VERSION}"]
  contexts = {
    // Dependency to the base image
    "bref/base-devel-${CPU}" = "target:base-devel"
  }
}

target "php" {
  dockerfile = "php-${PHP_VERSION}/cpu-${CPU}.Dockerfile"
  target = "function"
  tags = ["bref/${CPU_PREFIX}php-${PHP_VERSION}"]
  contexts = {
    "bref/base-devel-${CPU}" = "target:base-devel"
    "bref/${CPU_PREFIX}build-php-${PHP_VERSION}" = "target:build-php"
  }
}

target "fpm-internal-src" {
  context = "layers/fpm"
  tags = ["bref/fpm-internal-src"]
}

target "php-fpm" {
  dockerfile = "php-${PHP_VERSION}/cpu-${CPU}.Dockerfile"
  target = "fpm"
  tags = ["bref/${CPU_PREFIX}php-${PHP_VERSION}-fpm"]
  contexts = {
    "bref/base-devel-${CPU}" = "target:base-devel"
    "bref/${CPU_PREFIX}build-php-${PHP_VERSION}" = "target:build-php"
    "bref/${CPU_PREFIX}php-${PHP_VERSION}" = "target:php"
    "bref/fpm-internal-src" = "target:fpm-internal-src"
  }
}

target "console" {
  context = "layers/console"
  target = "console"
  tags = ["bref/${CPU_PREFIX}php-${PHP_VERSION}-console"]
  args = {
    PHP_VERSION = "${PHP_VERSION}"
    CPU_PREFIX = "${CPU_PREFIX}"
  }
  contexts = {
    "bref/base-devel-${CPU}" = "target:base-devel"
    "bref/${CPU_PREFIX}build-php-${PHP_VERSION}" = "target:build-php"
    "bref/${CPU_PREFIX}php-${PHP_VERSION}" = "target:php"
  }
}

target "php-fpm-dev" {
  context = "layers/fpm-dev"
  tags = ["bref/${CPU_PREFIX}php-${PHP_VERSION}-fpm-dev"]
  args = {
    PHP_VERSION = "${PHP_VERSION}"
    CPU_PREFIX = "${CPU_PREFIX}"
  }
  contexts = {
    "bref/base-devel-${CPU}" = "target:base-devel"
    "bref/${CPU_PREFIX}build-php-${PHP_VERSION}" = "target:build-php"
    "bref/${CPU_PREFIX}php-${PHP_VERSION}" = "target:php"
    "bref/${CPU_PREFIX}php-${PHP_VERSION}-fpm" = "target:php-fpm"
    "bref/local-api-gateway" = "docker-image://bref/local-api-gateway:latest"
  }
}
