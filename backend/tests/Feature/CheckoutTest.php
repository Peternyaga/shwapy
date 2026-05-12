<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\Payments\Mpesa\MpesaStkPushService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CheckoutTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_checkout_with_paybill(): void
    {
        $user = User::factory()->create();

        Sanctum::actingAs($user);

        $this->instance(MpesaStkPushService::class, new class extends MpesaStkPushService {
            public function __construct()
            {
            }

            public function initiate($transaction, $paymentAccount, string $phoneNumber, float $amount): array
            {
                return [
                    'ResponseCode' => '0',
                    'CustomerMessage' => 'Success. Request accepted for processing',
                    'MerchantRequestID' => 'mid-123',
                    'CheckoutRequestID' => 'cid-123',
                ];
            }
        });

        $response = $this->postJson('/api/payments/checkout', [
            'payment_account' => [
                'type' => 'paybill',
                'paybill_no' => '247247',
                'account_no' => 'ABC123',
                'merchant_name' => 'Kenya Power',
            ],
            'amount' => 3500,
            'phone_number' => '0712345678',
            'extraction_confidence' => 0.93,
            'raw_extraction' => ['sample' => 'payload'],
        ]);

        $response->assertOk()->assertJsonPath('success', true);

        $this->assertDatabaseHas('transactions', [
            'user_id' => $user->id,
            'merchant_request_id' => 'mid-123',
            'checkout_request_id' => 'cid-123',
            'status' => 'processing',
            'phone_number' => '254712345678',
        ]);
    }
}
