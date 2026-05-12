<?php

namespace App\Services\Payments\Checkout;

use App\Models\PaymentAccount;
use App\Models\Transaction;
use App\Models\User;

class TransactionRecorder
{
    /**
     * @param array<string, mixed>|null $rawExtraction
     */
    public function createPending(
        User $user,
        PaymentAccount $paymentAccount,
        string $phoneNumber,
        float $amount,
        ?float $extractionConfidence = null,
        ?array $rawExtraction = null,
    ): Transaction {
        return Transaction::create([
            'user_id' => $user->id,
            'payment_account_id' => $paymentAccount->id,
            'transaction_type' => $paymentAccount->type === 'till'
                ? 'CustomerBuyGoodsOnline'
                : 'CustomerPayBillOnline',
            'phone_number' => $phoneNumber,
            'amount' => $amount,
            'status' => Transaction::STATUS_PENDING,
            'extraction_confidence' => $extractionConfidence,
            'raw_extraction' => $rawExtraction,
        ]);
    }

    public function markProcessingWithStkIds(
        Transaction $transaction,
        string $merchantRequestId,
        string $checkoutRequestId,
    ): Transaction {
        $transaction->update([
            'status' => Transaction::STATUS_PROCESSING,
            'merchant_request_id' => $merchantRequestId,
            'checkout_request_id' => $checkoutRequestId,
        ]);

        return $transaction->fresh();
    }

    public function markFailed(Transaction $transaction, ?array $rawCallback = null): Transaction
    {
        $transaction->update([
            'status' => Transaction::STATUS_FAILED,
            'raw_callback' => $rawCallback,
        ]);

        return $transaction->fresh();
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function applyCallback(array $payload): ?Transaction
    {
        $checkoutRequestId = (string) data_get($payload, 'Body.stkCallback.CheckoutRequestID', '');

        if ($checkoutRequestId === '') {
            return null;
        }

        $transaction = Transaction::where('checkout_request_id', $checkoutRequestId)->first();

        if (! $transaction) {
            return null;
        }

        $resultCode = (int) data_get($payload, 'Body.stkCallback.ResultCode', -1);
        $status = match ($resultCode) {
            0 => Transaction::STATUS_SUCCESS,
            1032 => Transaction::STATUS_CANCELLED,
            1037 => Transaction::STATUS_TIMEOUT,
            default => Transaction::STATUS_FAILED,
        };

        $transaction->update([
            'status' => $status,
            'raw_callback' => $payload,
        ]);

        return $transaction->fresh();
    }
}
