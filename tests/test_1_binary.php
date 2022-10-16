<?php declare(strict_types=1);

require_once __DIR__ . '/utils.php';

$expected = $_SERVER['argv'][1];
$actual = str_replace('.', '', PHP_VERSION);

if (! str_starts_with($actual, $expected)) {
    error("Expected version [$expected] does not match " . PHP_VERSION);
}

success("[Version] PHP version $expected");
