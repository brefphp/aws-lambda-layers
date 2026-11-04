
test: test-83 test-84 test-85

# This rule matches with a wildcard, for example `test-84`.
# The `$*` variable will contained the matched part, in this case `84`.
test-%: vendor
	# Image layout: Lambda needs /etc/hosts and /var/task, layers would hide /opt
	docker run --platform=${DOCKER_PLATFORM} --rm --entrypoint=sh bref/php-$* -c \
		'test -f /etc/hosts && test -d /var/task && test -x /var/runtime/bootstrap && test -z "$$(ls -A /opt)" && test "$$(stat -c %a /tmp)" = 1777'
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/php-$* test_1_binary.php $*
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/php-$*-dev test_1_binary.php $*

	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/php-$* test_2_extensions.php
	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php bref/php-$*-dev test_2_extensions.php

	docker run --platform=${DOCKER_PLATFORM} --rm -v=$(PWD):/var/task:ro --entrypoint=php \
		   -e PHP_INI_SCAN_DIR="/etc/php/conf.d/:/var/task/" bref/php-$* \
 		   test_3_manual_enabling_extensions.php

	# Test function handler
	docker stop test-php-$* 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-php-$* \
		   -e BREF_RUNTIME=function \
		   bref/php-$* test_4_function_handler.php
	docker exec test-php-$* php test_4_function_invocation.php \
        || (docker logs test-php-$* && exit 1)
	docker stop test-php-$*

	# Test FPM handler
	docker stop test-php-$* 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-php-$* \
		   -e BREF_RUNTIME=fpm \
		   bref/php-$* test_5_fpm_handler.php
	docker exec test-php-$* php test_5_fpm_invocation.php \
		|| (docker logs test-php-$* && exit 1) # print logs in case of failure
	docker stop test-php-$*

	# Test console handler
	docker stop test-php-$* 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-php-$* \
		   -e BREF_RUNTIME=console \
		   bref/php-$* test_6_console_handler.php
	docker exec test-php-$* php test_6_console_invocation.php \
		|| (docker logs test-php-$* && exit 1) # print logs in case of failure
	docker stop test-php-$*

	# Test that we can override PHP_INI_SCAN_DIR
	docker stop test-php-$*-test7 2> /dev/null || true # silence errors
	docker run --platform=${DOCKER_PLATFORM} --rm --detach -v=$(PWD):/var/task:ro --name test-php-$*-test7 \
		   -e BREF_RUNTIME=function \
		   -e PHP_INI_SCAN_DIR="/etc/php/conf.d/:/var/task/" \
		   bref/php-$* test_4_function_handler.php
	docker exec test-php-$*-test7 php test_7_custom_ini_scan_dir.php \
		|| (docker logs test-php-$*-test7 && exit 1) # print logs in case of failure
	docker stop test-php-$*-test7

	echo "\033[1;32m✓ Tests succeeded\033[0m"

vendor:
	docker run --rm -v=$(PWD):/app composer install

clean:
	rm -rf vendor composer.lock
