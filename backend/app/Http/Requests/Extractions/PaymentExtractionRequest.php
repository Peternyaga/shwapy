<?php

namespace App\Http\Requests\Extractions;

use Illuminate\Foundation\Http\FormRequest;

class PaymentExtractionRequest extends FormRequest
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
            'type' => ['required', 'in:image,text,pdf'],
            'content' => ['nullable', 'string'],
            'phone_number' => ['nullable', 'string', 'max:20'],
        ];
    }
}
