<?php

namespace App\Services\Payments\Mpesa;

use InvalidArgumentException;

class PhoneNumberFormatter
{
    public function normalize(string $phoneNumber): string
    {
        $digits = preg_replace('/\D+/', '', $phoneNumber) ?? '';

        if (str_starts_with($digits, '0')) {
            $digits = '254'.substr($digits, 1);
        } elseif (str_starts_with($digits, '7')) {
            $digits = '254'.$digits;
        }

        if (! preg_match('/^2547\d{8}$/', $digits)) {
            throw new InvalidArgumentException('Invalid phone number format. Use a valid Kenyan mobile number.');
        }

        return $digits;
    }
}
