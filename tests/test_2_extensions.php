<?php declare(strict_types=1);

require_once __DIR__ . '/utils.php';

$expectedExtensions = [
    'bcmath',
    'ctype',
    'curl',
    'date',
    'dom',
    'exif',
    'fileinfo',
    'filter',
    'ftp',
    'gettext',
    'hash',
    'iconv',
    'json',
    'libxml',
    'mbstring',
    'mysqli',
    'mysqlnd',
    'Zend OPcache',
    'openssl',
    'pcntl',
    'pcre',
    'PDO',
    'pdo_sqlite',
    'pdo_mysql',
    'Phar',
    'posix',
    'readline',
    'Reflection',
    'session',
    'SimpleXML',
    'sodium',
    'soap',
    'sockets',
    'SPL',
    'sqlite3',
    'tokenizer',
    'xml',
    'xmlreader',
    'xmlwriter',
    'xsl',
    'zlib',
];
$loadedExtensions = get_loaded_extensions();
$missingExtensions = array_diff($expectedExtensions, $loadedExtensions);
if ($missingExtensions) {
    error('[Extensions] The following extensions are missing: ' . implode(', ', $missingExtensions));
}

// The tests below are more robust: sometimes an extension is "loaded" but broken (e.g. a system lib missing)

$coreExtensions = [
    'date' => class_exists(\DateTime::class),
    'filter_var' => filter_var('bref@bref.com', FILTER_VALIDATE_EMAIL),
    'hash' => hash('md5', 'Bref') === 'df4647d91c4a054af655c8eea2bce541',
    'libxml' => class_exists(\LibXMLError::class),
    'openssl' => strlen(openssl_random_pseudo_bytes(1)) === 1,
    'pntcl' => function_exists('pcntl_fork'),
    'pcre' => preg_match('/abc/', 'abcde', $matches) && $matches[0] === 'abc',
    'readline' => READLINE_LIB === 'readline',
    'reflection' => class_exists(\ReflectionClass::class),
    'session' => session_status() === PHP_SESSION_NONE,
    'zip' => class_exists(\ZipArchive::class),
    'zlib' => md5(gzcompress('abcde')) === 'db245560922b42f1935e73e20b30980e',
];
foreach ($coreExtensions as $extension => $test) {
    if (! $test) {
        error($extension . ' core extension was not loaded');
    }
    success("[Core extension] $extension");
}

$extensions = [
    'curl' => function_exists('curl_init')
        // Make sure we are not using the default AL2 cURL version (7.79)
        && version_compare(curl_version()['version'], '7.84.0', '>='),
    // https://github.com/brefphp/aws-lambda-layers/issues/42
    'curl-http2' => defined('CURL_HTTP_VERSION_2'),
    // Make sure we are not using the default AL2 OpenSSL version (7.79)
    'curl-openssl' => str_starts_with(curl_version()['ssl_version'], 'OpenSSL/1.1.1') || str_starts_with(curl_version()['ssl_version'], 'OpenSSL/3.0'),
    // Check that the default certificate file exists
    // https://github.com/brefphp/aws-lambda-layers/issues/53
    'curl-openssl-certificates' => file_exists(openssl_get_cert_locations()['default_cert_file']),
    // Check its location has not changed (would be a breaking change)
    'curl-openssl-certificates-location' => openssl_get_cert_locations()['default_cert_file'] === '/opt/bref/ssl/cert.pem',
    // Make sure we are using curl with our compiled libssh
    'curl-libssh' => version_compare(str_replace('libssh2/', '', curl_version()['libssh_version']), '1.10.0', '>='),
    'json' => function_exists('json_encode'),
    'bcmath' => function_exists('bcadd'),
    'ctype' => function_exists('ctype_digit'),
    'dom' => class_exists(\DOMDocument::class),
    'exif' => function_exists('exif_imagetype'),
    'fileinfo' => function_exists('finfo_file'),
    'ftp' => function_exists('ftp_connect'),
    'gettext' => function_exists('gettext'),
    'iconv' => function_exists('iconv_strlen'),
    'mbstring' => function_exists('mb_strlen'),
    'mysqli' => function_exists('mysqli_connect'),
    'opcache' => ini_get('opcache.enable') == 1,
    'pdo' => class_exists(\PDO::class),
    'pdo_mysql' => extension_loaded('pdo_mysql'),
    'pdo_sqlite' => extension_loaded('pdo_sqlite'),
    'phar' => extension_loaded('phar'),
    'posix' => function_exists('posix_getpgid'),
    'simplexml' => class_exists(\SimpleXMLElement::class),
    'sodium' => defined('PASSWORD_ARGON2I'),
    'soap' => class_exists(\SoapClient::class),
    'sockets' => function_exists('socket_connect'),
    'spl' => class_exists(\SplQueue::class),
    'sqlite3' => class_exists(\SQLite3::class),
    'tokenizer' => function_exists('token_get_all'),
    'libxml' => function_exists('libxml_get_errors'),
    'xml' => function_exists('xml_parse'),
    'xmlreader' => class_exists(\XMLReader::class),
    'xmlwriter' => class_exists(\XMLWriter::class),
    'xsl' => class_exists(\XSLTProcessor::class),
];
$errors = [];
foreach ($extensions as $extension => $test) {
    if (! $test) {
        $errors[] = "[Extension] $extension extension was not loaded or failed the test";
    }
    success("[Extension] $extension");
}
if ($errors) {
    errors($errors);
}

$extensionsDisabledByDefault = [
    'intl' => class_exists(\Collator::class),
    'apcu' => function_exists('apcu_add'),
    'pdo_pgsql' => extension_loaded('pdo_pgsql'),
];
foreach ($extensionsDisabledByDefault as $extension => $test) {
    if ($test) {
        error($extension . ' extension was not supposed to be loaded');
    }
    success("[Extension] $extension (disabled)");
}
