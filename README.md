# PHP runtimes for AWS Lambda

⚠️⚠️⚠️

> **Warning**
> **You are probably in the wrong place.**

If you are new to PHP on Lambda or Bref, **check out [bref.sh](https://bref.sh) instead**.

⚠️⚠️⚠️

This project is a low-level internal piece of the Bref project. It contains the scripts to build the Bref runtime images: PHP, its extensions and configuration, and Bref's bootstrap, for each supported PHP version.

---

## Contributing

Thank you for diving into this very complex part of Bref.

If you are submitting a pull request to this repository, you probably want to test your changes:

1. Build the Docker images locally (to make sure it works).
2. Run the test scripts.

**For minor changes** (e.g. upgrading a version) it is faster and easier to open a pull request. The images will be built faster in CI and the test results will be available in a few minutes.

### Requirements

- `make`
- Docker

### Building

Build the images of every PHP version for your machine's architecture:

```sh
make
```

Or one PHP version, or another architecture (emulated, much slower):

```sh
make docker-images-php-85
make docker-images-php-85 DOCKER_PLATFORM=linux/amd64
```

PHP versions and their exact release are listed in `docker-bake.hcl`.

### Testing

After building the images, run the automated tests:

```sh
make test
# or
make test-85
```

> **Note**
> If automated tests fail, you can test the images manually using Docker. Check out [the README in `tests/`](tests/README.md).

### Debugging

You can start a `bash` terminal inside an image:

```sh
docker run --rm -it --entrypoint=bash bref/php-85
```

### Supporting a new PHP version

Add it to `FULL_PHP_VERSIONS` in `docker-bake.hcl`, to the lists in `Makefile`, `tests/Makefile` and the GitHub workflows.

## How this repository works

### Repository workflow

1. A PR is opened on this repository.
    - GitHub Actions will build the images and test them (but not publish them).
2. The PR is merged by a Bref maintainer.
3. A new release is tagged by a Bref maintainer.
4. GitHub Actions will build the images for both architectures and publish multi-architecture images to Docker Hub.

### The images

One `Dockerfile` builds every PHP version (`PHP_VERSION` and `FULL_PHP_VERSION` come from `docker-bake.hcl`), for `linux/amd64` and `linux/arm64`:

- `bref/php-XX`: the runtime image.
- `bref/php-XX-dev`: the same with xdebug, Composer and a local API Gateway, for local development.
- `bref/build-php-XX`: the build environment, to compile extra PHP extensions against the same PHP.

### Runtime image structure

```sh
/usr/local/bin/php
/usr/local/sbin/php-fpm
/usr/local/lib/php/extensions/ # optional extensions (not enabled), `extension_dir`

/etc/php/
    conf.d/ # php.ini files loaded automatically (Bref's settings)
    php-fpm.conf

/var/runtime/
    bootstrap # entrypoint of the runtime: starts Bref's runtime (bootstrap.php)
    bootstrap.php

/var/task # the code of the Lambda function
    php/conf.d/ # also automatically loaded php.ini files

/opt # empty: Lambda layers are mounted here, and would hide anything else
    bref/etc/php/conf.d/ # php.ini files of extension layers, loaded automatically
```

The image must contain `/var/task` and `/etc/hosts`: Lambda mounts the code on the first and rewrites the second at startup. Without them, the execution environment never starts (no logs, only an "insufficient capacity" error).
