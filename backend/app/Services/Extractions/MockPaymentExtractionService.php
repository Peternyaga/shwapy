<?php

namespace App\Services\Extractions;

use App\DTOs\PaymentDetailsDTO;

class MockPaymentExtractionService
{
    public function extract(): PaymentDetailsDTO
    {
        return PaymentDetailsDTO::fromArray([
            'type' => 'paybill',
            'paybill_no' => '247247',
            'account_no' => 'ABC123',
            'till_no' => null,
            'merchant_name' => 'Kenya Power',
            'amount' => 3500,
            'confidence' => 0.93,
        ]);
    }
}
