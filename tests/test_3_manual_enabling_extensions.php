<?php declare(strict_types=1);

require_once __DIR__ . '/utils.php';

$extensions = [
    'intl' => class_exists(\Collator::class),
    'apcu' => function_exists('apcu_add'),
    'pdo_pgsql' => extension_loaded('pdo_pgsql'),
];

$extensionDir = ini_get('extension_dir');
if ($extensionDir !== '/opt/bref/extensions') {
    error("extension_dir points to $extensionDir instead of /opt/bref/extensions");
}
success("[Extension] extension_dir points to /opt/bref/extensions");

foreach ($extensions as $extension => $test) {
    if (! $test) {
        if ($extension === 'apcu' && str_contains(php_uname('m'), 'aarch64')) {
            echo "⨯ [Extension] APCu is skipped for ARM because it is not supported yet\n";
            continue;
        }

        error($extension . ' extension was not loaded');
    }
    success("[Extension] $extension");
}
