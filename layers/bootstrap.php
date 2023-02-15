<?php declare(strict_types=1);

if (getenv('BREF_AUTOLOAD_PATH')) {
    require getenv('BREF_AUTOLOAD_PATH');
} else {
    $appRoot = getenv('LAMBDA_TASK_ROOT');

    require $appRoot . '/vendor/autoload.php';
}

$runtimeClass = getenv('RUNTIME_CLASS');

if (! class_exists($runtimeClass)) {
    throw new RuntimeException("Bref is not installed in your application (could not find the class \"$runtimeClass\" in Composer dependencies). Did you run \"composer require bref/bref\"?");
}

$runtimeClass::run();
