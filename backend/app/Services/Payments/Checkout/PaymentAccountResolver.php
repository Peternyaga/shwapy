<?php

namespace App\Services\Payments\Checkout;

use App\Models\PaymentAccount;
use Illuminate\Support\Arr;
use InvalidArgumentException;

class PaymentAccountResolver
{
    /**
     * @param array<string, mixed> $payload
     */
    public function resolve(array $payload, int $userId): PaymentAccount
    {
        $type = (string) Arr::get($payload, 'type');

        if (! in_array($type, ['paybill', 'till'], true)) {
            throw new InvalidArgumentException('Invalid payment account type.');
        }

        if ($type === 'paybill') {
            $paybillNo = trim((string) Arr::get($payload, 'paybill_no'));
            $accountNo = trim((string) Arr::get($payload, 'account_no'));

            if ($paybillNo === '' || $accountNo === '') {
                throw new InvalidArgumentException('Paybill details are incomplete.');
            }

            return PaymentAccount::updateOrCreate(
                ['paybill_no' => $paybillNo, 'account_no' => $accountNo],
                [
                    'type' => 'paybill',
                    'till_no' => null,
                    'merchant_name' => Arr::get($payload, 'merchant_name'),
                    'created_by_user_id' => $userId,
                    'last_used_at' => now(),
                ]
            );
        }

        $tillNo = trim((string) Arr::get($payload, 'till_no'));

        if ($tillNo === '') {
            throw new InvalidArgumentException('Till number is required for till payments.');
        }

        return PaymentAccount::updateOrCreate(
            ['till_no' => $tillNo],
            [
                'type' => 'till',
                'paybill_no' => null,
                'account_no' => null,
                'merchant_name' => Arr::get($payload, 'merchant_name'),
                'created_by_user_id' => $userId,
                'last_used_at' => now(),
            ]
        );
    }
}
