check:
	@php verify.php php-80/cpu-x86.Dockerfile x86
	@php verify.php php-81/cpu-x86.Dockerfile x86
	@php verify.php php-82/cpu-x86.Dockerfile x86
	@php verify.php php-80/cpu-arm.Dockerfile arm
	@php verify.php php-81/cpu-arm.Dockerfile arm

update:
	docker compose run --rm update-x86
	docker compose run --rm update-arm
