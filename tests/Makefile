export CPU_PREFIX ?=

test: test-80 test-81 test-82 test-83

# This rule matches with a wildcard, for example `test-80`.
# The `$*` variable will contained the matched part, in this case `80`.
test-%: vendor
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/${CPU_PREFIX}php-$* test_1_binary.php $*
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/${CPU_PREFIX}php-$*-fpm test_1_binary.php $*
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/${CPU_PREFIX}php-$*-fpm-dev test_1_binary.php $*

	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/${CPU_PREFIX}php-$* test_2_extensions.php
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/${CPU_PREFIX}php-$*-fpm test_2_extensions.php
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/${CPU_PREFIX}php-$*-fpm-dev test_2_extensions.php

	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php \
		   -e PHP_INI_SCAN_DIR="/opt/bref/etc/php/conf.d/:/var/task/" bref/${CPU_PREFIX}php-$* \
 		   test_3_manual_enabling_extensions.php

	# Test function handler
	docker stop test-${CPU_PREFIX}php-$* 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-${CPU_PREFIX}php-$* \
		   bref/${CPU_PREFIX}php-$* test_4_function_handler.php
	docker exec test-${CPU_PREFIX}php-$* php test_4_function_invocation.php \
        || (docker logs test-${CPU_PREFIX}php-$* && exit 1)
	docker stop test-${CPU_PREFIX}php-$*

	# Test FPM handler
	docker stop test-${CPU_PREFIX}php-$*-fpm 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-${CPU_PREFIX}php-$*-fpm \
		   bref/${CPU_PREFIX}php-$*-fpm test_5_fpm_handler.php
	docker exec test-${CPU_PREFIX}php-$*-fpm php test_5_fpm_invocation.php \
		|| (docker logs test-${CPU_PREFIX}php-$*-fpm && exit 1) # print logs in case of failure
	docker stop test-${CPU_PREFIX}php-$*-fpm

	# Test console handler
	docker stop test-${CPU_PREFIX}php-$*-console 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-${CPU_PREFIX}php-$*-console \
		   bref/${CPU_PREFIX}php-$*-console test_6_console_handler.php
	docker exec test-${CPU_PREFIX}php-$*-console php test_6_console_invocation.php \
		|| (docker logs test-${CPU_PREFIX}php-$*-console && exit 1) # print logs in case of failure
	docker stop test-${CPU_PREFIX}php-$*-console

	# Test that we can override PHP_INI_SCAN_DIR
	docker stop test-${CPU_PREFIX}php-$*-test7 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-${CPU_PREFIX}php-$*-test7 \
		   -e PHP_INI_SCAN_DIR="/opt/bref/etc/php/conf.d/:/var/task/" \
		   bref/${CPU_PREFIX}php-$* test_4_function_handler.php
	docker exec test-${CPU_PREFIX}php-$*-test7 php test_7_custom_ini_scan_dir.php \
		|| (docker logs test-${CPU_PREFIX}php-$*-test7 && exit 1) # print logs in case of failure
	docker stop test-${CPU_PREFIX}php-$*-test7

	echo "\033[1;32m✓ Tests succeeded\033[0m"

vendor:
	docker run --rm -v=$(PWD):/app composer install

clean:
	rm -rf vendor composer.lock
