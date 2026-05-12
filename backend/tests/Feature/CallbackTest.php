<?php

namespace Tests\Feature;

use App\Models\PaymentAccount;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CallbackTest extends TestCase
{
    use RefreshDatabase;

    public function test_callback_updates_transaction_status_without_auth(): void
    {
        $user = User::factory()->create();
        $paymentAccount = PaymentAccount::create([
            'type' => 'paybill',
            'paybill_no' => '247247',
            'account_no' => 'ACC-001',
            'merchant_name' => 'Kenya Power',
            'created_by_user_id' => $user->id,
        ]);

        $transaction = Transaction::create([
            'user_id' => $user->id,
            'payment_account_id' => $paymentAccount->id,
            'merchant_request_id' => 'mid-123',
            'checkout_request_id' => 'cid-123',
            'transaction_type' => 'CustomerPayBillOnline',
            'phone_number' => '254712345678',
            'amount' => 3500,
            'status' => 'processing',
        ]);

        $payload = [
            'Body' => [
                'stkCallback' => [
                    'MerchantRequestID' => 'mid-123',
                    'CheckoutRequestID' => 'cid-123',
                    'ResultCode' => 0,
                    'ResultDesc' => 'The service request is processed successfully.',
                ],
            ],
        ];

        $this->postJson('/api/payments/callback', $payload)
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.transaction_id', $transaction->id)
            ->assertJsonPath('data.status', 'success');

        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'status' => 'success',
        ]);
    }
}
