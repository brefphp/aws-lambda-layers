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

Add it to `VERSIONS` in `docker-bake.hcl`, to the lists in `Makefile`, `tests/Makefile` and the GitHub workflows.

## How this repository works

### Repository workflow

1. A PR is opened on this repository.
    - GitHub Actions will build the images and test them (but not publish them).
2. The PR is merged by a Bref maintainer.
3. A new release is tagged by a Bref maintainer.
4. GitHub Actions will build the images for both architectures, test them, and publish multi-architecture images to Docker Hub.

### The images

One `Dockerfile` builds every PHP version (`PHP_VERSION` and `VERSION_PHP` come from `docker-bake.hcl`), for `linux/amd64` and `linux/arm64`:

- `bref/php-XX`: the runtime image.
- `bref/php-XX-dev`: the same with xdebug, Composer and a local API Gateway, for local development.
- `bref/build-php-XX`: the build environment, to compile extra PHP extensions against the same PHP.

The `Dockerfile` reads top-down:

1. On Ubuntu, compile PHP with `-O2`.
   Extensions enabled by default are compiled statically, optional ones as shared extensions.
2. Start again from a clean Ubuntu with only the libraries PHP needs at runtime, copy PHP, its
   configuration and Bref's bootstrap.

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

## Design decisions log

### Bref v4: PHP compiled on Ubuntu

Bref v3 compiled PHP on Amazon Linux 2023 into `/opt` and shipped it as Lambda layers (zip files, limited to 250 MB). Bref v4 ships runtime images, measured against alternatives on real Lambda in 2026:

- **The base OS does not change performance**: the same PHP build on Amazon Linux 2023, Ubuntu 24.04, Ubuntu 26.04 and Debian 13 shows no measurable difference on cold starts, warm requests or CPU. Ubuntu 26.04 LTS was chosen for its up-to-date libraries (ICU 78, libxml2 2.15, ImageMagick 7, OpenSSL 3.5, gcc 15), apt packages for almost any extension dependency, familiarity, and support until 2031. Amazon Linux 2023's libraries are older (ICU 67, libxml2 2.10, SQLite 3.40 that Bref v3 had to recompile).
- **PHP is compiled, not installed from packages** (e.g. Ondřej Surý's PPA): packaged `php` and `php-fpm` are separate builds that cannot share opcache's file cache, which made every Laravel cold start ~420 ms slower; their shared extensions are loaded at every PHP start; we cannot choose the compilation flags; and security releases can take longer to be packaged.
- **`-O2` instead of `-Os`**: layers had a size limit, images do not. PHP code runs 16-18% faster for 1 MB more.
- **Optional extensions installed but not enabled**: Lambda loads images lazily, so installed-but-unused extensions cost nothing measurable at cold start.


### Bref v1-v3: installing PHP from a distribution

#### First iteration

Compiling PHP is a complex process for the average PHP Developer. It takes a fair amount of time
and can be cumbersome. Using `remi-collet` as a PHP distributor greatly simplifies and help the
installation process. The code is more readable and approachable. Remi also distribute releases
even before they are announced on the PHP Internal Mailing List by the Release Manager.

The biggest downside is that we're no longer in control of compiling new releases whenever we want.
But for x86 architecture, we see that using remi-collet will not be a problem for this.
We can see the impact of this on arm64 (Graviton2 Support). Since remi-collet doesn't distribute arm64,
we may have to rely on `amazon-linux-extras`, which is 5 months behind (as of this writing) with PHP 8.0.8.

Useful links:

- https://blog.remirepo.net/pages/English-FAQ#scl
- https://rpms.remirepo.net/wizard/

#### Second iteration

We discovered an issue with using Remi's built images ([#42](https://github.com/brefphp/aws-lambda-layers/issues/42)): HTTP2 support was not compiled in CURL. Remi's packages explicitly don't intent to support it, and our only choice is to compile PHP (it's not an extension that can be installed after the fact).

The previous decision (use Remi's repo) is reverted during Bref v2's beta and we go back to compiling PHP from scratch.

Some benefits:

- We can have identical compilation scripts between x86 and ARM, which simplifies the code a lot
- We can provide recent PHP versions for ARM, including PHP 8.2 (wasn't supported by Amazon Linux Extra before)
- We have identical system libraries and dependencies on x86 and ARM, which should avoid weird differences and bugs

##### Bundling extensions

While developing a new Runtime, the first attempt was to provide an "alpine-like" Bref Layer: only the PHP
binary and no extension (or minimal extensions) installed. This turned out to slow down the process
by a big factor because every layer needs to be compiled for multiple PHP versions and deployed
across 21 AWS Region (at this time). Except for php-intl, most extensions are extremely small and lightweight.
The benefits of maintaining a lightweight layer long-term didn't outweigh the costs at this time.

##### Variables vs Repetitive Code

Before landing on the current architecture, there was several attempts (9 to be exact) on a back-and-forth
between more environment variables vs more repetitive code. Environment variables grows complexity because
they require contributors to understand how they intertwine with each other. We have layers, php version and
CPU architecture. A more "reusable" Dockerfile or docker compose requires a more complex Makefile. In contrast,
a simpler and straight-forward Makefile requires more code duplication for Docker and Docker Compose.
The current format makes it so that old PHP layers can easily be removed by dropping an entire folder
and a new PHP Version can be added by copying an existing folder and doing search/replace on the
PHP version. It's a hard balance between a process that allows parallelization, code reusability and
readability.

##### Layer Publishing

It would have been ideal to be able to upload the layers to a single S3 folder and then "publish" a new layer by pointing it to the existing S3Bucket/S3Key. However, AWS Lambda does not allow publishing layers from a bucket in another region. Layers must be published on each region individually, so instead we upload the zip files for every layer published.

Parallelization of all regions at once often leads to network crashing. The strategy applied divides AWS
regions in chunks (7 to be precise) and tries to publish 7 layers at a time.

##### AWS CodeBuild vs GitHub Actions

AWS CodeBuild was used for Bref v1 builds, as it lets us use large instances to build faster. Bref 1 layers took an hour to build. Additionally, using CodeBuild allowed to avoid using AWS access keys to publish layers.

For Bref v2, we now build in GitHub Actions because it's simpler, entirely public and easier to follow for maintainers and contributors.

To make builds 10× to 20× faster, we use https://depot.dev thanks who generously offered to support Bref for free ❤️

Additionally, using OIDC we can authorize this repository to publish into the AWS account with very restricted permissions _without_ using AWS access keys (assume role, just like CodeBuild).

##### Automation tests

The `tests` folder contains multiple PHP scripts that are executed inside a Docker container that Bref builds. These scripts are supposed to ensure that the PHP version is expected, PHP extensions are correctly installed and available and PHP is correctly configured. Some acceptance tests uses AWS Runtime Interface Emulator (RIE) to test whether a Lambda invocation is expected to work.
