<?php

namespace App\DTOs;

final class CheckoutRequestDTO
{
    /**
     * @param array<string, mixed> $paymentAccount
     */
    public function __construct(
        public readonly array $paymentAccount,
        public readonly string $phoneNumber,
        public readonly float $amount,
        public readonly ?float $extractionConfidence,
        public readonly ?array $rawExtraction,
    ) {
    }

    /**
     * @param array<string, mixed> $payload
     */
    public static function fromArray(array $payload): self
    {
        return new self(
            paymentAccount: (array) ($payload['payment_account'] ?? []),
            phoneNumber: (string) ($payload['phone_number'] ?? ''),
            amount: (float) ($payload['amount'] ?? 0),
            extractionConfidence: isset($payload['extraction_confidence']) ? (float) $payload['extraction_confidence'] : null,
            rawExtraction: isset($payload['raw_extraction']) && is_array($payload['raw_extraction']) ? $payload['raw_extraction'] : null,
        );
    }
}
