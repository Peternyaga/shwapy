<?php

namespace Tests\Unit;

use App\Models\PaymentAccount;
use App\Models\Transaction;
use App\Services\Payments\Mpesa\MpesaAuthService;
use App\Services\Payments\Mpesa\MpesaStkPushService;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class MpesaStkPushServiceTest extends TestCase
{
    public function test_it_sends_a_distinct_buy_goods_till_as_party_b(): void
    {
        config([
            'services.mpesa.env' => 'live',
            'services.mpesa.shortcode' => '6789398',
            'services.mpesa.passkey' => 'test-passkey',
            'services.mpesa.callback_url' => 'https://example.com/api/payments/callback',
        ]);

        Http::fake([
            'https://api.safaricom.co.ke/*' => Http::response([
                'ResponseCode' => '0',
                'MerchantRequestID' => 'merchant-request',
                'CheckoutRequestID' => 'checkout-request',
            ]),
        ]);

        $service = new MpesaStkPushService($this->fakeAuthService());
        $transaction = new Transaction();
        $transaction->id = 1;
        $paymentAccount = new PaymentAccount([
            'type' => 'till',
            'till_no' => '544600',
        ]);

        $service->initiate($transaction, $paymentAccount, '254712345678', 100);

        Http::assertSent(fn ($request): bool =>
            data_get($request->data(), 'BusinessShortCode') === '6789398'
            && data_get($request->data(), 'PartyB') === '544600'
            && data_get($request->data(), 'TransactionType') === 'CustomerBuyGoodsOnline'
        );
    }

    public function test_it_sends_a_paybill_destination_as_party_b(): void
    {
        config([
            'services.mpesa.env' => 'live',
            'services.mpesa.shortcode' => '522533',
            'services.mpesa.passkey' => 'test-passkey',
            'services.mpesa.callback_url' => 'https://example.com/api/payments/callback',
        ]);

        Http::fake([
            'https://api.safaricom.co.ke/*' => Http::response([
                'ResponseCode' => '0',
                'MerchantRequestID' => 'merchant-request',
                'CheckoutRequestID' => 'checkout-request',
            ]),
        ]);

        $service = new MpesaStkPushService($this->fakeAuthService());
        $transaction = new Transaction();
        $transaction->id = 1;
        $paymentAccount = new PaymentAccount([
            'type' => 'paybill',
            'paybill_no' => '522533',
            'account_no' => '23',
        ]);

        $service->initiate($transaction, $paymentAccount, '254712345678', 100);

        Http::assertSent(fn ($request): bool =>
            data_get($request->data(), 'BusinessShortCode') === '522533'
            && data_get($request->data(), 'PartyB') === '522533'
            && data_get($request->data(), 'TransactionType') === 'CustomerPayBillOnline'
        );
    }

    private function fakeAuthService(): MpesaAuthService
    {
        return new class extends MpesaAuthService
        {
            public function getAccessToken(): string
            {
                return 'test-token';
            }
        };
    }
}
