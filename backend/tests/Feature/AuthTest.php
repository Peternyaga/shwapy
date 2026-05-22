<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Test User',
            'email' => 'test@example.com',
            'phone_number' => '0712345678',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => ['token', 'user'],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'test@example.com',
            'phone_number' => '254712345678',
        ]);
    }

    public function test_user_can_login_and_logout(): void
    {
        $user = User::factory()->create([
            'password' => bcrypt('password123'),
        ]);

        $login = $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'password123',
        ]);

        $token = $login->json('data.token');

        $login->assertOk()->assertJsonPath('success', true);

        $this->withHeader('Authorization', 'Bearer '.$token)
            ->postJson('/api/auth/logout')
            ->assertOk()
            ->assertJsonPath('success', true);
    }

    public function test_user_can_signup_with_google_token(): void
    {
        config(['services.google.client_ids' => ['ios-client-id']]);

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response([
                'sub' => 'google-subject-1',
                'aud' => 'ios-client-id',
                'email' => 'google@example.com',
                'email_verified' => 'true',
                'name' => 'Google User',
                'picture' => 'https://example.com/avatar.png',
            ]),
        ]);

        $response = $this->postJson('/api/auth/google', [
            'id_token' => 'valid-google-token',
            'phone_number' => '0712345678',
        ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure([
                'data' => ['token', 'user'],
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'google@example.com',
            'google_id' => 'google-subject-1',
            'phone_number' => '254712345678',
        ]);
    }

    public function test_google_signup_requires_phone_number_for_new_users(): void
    {
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response([
                'sub' => 'google-subject-2',
                'aud' => 'android-client-id',
                'email' => 'new@example.com',
                'email_verified' => 'true',
                'name' => 'New User',
            ]),
        ]);

        $this->postJson('/api/auth/google', [
            'id_token' => 'valid-google-token',
        ])
            ->assertUnprocessable()
            ->assertJsonPath('success', false);
    }
}
