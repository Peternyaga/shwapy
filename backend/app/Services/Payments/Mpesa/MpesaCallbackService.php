<?php

namespace App\Services\Payments\Mpesa;

use App\Models\Transaction;
use App\Services\Payments\Checkout\TransactionRecorder;
use Illuminate\Support\Facades\Log;

class MpesaCallbackService
{
    public function __construct(private readonly TransactionRecorder $transactionRecorder)
    {
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function handle(array $payload): ?Transaction
    {
        $transaction = $this->transactionRecorder->applyCallback($payload);

        if (! $transaction) {
            Log::warning('Callback received for unknown transaction.', [
                'payload' => $payload,
            ]);
        }

        return $transaction;
    }
}
