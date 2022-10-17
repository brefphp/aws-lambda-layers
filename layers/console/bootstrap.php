<?php declare(strict_types=1);

use Bref\ConsoleRuntime\Main;

if (getenv('BREF_AUTOLOAD_PATH')) {
    require getenv('BREF_AUTOLOAD_PATH');
} else {
    $appRoot = getenv('LAMBDA_TASK_ROOT');

    require $appRoot . '/vendor/autoload.php';
}

if (! class_exists(Main::class)) {
    throw new RuntimeException('Bref is not installed in your application (could not find the class "Bref\FunctionRuntime\Main" in Composer dependencies). Did you run "composer require bref/bref"?');
}

Main::run();
