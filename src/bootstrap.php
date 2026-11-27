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

$runtime = $_SERVER['BREF_RUNTIME'] ?? null;

if (empty($runtime)) {
    throw new RuntimeException('The environment variable `BREF_RUNTIME` is not set. Use the `php-XX`, `php-XX-fpm` or `php-XX-console` runtimes in serverless.yml, or set `BREF_RUNTIME` to `function`, `fpm` or `console`.');
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

// Older versions of bref/bref do not work with these runtimes (this class was added in Bref 4)
if (class_exists('Bref\Bref') && ! class_exists('Bref\Event\Http\HttpResponseWriter')) {
    throw new RuntimeException('This runtime requires Bref 4, but an older version of the bref/bref package is installed. Upgrade it with "composer require bref/bref:^4", and read https://bref.sh/docs/upgrading/v4');
}

$runtimeClass::run();
