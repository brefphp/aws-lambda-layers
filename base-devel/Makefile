build:
	docker-compose build --parallel

upload-to-docker-hub: build
	docker tag bref/base-devel-arm bref/base-devel-arm
	docker tag bref/base-devel-x86 bref/base-devel-x86
	docker push bref/base-devel-arm
	docker push bref/base-devel-x86
