# Load .env file if it exists
-include .env
export # export all variables defined in .env

# Define all the environment variables depending on the CPU
# Set CPU= (empty) to build for x86
# Set CPU=arm to build for ARM
ifeq ($(CPU), arm) # if $CPU=="arm"
  $(info "⚠️  Building for ARM") # Print a message
  export CPU = arm
  export CPU_PREFIX = arm-
  export IMAGE_VERSION_SUFFIX = arm64
  export DOCKER_PLATFORM = linux/arm64
else
  $(info "⚠️  Building for x86") # Print a message
  export CPU = x86
  export CPU_PREFIX =
  export IMAGE_VERSION_SUFFIX = x86_64
  export DOCKER_PLATFORM = linux/amd64
endif

# By default, Docker images are built using `docker buildx bake`
# But we use https://depot.dev in CI (super fast) by setting USE_DEPOT=1
ifeq ($(USE_DEPOT), 1) # if $USE_DEPOT=="1"
  $(info "⚠️  Building using depot.dev") # Print a message
  export BAKE_COMMAND = depot bake
else
  export BAKE_COMMAND = docker buildx bake
endif


# Build all Docker images and layers *locally*
# Use this to test your changes
default: docker-images layers


# Build Docker images *locally*
docker-images: docker-images-php-82 docker-images-php-83 docker-images-php-84
docker-images-php-%:
	PHP_VERSION=$* ${BAKE_COMMAND} --load


# Build Lambda layers (zip files) *locally*
layers: layer-php-82 layer-php-83 layer-php-84
# This rule matches with a wildcard, for example `layer-php-84`.
# The `$*` variable will contained the matched part, in this case `php-84`.
layer-%:
	./utils/docker-zip-dir.sh bref/${CPU_PREFIX}$* ${CPU_PREFIX}$*


# Upload the layers to AWS Lambda
# Uses the current AWS_PROFILE. Most users will not want to use this option
# as this will publish all layers to all regions + publish all Docker images.
upload-layers: upload-layers-php-82 upload-layers-php-83 upload-layers-php-84
upload-layers-php-%:
	LAYER_NAME=${CPU_PREFIX}php-$* $(MAKE) -C ./utils/lambda-publish publish-parallel


# Publish Docker images to Docker Hub.
upload-to-docker-hub: upload-to-docker-hub-php-82 upload-to-docker-hub-php-83 upload-to-docker-hub-php-84
upload-to-docker-hub-php-%:
    # Make sure we have defined the docker tag
	(test $(DOCKER_TAG)) && echo "Tagging images with \"${DOCKER_TAG}\"" || echo "You have to define environment variable DOCKER_TAG"
	test $(DOCKER_TAG)

	set -e ; \
	for image in \
	  "bref/${CPU_PREFIX}php-$*" "bref/${CPU_PREFIX}build-php-$*" "bref/${CPU_PREFIX}php-$*-dev"; \
	do \
		docker tag $$image $$image:2 ; \
		docker tag $$image $$image:${DOCKER_TAG} ; \
		docker push $$image --all-tags ; \
	done


test: test-82 test-83 test-84
test-%:
	cd tests && $(MAKE) test-$*


clean: clean-82 clean-83 clean-84
	# Clear the build cache, else all images will be rebuilt using cached layers
	docker builder prune
	# Remove zip files
	rm -f output/${CPU_PREFIX}*.zip
clean-%:
	# Clean Docker images to force rebuilding them
	docker image rm --force bref/${CPU_PREFIX}build-php-$* \
		bref/${CPU_PREFIX}php-$* \
		bref/${CPU_PREFIX}php-$*-zip \
		bref/${CPU_PREFIX}php-$*-dev
