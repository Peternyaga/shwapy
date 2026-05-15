<?php

namespace App\Services\Extractions;

use App\DTOs\PaymentDetailsDTO;

interface PaymentExtractionService
{
    /**
     * @param array<string, mixed> $payload
     */
    public function extract(array $payload): PaymentDetailsDTO;
}
