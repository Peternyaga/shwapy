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
        public readonly float $amount,
        public readonly float $confidence,
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
            amount: (float) ($payload['amount'] ?? 0),
            confidence: (float) ($payload['confidence'] ?? 0),
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
            'confidence' => $this->confidence,
        ];
    }
}
