<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\Payments\Checkout\PaymentAccountResolver;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PaymentAccountResolverTest extends TestCase
{
    use RefreshDatabase;

    public function test_resolver_reuses_existing_paybill_account(): void
    {
        $user = User::factory()->create();
        $resolver = app(PaymentAccountResolver::class);

        $first = $resolver->resolve([
            'type' => 'paybill',
            'paybill_no' => '247247',
            'account_no' => 'ABC123',
            'merchant_name' => 'Kenya Power',
        ], $user->id);

        $second = $resolver->resolve([
            'type' => 'paybill',
            'paybill_no' => '247247',
            'account_no' => 'ABC123',
            'merchant_name' => 'Kenya Power',
        ], $user->id);

        $this->assertSame($first->id, $second->id);
        $this->assertDatabaseCount('payment_accounts', 1);
    }
}
