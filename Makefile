# Load .env file if it exists
-include .env
export # export all variables defined in .env

# - Build all layers
# - Publish all Docker images to Docker Hub
# - Publish all layers to AWS Lambda
# Uses the current AWS_PROFILE. Most users will not want to use this option
# as this will publish all layers to all regions + publish all Docker images.
everything:
	$(MAKE) -f cpu-x86.Makefile everything
	$(MAKE) -f cpu-arm.Makefile everything

# Build Docker images *locally*
docker-images:
	$(MAKE) -f cpu-x86.Makefile docker-images
	$(MAKE) -f cpu-arm.Makefile docker-images

# Build Lambda layers (zip files) *locally*
layers:
	$(MAKE) -f cpu-x86.Makefile layers
	$(MAKE) -f cpu-arm.Makefile layers

# Upload the layers to AWS Lambda
upload-layers:
	$(MAKE) -f cpu-x86.Makefile upload-layers
	$(MAKE) -f cpu-arm.Makefile upload-layers

# Build and publish Docker images to Docker Hub.
# Only publishes the `latest` version.
# This process is executed when a merge to `main` happens.
# When a release tag is created, GitHub Actions
# will download the latest images, tag them with the version number
# and re-upload them with the right tag.
upload-to-docker-hub:
	$(MAKE) -f cpu-x86.Makefile upload-to-docker-hub
	$(MAKE) -f cpu-arm.Makefile upload-to-docker-hub

test:
	$(MAKE) -f cpu-x86.Makefile test
	$(MAKE) -f cpu-arm.Makefile test

clean:
	$(MAKE) -f cpu-x86.Makefile clean
	$(MAKE) -f cpu-arm.Makefile clean

.PHONY: layers
