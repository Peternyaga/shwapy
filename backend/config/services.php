<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'mpesa' => [
        'env' => env('MPESA_ENV', 'sandbox'),
        'consumer_key' => env('MPESA_ENV') === 'live'
            ? env('MPESA_CONSUMER_KEY')
            : env('MPESA_CONSUMER_KEY_SANDBOX'),
        'consumer_secret' => env('MPESA_ENV') === 'live'
            ? env('MPESA_CONSUMER_SECRET')
            : env('MPESA_CONSUMER_SECRET_SANDBOX'),
        'shortcode' => env('MPESA_ENV') === 'live'
            ? env('MPESA_SHORTCODE')
            : env('MPESA_SHORTCODE_SANDBOX'),
        'passkey' => env('MPESA_ENV') === 'live'
            ? env('MPESA_PASSKEY')
            : env('MPESA_PASSKEY_SANDBOX'),
        'callback_url' => env('MPESA_CALLBACK_URL'),
    ],

    'gemini' => [
        'api_key' => env('GEMINI_API_KEY'),
        'model' => env('GEMINI_MODEL', 'gemini-2.5-flash'),
        'base_url' => env('GEMINI_BASE_URL', 'https://generativelanguage.googleapis.com/v1beta'),
        'timeout' => env('GEMINI_TIMEOUT', 8),
        'file_timeout' => env('GEMINI_FILE_TIMEOUT', 15),
        'connect_timeout' => env('GEMINI_CONNECT_TIMEOUT', 2),
        'max_file_bytes' => env('GEMINI_MAX_FILE_BYTES', 3 * 1024 * 1024),
        'mobile_key_ttl' => env('GEMINI_MOBILE_KEY_TTL', 600),
        'mobile_encryption_secret' => env('GEMINI_MOBILE_ENCRYPTION_SECRET'),
    ],

    'google' => [
        'client_ids' => array_values(array_filter(array_map(
            'trim',
            explode(',', (string) env('GOOGLE_CLIENT_IDS', ''))
        ))),
    ],

];
