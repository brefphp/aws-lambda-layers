<?php declare(strict_types=1);

echo "Hello from Bref FPM!";

// Trigger a warning to test that it is not sent to stdout
include 'does-not-exist.php';
