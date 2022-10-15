run: vendor
	docker-compose up

test-function:
	curl -X POST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{"name": "World"}'

test-fpm:
	curl -X POST "http://localhost:9001/2015-03-31/functions/function/invocations" --data-binary "@api-gateway.json"

vendor:
	composer install
