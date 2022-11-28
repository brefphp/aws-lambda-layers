export CPU_PREFIX ?=

.SILENT: test test-80 test-81 test-82 vendor

test: test-80 test-81 test-82

# This rule matches with a wildcard, for example `test-80`.
# The `$*` variable will contained the matched part, in this case `80`.
test-%: vendor
	# Clean up containers from previous failed runs
	docker-compose down
	docker-compose run --rm -- php-$* test_1_binary.php $*
	docker-compose run --rm -- php-$* test_2_extensions.php
	docker-compose run --rm -e PHP_INI_SCAN_DIR="/opt/bref/etc/php/conf.d/:/var/task/" \
		-- php-$* test_3_manual_enabling_extensions.php
	# Test function handler
	docker-compose up --detach php-$*-handler
	docker-compose exec -T php-$*-handler php test_4_function_invocation.php \
		|| (docker-compose logs php-$*-handler && exit 1) # print logs in case of failure
	# Test FPM handler
	docker-compose up --detach php-$*-fpm-handler
	docker-compose exec -T php-$*-fpm-handler php test_5_fpm_invocation.php \
		|| (docker-compose logs php-$*-fpm-handler && exit 1) # print logs in case of failure
	# Test console handler
	docker-compose up --detach php-$*-console-handler
	docker-compose exec -T php-$*-console-handler php test_6_console_invocation.php \
		|| (docker-compose logs php-$*-console-handler && exit 1) # print logs in case of failure
	# Clean up containers
	docker-compose down
	echo "\033[1;32m✓ Tests succeeded\033[0m"

start-containers: vendor
	docker-compose up php-80-handler php-80-fpm-handler

test-function:
	curl -X POST "http://localhost:9001/2015-03-31/functions/function/invocations" -d '{"name": "World"}'

test-fpm:
	curl -X POST "http://localhost:9002/2015-03-31/functions/function/invocations" --data-binary "@test_5_event.json"

vendor:
	docker-compose run --rm composer install

clean:
	docker-compose down
	rm -rf vendor composer.lock
