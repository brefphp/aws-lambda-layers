<?php declare(strict_types=1);

require_once __DIR__ . '/utils.php';

$extensions = [
    'gd' => function_exists('gd_info'),
    'gmp' => function_exists('gmp_add'),
    'intl' => class_exists(\Collator::class),
    'apcu' => function_exists('apcu_add'),
    'soap' => class_exists(\SoapClient::class),
    // TODO redis is not available on PHP 8.5 yet
    'redis' => PHP_VERSION_ID >= 80500 ? true : class_exists(\Redis::class),
];

$extensionDir = ini_get('extension_dir');
if ($extensionDir !== '/usr/local/lib/php/extensions') {
    error("extension_dir points to $extensionDir instead of /usr/local/lib/php/extensions");
}
success("[Extension] extension_dir points to /usr/local/lib/php/extensions");

foreach ($extensions as $extension => $test) {
    if (! $test) {
        error($extension . ' extension was not loaded');
    }
    success("[Extension] $extension");
}

// gd must support the common image formats and fonts
$gdInfo = gd_info();
foreach (['JPEG Support', 'PNG Support', 'WebP Support', 'FreeType Support'] as $feature) {
    if (empty($gdInfo[$feature])) {
        error("gd was compiled without $feature");
    }
    success("[Extension] gd: $feature");
}
