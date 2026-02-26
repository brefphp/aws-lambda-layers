<?php declare(strict_types=1);

function success(string $message): void
{
    echo "\033[32m✓ $message\033[0m" . PHP_EOL;
}

/**
 * @return never-return
 */
#[NoReturn] function error(string $message): void
{
    echo "\033[31m⨯ $message\033[0m" . PHP_EOL;
    exit(1);
}

/**
 * @param string[] $messages
 * @return never-return
 */
#[NoReturn] function errors(array $messages): void
{
    foreach ($messages as $message) {
        echo "\033[31m⨯ $message\033[0m" . PHP_EOL;
    }
    exit(1);
}

/**
 * Wait for a port to be available (useful for QEMU-emulated containers that start slowly).
 */
function waitForPort(string $host, int $port, int $timeoutSeconds = 5): void
{
    $start = time();
    while (true) {
        $socket = @fsockopen($host, $port, $errno, $errstr, 1);
        if ($socket !== false) {
            fclose($socket);
            return;
        }
        if (time() - $start >= $timeoutSeconds) {
            error("Timeout waiting for $host:$port to be available");
        }
        usleep(100000); // 100ms
    }
}
