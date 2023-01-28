# Load .env file if it exists
-include .env
export # export all variables defined in .env
export CPU = x86
export CPU_PREFIX =
export IMAGE_VERSION_SUFFIX = x86_64
export DOCKER_PLATFORM = linux/amd64


# Build all Docker images and layers *locally*
# Use this to test your changes
default: docker-images layers


# Build Docker images *locally*
docker-images: docker-images-php-80 docker-images-php-81 docker-images-php-82
docker-images-php-%:
	PHP_VERSION=$* depot bake --build-platform=${DOCKER_PLATFORM} --load


# Build Lambda layers (zip files) *locally*
layers: layer-php-80 layer-php-81 layer-php-82 layer-php-80-fpm layer-php-81-fpm layer-php-82-fpm
	# Handle this layer specifically
	./utils/docker-zip-dir.sh bref/php-80-console-zip console
# This rule matches with a wildcard, for example `layer-php-80`.
# The `$*` variable will contained the matched part, in this case `php-80`.
layer-%:
	./utils/docker-zip-dir.sh bref/$* $*


# Upload the layers to AWS Lambda
# Uses the current AWS_PROFILE. Most users will not want to use this option
# as this will publish all layers to all regions + publish all Docker images.
upload-layers:
	# Upload the function layers to AWS
	LAYER_NAME=php-80 $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-81 $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-82 $(MAKE) -C ./utils/lambda-publish publish-parallel

	# Upload the FPM layers to AWS
	LAYER_NAME=php-80-fpm $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-81-fpm $(MAKE) -C ./utils/lambda-publish publish-parallel
	LAYER_NAME=php-82-fpm $(MAKE) -C ./utils/lambda-publish publish-parallel

	# Upload the console layer to AWS
	LAYER_NAME=console $(MAKE) -C ./utils/lambda-publish publish-parallel


# Publish Docker images to Docker Hub.
upload-to-docker-hub:
	# While in beta we tag and push the `:2` version, later we'll push `:latest` as well
	for image in \
	  "bref/php-80" "bref/php-80-fpm" "bref/php-80-console" "bref/build-php-80" "bref/php-80-fpm-dev" \
	  "bref/php-81" "bref/php-81-fpm" "bref/php-81-console" "bref/build-php-81" "bref/php-81-fpm-dev" \
	  "bref/php-82" "bref/php-82-fpm" "bref/php-82-console" "bref/build-php-82" "bref/php-82-fpm-dev"; \
	do \
		docker tag $$image $$image:2 ; \
		docker push $$image:2 ; \
	done
	# TODO: when v2 becomes "latest", we should also push "latest" tags
	# We could actually use `docker push --all-tags` at the end probably?


test: test-80 test-81 test-82
test-%:
	cd tests && $(MAKE) test-$*


clean:
	# Remove zip files
	rm -f output/*.zip
	# Clean Docker images to force rebuilding them
	docker image rm --force bref/build-php-80
	docker image rm --force bref/build-php-81
	docker image rm --force bref/build-php-82
	docker image rm --force bref/php-80
	docker image rm --force bref/php-81
	docker image rm --force bref/php-82
	docker image rm --force bref/php-80-zip
	docker image rm --force bref/php-81-zip
	docker image rm --force bref/php-82-zip
	docker image rm --force bref/php-80-fpm
	docker image rm --force bref/php-81-fpm
	docker image rm --force bref/php-82-fpm
	docker image rm --force bref/php-80-fpm-zip
	docker image rm --force bref/php-81-fpm-zip
	docker image rm --force bref/php-82-fpm-zip
	docker image rm --force bref/php-80-fpm-dev
	docker image rm --force bref/php-81-fpm-dev
	docker image rm --force bref/php-82-fpm-dev
	docker image rm --force bref/php-80-console
	docker image rm --force bref/php-81-console
	docker image rm --force bref/php-82-console
	# Clear the build cache, else all images will be rebuilt using cached layers
	docker builder prune
