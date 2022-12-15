# Load .env file if it exists
-include .env
export # export all variables defined in .env
export CPU = arm
export CPU_PREFIX = arm-


# - Build all layers
# - Publish all Docker images to Docker Hub
# - Publish all layers to AWS Lambda
# Uses the current AWS_PROFILE. Most users will not want to use this option
# as this will publish all layers to all regions + publish all Docker images.
everything: clean upload-layers upload-to-docker-hub


# Build Docker images *locally*
docker-images:
	# Prepare the content of `/opt` that will be copied in each layer
	docker-compose -f ./layers/docker-compose.yml build --parallel
	# Build images for "build environment"
	docker-compose build --parallel build-php-80 build-php-81
	# Build images for function layers
	docker-compose build --parallel php-80 php-81
	# Build images for FPM layers
	docker-compose build --parallel php-80-fpm php-81-fpm
	# Build images for console layers
	docker-compose build --parallel php-80-console php-81-console
	# Build dev images
	docker-compose build --parallel php-80-fpm-dev php-81-fpm-dev


# Build Lambda layers (zip files) *locally*
layers: docker-images
	# Build the containers that will zip the layers
	docker-compose build --parallel php-80-zip php-81-zip \
									php-80-zip-fpm php-81-zip-fpm

	# Run the zip containers: the layers will be copied to `./output/`
	docker-compose up php-80-zip php-81-zip \
		php-80-zip-fpm php-81-zip-fpm
	# Clean up containers
	docker-compose down


# Upload the layers to AWS Lambda
upload-layers: layers
	# Upload the function layers to AWS
	LAYER_NAME=arm-php-80 $(MAKE) -C ./utils/lambda-publish/ publish-parallel
	LAYER_NAME=arm-php-81 $(MAKE) -C ./utils/lambda-publish/ publish-parallel

	# Upload the FPM layers to AWS
	LAYER_NAME=arm-php-80-fpm $(MAKE) -C ./utils/lambda-publish/ publish-parallel
	LAYER_NAME=arm-php-81-fpm $(MAKE) -C ./utils/lambda-publish/ publish-parallel


# Build and publish Docker images to Docker Hub.
upload-to-docker-hub: docker-images
	for image in \
	  "bref/arm-php-80" "bref/arm-php-80-fpm" "bref/arm-php-80-console" "bref/arm-build-php-80" "bref/arm-php-80-fpm-dev" \
	  "bref/arm-php-81" "bref/arm-php-81-fpm" "bref/arm-php-81-console" "bref/arm-build-php-81" "bref/arm-php-81-fpm-dev"; \
	do \
		docker tag $$image $$image:2 ; \
		docker push $$image:2 ; \
	done
	# TODO: when v2 becomes "latest", we should also push "latest" tags
	# We could actually use `docker push --all-tags` at the end probably?


test:
	cd tests && $(MAKE) test-80
	cd tests && $(MAKE) test-81


clean:
	# Remove zip files
	rm -f output/arm-*.zip
	# Clean Docker images to force rebuilding them
	docker image rm --force bref/arm-fpm-internal-src
	docker image rm --force bref/arm-build-php-80
	docker image rm --force bref/arm-php-80
	docker image rm --force bref/arm-php-80-zip
	docker image rm --force bref/arm-php-80-fpm
	docker image rm --force bref/arm-php-80-fpm-zip
	docker image rm --force bref/arm-php-80-fpm-dev
	docker image rm --force bref/arm-php-80-console
	docker image rm --force bref/arm-build-php-81
	docker image rm --force bref/arm-php-81
	docker image rm --force bref/arm-php-81-zip
	docker image rm --force bref/arm-php-81-fpm
	docker image rm --force bref/arm-php-81-fpm-zip
	docker image rm --force bref/arm-php-81-fpm-dev
	docker image rm --force bref/arm-php-81-console
	# Clear the build cache, else all images will be rebuilt using cached layers
	docker builder prune
