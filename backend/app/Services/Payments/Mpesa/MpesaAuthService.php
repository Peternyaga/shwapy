<?php

namespace App\Services\Payments\Mpesa;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class MpesaAuthService
{
    public function getAccessToken(): string
    {
        $baseUrl = config('services.mpesa.env') === 'live'
            ? 'https://api.safaricom.co.ke'
            : 'https://sandbox.safaricom.co.ke';

        $response = Http::withBasicAuth(
            (string) config('services.mpesa.consumer_key'),
            (string) config('services.mpesa.consumer_secret')
        )->get($baseUrl.'/oauth/v1/generate', [
            'grant_type' => 'client_credentials',
        ]);

        if (! $response->successful()) {
            throw new RuntimeException('Failed to authenticate with Daraja API.');
        }

        $token = (string) $response->json('access_token');

        if ($token === '') {
            throw new RuntimeException('Daraja access token missing.');
        }

        return $token;
    }
}
