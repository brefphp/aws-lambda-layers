<?php declare(strict_types=1);

require_once __DIR__ . '/utils.php';

function post(string $url, array $params)
{
    $ch = curl_init();

    $jsonData = json_encode($params);

    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json', 'Content-Length: ' . strlen($jsonData)]);
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonData);

    $response = curl_exec($ch);

    curl_close($ch);

    if ($response === false) {
        throw new Exception('Curl error: ' . curl_error($ch));
    }

    return $response;
}

$body = ['Hello' => 'From Bref!'];

try {
    $response = post('http://127.0.0.1:8080/2015-03-31/functions/function/invocations', $body);
    $response = json_decode($response, true, 512, JSON_THROW_ON_ERROR);
} catch (Throwable $e) {
    error($e->getMessage() . PHP_EOL . $e->getTraceAsString());
}

if ($response['event']['Hello'] !== 'From Bref!') {
    error('Unexpected response: ' . json_encode($response));
}

if ($response['memory_limit'] !== '586M') {
    error('Failed to load php.ini from /var/task/php/conf.d/');
}

success('[Invoke] Function');
