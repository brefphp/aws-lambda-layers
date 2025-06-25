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

// `RUNTIME_CLASS` is for backwards compatibility with Bref v2's environment variable
$runtime = $_SERVER['BREF_RUNTIME'] ?? $_SERVER['RUNTIME_CLASS'] ?? null;

if (empty($runtime)) {
    throw new RuntimeException('The environment variable `BREF_RUNTIME` is not set, are you trying to use Bref v2 with Bref v3 layers? Make sure to follow the Bref documentation to use the right layers for your current Bref version.');
}

$runtimeClass = match ($runtime) {
    'function' => 'Bref\FunctionRuntime\Main',
    'fpm' => 'Bref\FpmRuntime\Main',
    'console' => 'Bref\ConsoleRuntime\Main',
    default => $runtime,
};

if (! class_exists($runtimeClass)) {
    throw new RuntimeException("Bref is not installed in your application (could not find the class \"$runtimeClass\" in Composer dependencies). Did you run \"composer require bref/bref\"?");
}

$runtimeClass::run();
