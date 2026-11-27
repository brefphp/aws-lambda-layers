<?php declare(strict_types=1);

header('X-Max-Execution-Time: ' . ini_get('max_execution_time'));
header('X-Output-Buffering: ' . ini_get('output_buffering'));

echo "Hello from Bref FPM!";

// Trigger a warning to test that it is not sent to stdout
include 'does-not-exist.php';
