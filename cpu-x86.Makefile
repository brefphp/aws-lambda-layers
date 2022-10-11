export CPU ?= x86
export CPU_PREFIX ?=
export ROOT_DIR ?= $(shell pwd)/


# This command is designed for bref internal use only and will publish every image
# using the configured AWS_PROFILE. Most users will not want to use this option
# as this will distribute all layers to all regions.
everything: clean upload-layers docker-hub


docker-images:
	# Build (in parallel) the internal packages that will be copied into the layers
	docker-compose -f ./common/docker-compose.yml build --parallel

	# We build the layer first because we want the Docker Image to be properly tagged so that
	# later on we can push to Docker Hub.
	docker-compose build --parallel php-80 php-81

	# After we build the layer successfully we can then zip it up so that it's ready to be uploaded to AWS.
	docker-compose build --parallel php-80-zip php-81-zip

	# Repeat the same process for FPM
	docker-compose build --parallel php-80-fpm php-81-fpm
	docker-compose build --parallel php-80-zip-fpm php-81-zip-fpm


layers: docker-images
	# By running the zip containers, the layers will be copied to `./layers/`
	docker-compose up php-80-zip php-81-zip \
		php-80-zip-fpm php-81-zip-fpm

	# This will clean up orphan containers
	docker-compose down


upload-layers: layers
	# Upload the Function layers to AWS
	LAYER_NAME=php-80 $(MAKE) -C ./common/publish/ publish-by-type
	LAYER_NAME=php-81 $(MAKE) -C ./common/publish/ publish-by-type

	# Upload the FPM Layers to AWS
	LAYER_NAME=php-80-fpm $(MAKE) -C ./common/publish/ publish-by-type
	LAYER_NAME=php-81-fpm $(MAKE) -C ./common/publish/ publish-by-type


layers.json:
	# Transform /tmp/bref-zip/output.ini into layers.json
	docker-compose -f common/utils/docker-compose.yml run parse
	cp /tmp/bref-zip/layers.${CPU}.json ./../


# Here we're only tagging the latest images. This process is executed when a merge to
# master happens. We're using the same images that we built for the layers and
# publishing them on Docker Hub. When a Release Tag is created, GitHub Actions
# will be used to download the latest images, tag them with the version number
# and reupload them with the right tag.
docker-hub:
	# Temporarily creating aliases of the Docker images to push to the test account
	docker tag bref/php-80 breftest/php-80
	docker tag bref/php-81 breftest/php-81
	docker tag bref/php-80-fpm breftest/php-80-fpm
	docker tag bref/php-81-fpm breftest/php-81-fpm

	$(MAKE) -f cpu-$(CPU).Makefile -j2 docker-hub-push-all


clean:
	rm layers/*.zip


docker-hub-push-all: docker-hub-push-function docker-hub-push-fpm

docker-hub-push-function:
	#TODO: change breftest/ to bref/
	docker push breftest/php-80
	docker push breftest/php-81

docker-hub-push-fpm:
	#TODO: change breftest/ to bref/
	docker push breftest/php-80-fpm
	docker push breftest/php-81-fpm
