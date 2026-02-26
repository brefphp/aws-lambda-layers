<?php declare(strict_types=1);

require_once __DIR__ . '/utils.php';

function post(string $url, string $body)
{
    $ch = curl_init();

    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json', 'Content-Length: ' . strlen($body)]);
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $body);

    $response = curl_exec($ch);

    curl_close($ch);

    if ($response === false) {
        throw new Exception('Curl error: ' . curl_error($ch));
    }

    return $response;
}

$body = file_get_contents(__DIR__ . '/test_5_event.json');

waitForPort('127.0.0.1', 8080);

try {
    $response = post('http://127.0.0.1:8080/2015-03-31/functions/function/invocations', $body);
    $response = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
} catch (Throwable $e) {
    error($e->getMessage() . PHP_EOL . $e->getTraceAsString());
}

if ($response['body'] !== 'Hello from Bref FPM!') {
    error('Unexpected response: ' . json_encode($response));
}

success('[Invoke] FPM');
