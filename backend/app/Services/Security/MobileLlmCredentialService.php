<?php

namespace App\Services\Security;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Str;
use RuntimeException;

class MobileLlmCredentialService
{
    /**
     * @return array<string, string|int>
     */
    public function issue(User $user, string $deviceId, ?int $tokenId): array
    {
        $apiKey = (string) config('services.gemini.api_key');
        $secret = (string) config('services.gemini.mobile_encryption_secret');

        if ($apiKey === '' || $secret === '') {
            throw new RuntimeException('Mobile Gemini credentials are not configured.');
        }

        $ttl = max(60, min(900, (int) config('services.gemini.mobile_key_ttl', 600)));
        $issuedAt = CarbonImmutable::now();
        $expiresAt = $issuedAt->addSeconds($ttl);
        $nonce = random_bytes(12);
        $keyId = (string) Str::uuid();
        $aad = $this->aad($user, $deviceId, $expiresAt->timestamp, $tokenId, $keyId);
        $key = $this->key($user, $deviceId, $expiresAt->timestamp, $tokenId);
        $tag = '';
        $ciphertext = openssl_encrypt(
            $apiKey,
            'aes-256-gcm',
            $key,
            OPENSSL_RAW_DATA,
            $nonce,
            $tag,
            $aad,
            16
        );

        if ($ciphertext === false) {
            throw new RuntimeException('Could not encrypt mobile Gemini credentials.');
        }

        return [
            'provider' => 'gemini',
            'model' => (string) config('services.gemini.model', 'gemini-2.5-flash'),
            'base_url' => rtrim((string) config('services.gemini.base_url'), '/'),
            'encrypted_key' => base64_encode($ciphertext),
            'nonce' => base64_encode($nonce),
            'tag' => base64_encode($tag),
            'expires_at' => $expiresAt->toIso8601String(),
            'expires_at_unix' => $expiresAt->timestamp,
            'issued_at' => $issuedAt->toIso8601String(),
            'key_id' => $keyId,
        ];
    }

    private function key(User $user, string $deviceId, int $expiresAt, ?int $tokenId): string
    {
        $material = implode('|', [
            config('services.gemini.mobile_encryption_secret'),
            $user->getKey(),
            $user->email,
            $deviceId,
            $expiresAt,
            $tokenId ?? 'transient',
        ]);

        return hash('sha256', $material, true);
    }

    private function aad(User $user, string $deviceId, int $expiresAt, ?int $tokenId, string $keyId): string
    {
        return implode('|', [
            'shwapy-mobile-llm-key-v1',
            $user->getKey(),
            $deviceId,
            $expiresAt,
            $tokenId ?? 'transient',
            $keyId,
        ]);
    }
}
