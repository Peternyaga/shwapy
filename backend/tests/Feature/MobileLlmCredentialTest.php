<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MobileLlmCredentialTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_fetch_encrypted_mobile_llm_session_key(): void
    {
        config([
            'services.gemini.api_key' => 'test-gemini-key',
            'services.gemini.mobile_encryption_secret' => 'test-mobile-secret',
            'services.gemini.mobile_key_ttl' => 300,
            'services.gemini.model' => 'gemini-2.5-flash',
        ]);

        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/llm/session-key?device_id=device-1234567890')
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.provider', 'gemini')
            ->assertJsonPath('data.model', 'gemini-2.5-flash')
            ->assertJsonStructure([
                'data' => [
                    'provider',
                    'model',
                    'base_url',
                    'encrypted_key',
                    'nonce',
                    'tag',
                    'expires_at',
                    'expires_at_unix',
                    'issued_at',
                    'key_id',
                ],
            ]);
    }

    public function test_mobile_llm_session_key_requires_device_id(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/llm/session-key')
            ->assertUnprocessable()
            ->assertJsonValidationErrors('device_id');
    }
}
