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
docker-images: docker-images-php-80 docker-images-php-81 docker-images-php-82
docker-images-php-%:
	PHP_VERSION=$* ${BAKE_COMMAND} --load


# Build Lambda layers (zip files) *locally*
layers: layer-php-80 layer-php-81 layer-php-82 layer-php-80-fpm layer-php-81-fpm layer-php-82-fpm
	# Build the console layer only once (x86 and single PHP version)
	@if [ ${CPU} = "x86" ]; then \
		./utils/docker-zip-dir.sh bref/console-zip console; \
	fi
# This rule matches with a wildcard, for example `layer-php-80`.
# The `$*` variable will contained the matched part, in this case `php-80`.
layer-%:
	./utils/docker-zip-dir.sh bref/${CPU_PREFIX}$* ${CPU_PREFIX}$*


# Upload the layers to AWS Lambda
# Uses the current AWS_PROFILE. Most users will not want to use this option
# as this will publish all layers to all regions + publish all Docker images.
upload-layers: upload-layers-php-80 upload-layers-php-81 upload-layers-php-82
	# Upload the console layer only once (x86 and single PHP version)
	@if [ ${CPU} = "x86" ]; then \
		LAYER_NAME=console $(MAKE) -C ./utils/lambda-publish publish-parallel; \
	fi
upload-layers-php-%:
	# Upload the function layers to AWS
	LAYER_NAME=${CPU_PREFIX}php-$* $(MAKE) -C ./utils/lambda-publish publish-parallel
	# Upload the FPM layers to AWS
	LAYER_NAME=${CPU_PREFIX}php-$*-fpm $(MAKE) -C ./utils/lambda-publish publish-parallel


# Publish Docker images to Docker Hub.
upload-to-docker-hub: upload-to-docker-hub-php-80 upload-to-docker-hub-php-81 upload-to-docker-hub-php-82
upload-to-docker-hub-php-%:
	# While in beta we tag and push the `:2` version, later we'll push `:latest` as well
	for image in \
	  "bref/${CPU_PREFIX}php-$*" "bref/${CPU_PREFIX}php-$*-fpm" "bref/${CPU_PREFIX}php-$*-console" \
	  "bref/${CPU_PREFIX}build-php-$*" "bref/${CPU_PREFIX}php-$*-fpm-dev"; \
	do \
		docker tag $$image $$image:2 ; \
		docker push $$image:2 ; \
	done
	# TODO: when v2 becomes "latest", we should also push "latest" tags
	# We could actually use `docker push --all-tags` at the end probably?


test: test-80 test-81 test-82
test-%:
	cd tests && $(MAKE) test-$*


clean: clean-80 clean-81 clean-82
	# Clear the build cache, else all images will be rebuilt using cached layers
	docker builder prune
	# Remove zip files
	rm -f output/${CPU_PREFIX}*.zip
clean-%:
	# Clean Docker images to force rebuilding them
	docker image rm --force bref/${CPU_PREFIX}build-php-$* \
		bref/${CPU_PREFIX}php-$* \
		bref/${CPU_PREFIX}php-$*-zip \
		bref/${CPU_PREFIX}php-$*-fpm \
		bref/${CPU_PREFIX}php-$*-fpm-zip \
		bref/${CPU_PREFIX}php-$*-fpm-dev \
		bref/${CPU_PREFIX}php-$*-console
