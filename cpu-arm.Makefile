# Load .env file if it exists
-include .env
export # export all variables defined in .env
export CPU = arm
export CPU_PREFIX = arm-
export ROOT_DIR = $(shell pwd)/


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
	# Build images for function layers
	docker-compose build --parallel php-80
	# Build images for FPM layers
	docker-compose build --parallel php-80-fpm


# Build Lambda layers (zip files) *locally*
layers: docker-images
	# Build the containers that will zip the layers
	docker-compose build --parallel php-80-zip
	docker-compose build --parallel php-80-zip-fpm

	# Run the zip containers: the layers will be copied to `./output/`
	docker-compose up php-80-zip \
		php-80-zip-fpm
	# Clean up containers
	docker-compose down


# Upload the layers to AWS Lambda
upload-layers: layers
	# Upload the Function layers to AWS
	LAYER_NAME=arm-php-80 $(MAKE) -C ./utils/lambda-publish/ publish-parallel

	# Upload the FPM Layers to AWS
	LAYER_NAME=arm-php-80-fpm $(MAKE) -C ./utils/lambda-publish/ publish-parallel


# Build and publish Docker images to Docker Hub.
# Only publishes the `latest` version.
# This process is executed when a merge to `main` happens.
# When a release tag is created, GitHub Actions
# will download the latest images, tag them with the version number
# and re-upload them with the right tag.
upload-to-docker-hub: docker-images
	# Temporarily creating aliases of the Docker images to push to the test account
	docker tag bref/arm-php-80 breftest/arm-php-80
	docker tag bref/arm-php-80-fpm breftest/arm-php-80-fpm

	# TODO: change breftest/ to bref/
	docker push breftest/arm-php-80
	docker push breftest/arm-php-80-fpm


test:
	cd tests && $(MAKE) test-80


clean:
	# Remove zip files
	rm -f output/arm-*.zip
	# Clean Docker images to force rebuilding them
	docker image rm --force bref/arm-fpm-internal-src
	docker image rm --force bref/arm-php-80
	docker image rm --force bref/arm-php-80-zip
	docker image rm --force bref/arm-php-81
	docker image rm --force bref/arm-php-81-zip
	docker image rm --force bref/arm-php-80-fpm
	docker image rm --force bref/arm-php-80-fpm-zip
	docker image rm --force bref/arm-php-81-fpm
	docker image rm --force bref/arm-php-81-fpm-zip
	# Clear the build cache, else all images will be rebuilt using cached layers
	docker builder prune
