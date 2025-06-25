# PHP layers for AWS Lambda

⚠️⚠️⚠️

> **Warning**
> **You are probably in the wrong place.**

If you are new to PHP on Lambda or Bref, **check out [bref.sh](https://bref.sh) instead**.

⚠️⚠️⚠️

This project is a low-level internal piece of the Bref project. It contains the scripts to build the AWS Lambda layers and Docker images.

---

## Contributing

Thank you for diving into this very complex part of Bref.

If you are submitting a pull request to this repository, you probably want to test your changes:

1. Build the Docker images and the Lambda layers (zip files) locally (to make sure it works).
2. Run the test scripts.
3. Publish the Lambda layers to your AWS account and test them in a real Lambda.

**For minor changes** (e.g. upgrading a version) it is faster and easier to open a pull request. The layers will be built faster in CI and the test results will be available in a few minutes.

### Requirements

- `make`
- `zip`
- Docker
- AWS CLI (if publishing layers)
- AWS credentials set up locally (if publishing layers)

### Building

> **Warning:**
>
> On macOS, do not enable [the experimental Rosetta emulation](https://docs.docker.com/desktop/release-notes/#4160). This causes a Segmentation Fault when running `php-fpm` in the Docker images (as of January 2023, this may have been fixed since).

You can build Docker images and Lambda layers locally:

```sh
# Make x86 layers (the default)
make

# Make ARM layers
make CPU=arm
```

It will create the Docker images on your machine, and generate the Lambda layer zip files in `./output`. It takes some time to build the Docker images (especially to build the images on the other platform, e.g. the ARM images if you are on an Intel processor).

### Testing

After building the images, run the automated tests:

```sh
make test
# and/or
make test CPU=arm
```

> **Note**
> If automated tests fail, you can test layers manually using Docker. Check out [the README in `tests/`](tests/README.md).

### Uploading layers

You can build everything _and_ upload Lambda layers to your AWS account. You will need to set up local AWS credentials. The following environment variables are recognized:

- `AWS_PROFILE` (optional): an AWS profile to use (instead of the default one).
- `ONLY_REGION` (optional): if set, layers will only be published to this region, instead of _all_ regions (useful for testing).

You can set those by creating a `.env` file:

```sh
cp .env.example .env 

# Now edit the .env file

# Then build layers:
make
make CPU=arm

# Then publish layers:
make upload-layers
make upload-layers CPU=arm
```

The published Lambda layers will be public (they are readonly anyway). You can find them in your AWS console (AWS Lambda service). Feel free to delete them afterwards.

### Debugging

If you ever need to check out the content of a layer, you can start a `bash` terminal inside the Docker image:

```sh
docker run --rm -it --entrypoint=bash bref/php-84
```

> **Note:**
> 
> `ldd` is a linux utility that will show libraries (`.so` files) used by a binary/library. For example: `ldd /opt/bin/php` or `ldd /opt/bref/extensions/curl.so`. That helps to make sure we include all the libraries needed by PHP extensions in the layers.
> 
> However, `ldd` fails when running on another CPU architecture. So instead of `ldd`, we can use `LD_TRACE_LOADED_OBJECTS=1 /opt/bin/php` (see https://stackoverflow.com/a/35905007/245552).

### Supporting a new PHP version

The general idea is to copy `php-82` into `php-83`. Search/replace `php-82` with `php-83`, update the PHP version, update the `Makefile`, and adapt anything else if needed.

### Supporting new regions

Check out `utils/lambda-publish/Makefile` to add more regions.

## How this repository works

### Repository workflow

1. A PR is opened on this repository.
    - GitHub Actions will build the layers and test them (but not publish them).
2. The PR is merged by a Bref maintainer.
3. A new release is tagged by a Bref maintainer.
4. GitHub Actions will build the layers, test them, and publish the layers and Docker images.
5. The "update layer versions" job in [brefphp/bref](https://github.com/brefphp/bref) will be triggered automatically.
    - A pull request will be opened with an updated `layers.json` file.
    - A Bref maintainer can then merge the PR and manually release a new Bref version.
6. The "update layer versions and release" job in [brefphp/layers.js](https://github.com/brefphp/layers.js) will be triggered automatically.
    - The `layers.json` file will be updated with new layer versions.
    - A new GitHub tag and release will be created.
    - A new release of the `@bref.sh/layers` NPM package will be published.

### How Lambda layers work?

In a nutshell, a Lambda Layer is a `zip` file. Its content is extracted to `/opt` when a Lambda starts.

Anything we want to make available in AWS Lambda is possible by preparing the right files and packing them into a layer. To work properly, these files need to be compatible with the Lambda environment. AWS provides Docker images (e.g. `public.ecr.aws/lambda/provided:al2-x86_64`) that replicate it.

### Lambda layers structure

```sh
/opt/ # where layers are unzipped/can add files

    bin/ # where layers can add binaries
        php # the PHP binary
        php-fpm # the PHP-FPM binary (only for FPM layers)

    lib/ # system libraries needed by Bref

    bref/ # custom Bref files
        extensions/ # PHP extensions
            ...
        etc/php/conf.d/ # automatically loaded php.ini files
            bref.ini

    bootstrap # entrypoint of the runtime

/var/runtime/
    bootstrap # duplicated entrypoint, used when running in Docker

/var/task # the code of the Lambda function
    php/conf.d/ # also automatically loaded php.ini files
```

In the "build" Docker images (used by example to build extra extensions), there is a `/bref/lib-copy/copy-dependencies.php` script that helps automatically copying the system dependencies of a binary or PHP extension. It can be used like so:

```sh
php /bref/lib-copy/copy-dependencies.php /opt/bref/extensions/apcu.so /opt/lib
```

In Bref v1, we used to manually identify (via `ldd`) and copy these system libraries, but this new script automates everything. It is recommended to use it.

### The php-xx folders

The Dockerfile attempts at a best-effort to follow a top-down execution process for easier reading.

It starts from an AWS-provided Docker image and compiles the system libraries that we will need to use to compile PHP (the PHP build requires more recent version than what `yum install` provides, so we need to compile them, which is slow.

Then, PHP is compiled. All the compilation happens in `/tmp`.

We then copy the PHP binary in `/opt/bin` and all PHP extensions in `/opt/...`. Indeed, `/opt` is the target directory of AWS Lambda layers.

Then, we need to copy to `/opt` all the system libraries (`*.so` files) used by PHP and the extensions. To do so, we have a script that parses all the system dependencies of `/opt/bin/php` and extensions, and automatically copies them to `/opt/lib` (a directory automatically scanned by AWS Lambda).

Finally, for each layer, we re-start from scratch from the empty AWS Lambda Docker images (using `FROM`, i.e. multi-stage builds) and we copy `/opt`. That gives us an "empty" Docker images with only `/opt` populated, just like on AWS Lambda when the PHP layers are unzipped.

That will also let us zip `/opt` to create the layers.

## Design decisions log

### Installing PHP from a distribution

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
