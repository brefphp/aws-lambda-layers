<?php declare(strict_types=1);

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
