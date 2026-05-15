<?php

namespace App\DTOs;

final class PaymentDetailsDTO
{
    public function __construct(
        public readonly string $type,
        public readonly ?string $paybillNo,
        public readonly ?string $accountNo,
        public readonly ?string $tillNo,
        public readonly ?string $merchantName,
        public readonly ?float $amount,
        public readonly string $currency,
        public readonly ?string $phoneNumber,
        public readonly float $confidence,
        public readonly array $missingFields,
        public readonly array $warnings,
    ) {
    }

    /**
     * @param array<string, mixed> $payload
     */
    public static function fromArray(array $payload): self
    {
        return new self(
            type: (string) ($payload['type'] ?? 'paybill'),
            paybillNo: isset($payload['paybill_no']) ? (string) $payload['paybill_no'] : null,
            accountNo: isset($payload['account_no']) ? (string) $payload['account_no'] : null,
            tillNo: isset($payload['till_no']) ? (string) $payload['till_no'] : null,
            merchantName: isset($payload['merchant_name']) ? (string) $payload['merchant_name'] : null,
            amount: isset($payload['amount']) && is_numeric($payload['amount']) ? (float) $payload['amount'] : null,
            currency: (string) ($payload['currency'] ?? 'KES'),
            phoneNumber: isset($payload['phone_number']) ? (string) $payload['phone_number'] : null,
            confidence: (float) ($payload['confidence'] ?? 0),
            missingFields: isset($payload['missing_fields']) && is_array($payload['missing_fields']) ? $payload['missing_fields'] : [],
            warnings: isset($payload['warnings']) && is_array($payload['warnings']) ? $payload['warnings'] : [],
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return [
            'type' => $this->type,
            'paybill_no' => $this->paybillNo,
            'account_no' => $this->accountNo,
            'till_no' => $this->tillNo,
            'merchant_name' => $this->merchantName,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'phone_number' => $this->phoneNumber,
            'confidence' => $this->confidence,
            'missing_fields' => $this->missingFields,
            'warnings' => $this->warnings,
        ];
    }
}
