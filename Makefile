# Load .env file if it exists
-include .env
export # export all variables defined in .env

# Images are multi-architecture (linux/amd64 + linux/arm64).
# `make docker-images` builds and loads them *locally* for one architecture, the current one by
# default: set DOCKER_PLATFORM=linux/amd64 or linux/arm64 to choose.
ifeq ($(shell uname -m), arm64)
  DOCKER_PLATFORM ?= linux/arm64
else ifeq ($(shell uname -m), aarch64)
  DOCKER_PLATFORM ?= linux/arm64
else
  DOCKER_PLATFORM ?= linux/amd64
endif
export DOCKER_PLATFORM

# By default, Docker images are built using `docker buildx bake`
# But we use https://depot.dev in CI (super fast) by setting USE_DEPOT=1
ifeq ($(USE_DEPOT), 1) # if $USE_DEPOT=="1"
  $(info "⚠️  Building using depot.dev") # Print a message
  export BAKE_COMMAND = depot bake
else
  export BAKE_COMMAND = docker buildx bake
endif


# Build all Docker images *locally*
# Use this to test your changes
default: docker-images


# Build Docker images *locally*
docker-images: docker-images-php-83 docker-images-php-84 docker-images-php-85
docker-images-php-%:
	PHP_VERSION=$* ${BAKE_COMMAND} --load


# Build and publish multi-architecture images to Docker Hub.
upload-to-docker-hub: upload-to-docker-hub-php-83 upload-to-docker-hub-php-84 upload-to-docker-hub-php-85
upload-to-docker-hub-php-%:
    # Make sure we have defined the docker tag
	(test $(DOCKER_TAG)) && echo "Tagging images with \"${DOCKER_TAG}\"" || echo "You have to define environment variable DOCKER_TAG"
	test $(DOCKER_TAG)

	PHP_VERSION=$* DOCKER_PLATFORM=linux/amd64,linux/arm64 ${BAKE_COMMAND} --push \
		--set "build-php.tags=bref/build-php-$*:4" --set "build-php.tags=bref/build-php-$*:${DOCKER_TAG}" --set "build-php.tags=bref/build-php-$*:latest" \
		--set "php.tags=bref/php-$*:4" --set "php.tags=bref/php-$*:${DOCKER_TAG}" --set "php.tags=bref/php-$*:latest" \
		--set "php-dev.tags=bref/php-$*-dev:4" --set "php-dev.tags=bref/php-$*-dev:${DOCKER_TAG}" --set "php-dev.tags=bref/php-$*-dev:latest"


test: test-83 test-84 test-85
test-%:
	cd tests && $(MAKE) test-$*


clean: clean-83 clean-84 clean-85
	# Clear the build cache, else all images will be rebuilt using cached layers
	docker builder prune
clean-%:
	# Clean Docker images to force rebuilding them
	docker image rm --force bref/build-php-$* bref/php-$* bref/php-$*-dev
