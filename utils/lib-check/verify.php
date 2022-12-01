<?php declare(strict_types=1);

# This file is only used manually.
# The goal is to reduce layer size by not copying any file that is not strictly necessary.
# We do this by executing one Lambda with the following `/opt/bootstrap` file:

##########
/**
#!/bin/sh
ls /lib64 -la
*/
##########

# The result of the Lambda execution should then be copied into the al2-x64.txt file.
# We will then read the Dockerfile, remove all comments and compare any file that we
# may be copying into the layer that doesn't need to be there.

if (! ($argv[1] ?? false)) {
    echo 'Run via "make check"' . PHP_EOL;
    exit(1);
}

$docker = file_get_contents(__DIR__ . '/../../' . $argv[1]);

$dockerContent = explode(PHP_EOL, $docker);

$dockerContent = array_filter($dockerContent, fn ($item) => ! str_starts_with($item, '#') && ! empty($item));

$docker = implode(PHP_EOL, $dockerContent);

$libraries = file(__DIR__ . '/al2-x64.txt');
// For some reason some libraries are actually not in Lambda, despite being in the docker image 🤷
$libraries = array_filter($libraries, function ($library) {
    return ! str_contains($library, 'libgcrypt.so') && ! str_contains($library, 'libgpg-error.so');
});

foreach ($libraries as $library) {
    if (! str_contains($library, '.so')) {
        continue;
    }

    if (str_contains($docker, $library)) {
        echo "[$library] is present in Docker but is also present on /lib64 by default" . PHP_EOL;
    }
}

echo 'OK' . PHP_EOL;
