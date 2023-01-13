build: build-x86 build-arm

build-x86:
	docker compose build x86
build-arm:
	docker compose build arm

upload-to-docker-hub: build
	docker tag bref/base-devel-arm bref/base-devel-arm
	docker tag bref/base-devel-x86 bref/base-devel-x86
	docker push bref/base-devel-arm
	docker push bref/base-devel-x86
