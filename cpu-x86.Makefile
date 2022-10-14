export CPU ?= x86
export CPU_PREFIX ?=
export ROOT_DIR ?= $(shell pwd)/


# - Build all layers
# - Publish all Docker images to Docker Hub
# - Publish all layers to AWS Lambda
# Uses the current AWS_PROFILE. Most users will not want to use this option
# as this will publish all layers to all regions + publish all Docker images.
everything: clean upload-layers upload-to-docker-hub


# Build Docker images *locally*
docker-images:
	# Prepare the content of `/opt` that will be copied in each layer
	docker-compose -f ./common/docker-compose.yml build --parallel
	# Build images for function layers
	docker-compose build --parallel php-80 php-81
	# Build images for FPM layers
	docker-compose build --parallel php-80-fpm php-81-fpm


# Build Lambda layers (zip files) *locally*
layers: docker-images
	# Build the containers that will zip the layers
	docker-compose build --parallel php-80-zip php-81-zip
	docker-compose build --parallel php-80-zip-fpm php-81-zip-fpm

	# Run the zip containers: the layers will be copied to `./layers/`
	docker-compose up php-80-zip php-81-zip \
		php-80-zip-fpm php-81-zip-fpm
	# Clean up containers
	docker-compose down


# Upload the layers to AWS Lambda
upload-layers: layers
	# Upload the Function layers to AWS
	LAYER_NAME=php-80 $(MAKE) -C ./lambda-publish/ publish-parallel
	LAYER_NAME=php-81 $(MAKE) -C ./lambda-publish/ publish-parallel

	# Upload the FPM Layers to AWS
	LAYER_NAME=php-80-fpm $(MAKE) -C ./lambda-publish/ publish-parallel
	LAYER_NAME=php-81-fpm $(MAKE) -C ./lambda-publish/ publish-parallel


# Build and publish Docker images to Docker Hub.
# Only publishes the `latest` version.
# This process is executed when a merge to `main` happens.
# When a release tag is created, GitHub Actions
# will download the latest images, tag them with the version number
# and re-upload them with the right tag.
upload-to-docker-hub: docker-images
	# Temporarily creating aliases of the Docker images to push to the test account
	docker tag bref/php-80 breftest/php-80
	docker tag bref/php-81 breftest/php-81
	docker tag bref/php-80-fpm breftest/php-80-fpm
	docker tag bref/php-81-fpm breftest/php-81-fpm

	# TODO: change breftest/ to bref/
	docker push breftest/php-80
	docker push breftest/php-81
	docker push breftest/php-80-fpm
	docker push breftest/php-81-fpm


clean:
	rm layers/*.zip
