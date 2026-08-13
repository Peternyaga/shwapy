<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PaymentExtractionTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_extract_text_with_missing_amount(): void
    {
        config([
            'services.gemini.api_key' => 'test-key',
            'services.gemini.model' => 'gemini-2.5-flash',
        ]);

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'payment_account' => [
                                            'type' => 'paybill',
                                            'paybill_no' => '247247',
                                            'account_no' => 'ABC123',
                                            'till_no' => null,
                                            'merchant_name' => 'Kenya Power',
                                        ],
                                        'amount' => null,
                                        'currency' => 'KES',
                                        'phone_number' => null,
                                        'confidence' => 0.88,
                                        'missing_fields' => ['amount'],
                                        'warnings' => [],
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ]),
        ]);

        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/extractions/payment', [
            'type' => 'text',
            'content' => 'Pay Kenya Power paybill 247247 account ABC123.',
            'phone_number' => '0759265709',
        ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_account.type', 'paybill')
            ->assertJsonPath('data.payment_account.paybill_no', '247247')
            ->assertJsonPath('data.amount', null)
            ->assertJsonPath('data.phone_number', '254759265709')
            ->assertJsonPath('data.missing_fields.0', 'amount');

        Http::assertSent(fn ($request): bool => $request->hasHeader('x-goog-api-key', 'test-key')
            && data_get($request->data(), 'generationConfig.responseMimeType') === 'application/json'
            && data_get($request->data(), 'generationConfig.maxOutputTokens') === 2048
            && data_get($request->data(), 'generationConfig.thinkingConfig.thinkingBudget') === 0
            && data_get($request->data(), 'generationConfig.responseSchema.additionalProperties') === null
            && data_get($request->data(), 'generationConfig.responseSchema.properties.payment_account.additionalProperties') === null);
    }

    public function test_authenticated_user_can_extract_image_content(): void
    {
        config([
            'services.gemini.api_key' => 'test-key',
            'services.gemini.model' => 'gemini-2.5-flash',
        ]);

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'payment_account' => [
                                            'type' => 'till',
                                            'paybill_no' => null,
                                            'account_no' => null,
                                            'till_no' => '123456',
                                            'merchant_name' => 'Test Merchant',
                                        ],
                                        'amount' => 1,
                                        'currency' => 'KES',
                                        'phone_number' => '0759265709',
                                        'confidence' => 0.91,
                                        'missing_fields' => [],
                                        'warnings' => [],
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ]),
        ]);

        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/extractions/payment', [
            'type' => 'image',
            'mime_type' => 'image/png',
            'content' => base64_encode('small-image-bytes'),
        ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_account.type', 'till')
            ->assertJsonPath('data.payment_account.till_no', '123456')
            ->assertJsonPath('data.amount', 1)
            ->assertJsonPath('data.phone_number', '254759265709');

        Http::assertSent(fn ($request): bool => data_get($request->data(), 'contents.0.parts.1.inline_data.mime_type') === 'image/png');
    }

    public function test_file_extraction_requires_base64_content(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/extractions/payment', [
            'type' => 'pdf',
            'mime_type' => 'application/pdf',
            'content' => 'not-base64',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('content');
    }

    public function test_authenticated_user_can_extract_multipart_image_upload(): void
    {
        config([
            'services.gemini.api_key' => 'test-key',
            'services.gemini.model' => 'gemini-2.5-flash',
        ]);

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    [
                        'content' => [
                            'parts' => [
                                [
                                    'text' => json_encode([
                                        'payment_account' => [
                                            'type' => 'till',
                                            'paybill_no' => null,
                                            'account_no' => null,
                                            'till_no' => '0742064136',
                                            'merchant_name' => 'Kims Furnit',
                                        ],
                                        'amount' => null,
                                        'currency' => 'KES',
                                        'phone_number' => null,
                                        'confidence' => 0.9,
                                        'missing_fields' => ['amount', 'phone_number'],
                                        'warnings' => [],
                                    ]),
                                ],
                            ],
                        ],
                    ],
                ],
            ]),
        ]);

        Sanctum::actingAs(User::factory()->create());

        $this->post('/api/extractions/payment', [
            'type' => 'image',
            'content' => UploadedFile::fake()->image('till.jpeg', 800, 600),
        ], [
            'Accept' => 'application/json',
        ])
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.payment_account.till_no', '0742064136')
            ->assertJsonPath('data.amount', null);

        Http::assertSent(fn ($request): bool => data_get($request->data(), 'contents.0.parts.1.inline_data.mime_type') === 'image/jpeg'
            && is_string(data_get($request->data(), 'contents.0.parts.1.inline_data.data')));
    }
}
