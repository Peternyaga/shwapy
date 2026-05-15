<?php

namespace App\Services\Extractions;

use App\DTOs\PaymentDetailsDTO;

class MockPaymentExtractionService implements PaymentExtractionService
{
    /**
     * @param array<string, mixed> $payload
     */
    public function extract(array $payload = []): PaymentDetailsDTO
    {
        return PaymentDetailsDTO::fromArray([
            'type' => 'paybill',
            'paybill_no' => '247247',
            'account_no' => 'ABC123',
            'till_no' => null,
            'merchant_name' => 'Kenya Power',
            'amount' => 3500,
            'currency' => 'KES',
            'phone_number' => $payload['phone_number'] ?? null,
            'confidence' => 0.93,
            'missing_fields' => [],
            'warnings' => [],
        ]);
    }
}
