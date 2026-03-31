<?php
declare(strict_types=1);

function get_database_config(): array
{
    $defaults = [
        'host' => 'CHANGE_ME_DB_HOST',
        'port' => 3306,
        'name' => 'sample',
        'user' => 'tutorial_user',
        'password' => 'CHANGE_ME_DB_PASSWORD',
        'charset' => 'utf8mb4',
    ];

    $config = $defaults;
    $localConfigPath = __DIR__ . '/db_settings.local.php';

    if (is_file($localConfigPath)) {
        $localConfig = require $localConfigPath;
        if (is_array($localConfig)) {
            foreach ($localConfig as $key => $value) {
                if ($value !== null && $value !== '') {
                    $config[$key] = $value;
                }
            }
        }
    }

    $environmentMap = [
        'host' => getenv('APP_DB_HOST') ?: null,
        'port' => getenv('APP_DB_PORT') ?: null,
        'name' => getenv('APP_DB_NAME') ?: null,
        'user' => getenv('APP_DB_USER') ?: null,
        'password' => getenv('APP_DB_PASSWORD') ?: null,
    ];

    foreach ($environmentMap as $key => $value) {
        if ($value !== null && $value !== '') {
            $config[$key] = $value;
        }
    }

    $config['port'] = (int) $config['port'];

    return $config;
}

function database_config_placeholders(array $config): array
{
    $missing = [];

    foreach (['host', 'password'] as $requiredKey) {
        $value = $config[$requiredKey] ?? '';
        if ($value === '' || str_starts_with((string) $value, 'CHANGE_ME_')) {
            $missing[] = $requiredKey;
        }
    }

    return $missing;
}

function database_config_ready(array $config): bool
{
    return database_config_placeholders($config) === [];
}

function create_database_connection(array $config): PDO
{
    $dsn = sprintf(
        'mysql:host=%s;port=%d;dbname=%s;charset=%s',
        $config['host'],
        $config['port'],
        $config['name'],
        $config['charset']
    );

    return new PDO(
        $dsn,
        $config['user'],
        $config['password'],
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );
}
