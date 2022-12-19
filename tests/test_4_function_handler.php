<?php declare(strict_types=1);

return function ($event, \Bref\Context\Context $context) {
    // Support for test 7
    if ($event === 'list_extensions') {
        return get_loaded_extensions();
    }

    return [
        'event' => $event,
        'server' => $_SERVER,
        'memory_limit' => ini_get('memory_limit'),
    ];
};
