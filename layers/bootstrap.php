<?php declare(strict_types=1);

// Force errors to be logged to stdout so that they end up in CloudWatch.
// In the `function` runtime this is already `1`, but in the `fpm` runtime it is `0` by default.
// Here we are forcing it to `1` in the bootstrap process, it will not impact the application code
// as it runs in different processes (FPM worker) and those will have `display_errors=0`.
ini_set('display_errors', '1');

$appRoot = getenv('LAMBDA_TASK_ROOT');

$autoloadPath = $_SERVER['BREF_AUTOLOAD_PATH'] ?? null;
if (! $autoloadPath) {
    $autoloadPath = $appRoot . '/vendor/autoload.php';
}
if (! file_exists($autoloadPath)) {
    throw new RuntimeException('Could not find the Composer vendor directory. Did you run "composer require bref/bref"? Read https://bref.sh/docs/environment/php#custom-vendor-path if your Composer vendor directory is in a custom path.');
}

require $autoloadPath;

$runtimeClass = getenv('RUNTIME_CLASS');

if (! class_exists($runtimeClass)) {
    throw new RuntimeException("Bref is not installed in your application (could not find the class \"$runtimeClass\" in Composer dependencies). Did you run \"composer require bref/bref\"?");
}

$runtimeClass::run();
