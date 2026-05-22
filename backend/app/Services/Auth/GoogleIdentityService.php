<?php

namespace App\Services\Auth;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class GoogleIdentityService
{
    /**
     * @return array{sub: string, email: string, name: string, picture: ?string}
     */
    public function verify(string $idToken): array
    {
        $response = Http::timeout(4)
            ->connectTimeout(2)
            ->acceptJson()
            ->get('https://oauth2.googleapis.com/tokeninfo', [
                'id_token' => $idToken,
            ]);

        if (! $response->successful()) {
            throw new RuntimeException('Google sign-in token could not be verified.');
        }

        $payload = $response->json();
        $clientIds = config('services.google.client_ids', []);
        $audience = (string) data_get($payload, 'aud');

        if (is_array($clientIds) && $clientIds !== [] && ! in_array($audience, $clientIds, true)) {
            throw new RuntimeException('Google sign-in token audience is not allowed.');
        }

        $emailVerified = data_get($payload, 'email_verified');

        if ($emailVerified !== true && (string) $emailVerified !== 'true') {
            throw new RuntimeException('Google account email is not verified.');
        }

        $subject = trim((string) data_get($payload, 'sub'));
        $email = trim((string) data_get($payload, 'email'));

        if ($subject === '' || $email === '') {
            throw new RuntimeException('Google sign-in token is missing required identity fields.');
        }

        return [
            'sub' => $subject,
            'email' => strtolower($email),
            'name' => trim((string) data_get($payload, 'name')) ?: $email,
            'picture' => data_get($payload, 'picture'),
        ];
    }
}
