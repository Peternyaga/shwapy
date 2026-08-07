<?php

namespace Tests\Feature;

use App\Models\PaymentAccount;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TransactionHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_only_read_their_transaction_history(): void
    {
        $user = User::factory()->create();
        $otherUser = User::factory()->create();
        $owned = $this->transactionFor($user, 'success');
        $other = $this->transactionFor($otherUser, 'processing');

        Sanctum::actingAs($user);

        $this->getJson('/api/payments')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $owned->id)
            ->assertJsonPath('data.0.status', 'success')
            ->assertJsonPath('data.0.payment_account.merchant_name', 'Test merchant');

        $this->getJson('/api/payments/'.$other->id)->assertNotFound();
    }

    public function test_user_can_poll_a_transaction_after_callback_update(): void
    {
        $user = User::factory()->create();
        $transaction = $this->transactionFor($user, 'processing');

        $this->postJson('/api/payments/callback', [
            'Body' => ['stkCallback' => [
                'MerchantRequestID' => $transaction->merchant_request_id,
                'CheckoutRequestID' => $transaction->checkout_request_id,
                'ResultCode' => 0,
                'ResultDesc' => 'Processed successfully.',
            ]],
        ])->assertOk();

        Sanctum::actingAs($user);

        $this->getJson('/api/payments/'.$transaction->id)
            ->assertOk()
            ->assertJsonPath('data.status', 'success')
            ->assertJsonPath('data.result_description', 'Processed successfully.');
    }

    private function transactionFor(User $user, string $status): Transaction
    {
        $account = PaymentAccount::create([
            'type' => 'till',
            'till_no' => (string) random_int(100000, 999999),
            'merchant_name' => 'Test merchant',
            'created_by_user_id' => $user->id,
        ]);

        return Transaction::create([
            'user_id' => $user->id,
            'payment_account_id' => $account->id,
            'merchant_request_id' => 'mid-'.$user->id,
            'checkout_request_id' => 'cid-'.$user->id,
            'transaction_type' => 'CustomerBuyGoodsOnline',
            'phone_number' => '254712345678',
            'amount' => 500,
            'status' => $status,
        ]);
    }
}
