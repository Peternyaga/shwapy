<?php

namespace App\Http\Requests\Payments;

use Illuminate\Foundation\Http\FormRequest;

class CheckoutStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'payment_account' => ['required', 'array'],
            'payment_account.type' => ['required', 'in:paybill,till'],
            'payment_account.paybill_no' => ['nullable', 'string', 'regex:/^\d{5,10}$/'],
            'payment_account.account_no' => ['nullable', 'string', 'max:50'],
            'payment_account.till_no' => ['nullable', 'string', 'regex:/^\d{5,10}$/'],
            'payment_account.merchant_name' => ['nullable', 'string', 'max:255'],
            'amount' => ['required', 'numeric', 'min:1'],
            'phone_number' => ['required', 'string', 'regex:/^\+?\d{9,13}$/'],
            'extraction_confidence' => ['nullable', 'numeric', 'min:0', 'max:1'],
            'raw_extraction' => ['nullable', 'array'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            /** @var string $type */
            $type = (string) data_get($this->input('payment_account'), 'type');

            if ($type === 'paybill') {
                if (! data_get($this->input('payment_account'), 'paybill_no') || ! data_get($this->input('payment_account'), 'account_no')) {
                    $validator->errors()->add('payment_account', 'Paybill payments require paybill_no and account_no.');
                }
            }

            if ($type === 'till' && ! data_get($this->input('payment_account'), 'till_no')) {
                $validator->errors()->add('payment_account', 'Till payments require till_no.');
            }
        });
    }
}
