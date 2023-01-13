<?php declare(strict_types=1);

/********************************************************
 *
 * Usage:
 *    php copy-dependencies.php <path-to-lib-check.php> <target-directory>
 *
 * For example:
 *    php copy-dependencies.php /opt/bin/php /opt/lib
 *
 ********************************************************/

if (! ($argv[1] ?? false)) {
    echo 'Missing the first argument, check the file to see how to use it' . PHP_EOL;
    exit(1);
}
if (! ($argv[2] ?? false)) {
    echo 'Missing the second argument, check the file to see how to use it' . PHP_EOL;
    exit(1);
}
$pathToCheck = $argv[1];
$targetDirectory = $argv[2];

// All the paths where shared libraries can be found
const LIB_PATHS = [
    // System
    '/lib64',
    '/usr/lib64',
    // Libraries we compiled from source go here by default
    '/tmp/bref/lib',
    '/tmp/bref/lib64',
];

$arch = 'x86';
if (php_uname('m') !== 'x86_64') {
    $arch = 'arm';
}

$librariesThatExistOnLambda = file(__DIR__ . "/libs-$arch.txt");
// For some reason some libraries are actually not in Lambda, despite being in the docker image 🤷
$librariesThatExistOnLambda = array_filter($librariesThatExistOnLambda, function ($library) {
    return ! str_contains($library, 'libgcrypt.so') && ! str_contains($library, 'libgpg-error.so');
});

$requiredLibraries = listAllDependenciesRecursively($pathToCheck);
// Exclude existing system libraries
$requiredLibraries = array_filter($requiredLibraries, fn(string $lib) => !in_array($lib, $librariesThatExistOnLambda, true));

// Copy all the libraries
foreach ($requiredLibraries as $libraryPath) {
    $targetPath = $targetDirectory . '/' . basename($libraryPath);
    echo "Copying $libraryPath to $targetPath" . PHP_EOL;
    copy($libraryPath, $targetPath);
}


function listDependencies(string $path): array
{
    static $cache = [];
    if (!isset($cache[$path])) {
        echo $path . PHP_EOL;
        $asString = shell_exec("objdump -p '$path' | grep NEEDED | awk '{ print $2 }'");
        if (!$asString) {
            $dependencies = [];
        } else {
            $dependencies = array_filter(explode(PHP_EOL, $asString));
        }
        $cache[$path] = array_map(fn(string $dependency) => findFullPath($dependency), $dependencies);
    }
    return $cache[$path];
}

function findFullPath(string $lib): string {
    static $cache = [];
    if (isset($cache[$lib])) {
        return $cache[$lib];
    }
    foreach (LIB_PATHS as $libPath) {
        if (file_exists("$libPath/$lib")) {
            $cache[$lib] = "$libPath/$lib";
            return "$libPath/$lib";
        }
    }
    throw new RuntimeException("Dependency '$lib' not found");
}

function listAllDependenciesRecursively(string $path): array
{
    $dependencies = listDependencies($path);
    $allDependencies = [];
    foreach ($dependencies as $dependency) {
        $allDependencies = array_merge($allDependencies, listAllDependenciesRecursively($dependency));
    }
    return array_unique(array_merge($dependencies, $allDependencies));
}
