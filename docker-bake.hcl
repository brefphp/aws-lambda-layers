group "default" {
  targets = ["base-devel", "build-php"]
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
