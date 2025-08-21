<?php declare(strict_types=1);

require_once __DIR__ . '/utils.php';

$extensions = [
    'intl' => class_exists(\Collator::class),
    'apcu' => function_exists('apcu_add'),
    'soap' => class_exists(\SoapClient::class),
];

$extensionDir = ini_get('extension_dir');
if ($extensionDir !== '/opt/bref/extensions') {
    error("extension_dir points to $extensionDir instead of /opt/bref/extensions");
}
success("[Extension] extension_dir points to /opt/bref/extensions");

foreach ($extensions as $extension => $test) {
    if (! $test) {
        error($extension . ' extension was not loaded');
    }
    success("[Extension] $extension");
}
