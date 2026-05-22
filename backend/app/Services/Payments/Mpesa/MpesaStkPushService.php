<?php

namespace App\Services\Payments\Mpesa;

use App\Models\PaymentAccount;
use App\Models\Transaction;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class MpesaStkPushService
{
    public function __construct(private readonly MpesaAuthService $mpesaAuthService)
    {
    }

    /**
     * @return array<string, mixed>
     */
    public function initiate(Transaction $transaction, PaymentAccount $paymentAccount, string $phoneNumber, float $amount): array
    {
        $token = $this->mpesaAuthService->getAccessToken();
        $timestamp = now()->format('YmdHis');
        $shortCode = (string) config('services.mpesa.shortcode');
        $passkey = (string) config('services.mpesa.passkey');
        $callbackUrl = (string) config('services.mpesa.callback_url');

        if ($shortCode === '' || $passkey === '' || $callbackUrl === '') {
            throw new RuntimeException('M-Pesa environment variables are not configured.');
        }

        $transactionType = $paymentAccount->type === 'till'
            ? 'CustomerBuyGoodsOnline'
            : 'CustomerPayBillOnline';

        $partyB = $paymentAccount->type === 'till'
            ? $paymentAccount->till_no
            : $paymentAccount->paybill_no;

        if (! $partyB) {
            throw new RuntimeException('Missing destination business shortcode.');
        }

        $password = base64_encode($shortCode.$passkey.$timestamp);
        $endpoint = config('services.mpesa.env') === 'live'
            ? 'https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest'
            : 'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest';

        $payload = [
            'BusinessShortCode' => $shortCode,
            'Password' => $password,
            'Timestamp' => $timestamp,
            'TransactionType' => $transactionType,
            'Amount' => (int) round($amount),
            'PartyA' => $phoneNumber,
            'PartyB' => $partyB,
            'PhoneNumber' => $phoneNumber,
            'CallBackURL' => $callbackUrl,
            'AccountReference' => $paymentAccount->account_no ?? ($paymentAccount->merchant_name ?: 'Shwapy'),
            'TransactionDesc' => 'Shwapy checkout #'.$transaction->id,
        ];

        $response = Http::withToken($token)
            ->acceptJson()
            ->post($endpoint, $payload);

        $result = $response->json() ?? [];

        if (! $response->successful()) {
            $message = is_array($result) ? ($result['errorMessage'] ?? $result['message'] ?? 'STK push request failed.') : 'STK push request failed.';

            throw new RuntimeException('STK push request failed: '.json_encode([
                'status' => $response->status(),
                'body' => $result,
                'message' => $message,
            ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
        }

        if (! is_array($result)) {
            throw new RuntimeException('Invalid STK response payload.');
        }

        return $result;
    }
}
