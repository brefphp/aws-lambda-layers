export CPU ?= x86
export ROOT_DIR = ../

ssh_extensions:
	docker-compose run --rm --entrypoint /bin/bash extensions

ssh_isolation:
	docker-compose run -e PHP_INI_SCAN_DIR="/opt/bref/etc/php/conf.d/:/opt/tests/" --rm --entrypoint /bin/bash isolation
