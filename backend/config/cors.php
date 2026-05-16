<?php

return [
    'paths' => [
        'api/*',
        'sanctum/csrf-cookie',
        'payments/callback',
    ],

    'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],

    'allowed_origins' => [
        'http://localhost:5173',
        'http://127.0.0.1:5173',
        'http://192.168.137.1:5173',
        'http://192.168.100.6:5173',
    ],

    'allowed_origins_patterns' => [
        'http://192\.168\.\d+\.\d+:5173',
        'http://10\.\d+\.\d+\.\d+:5173',
    ],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => true,
];
