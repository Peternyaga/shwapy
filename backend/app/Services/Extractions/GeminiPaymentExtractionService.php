<?php

namespace App\Services\Extractions;

use App\DTOs\PaymentDetailsDTO;
use App\Services\Payments\Mpesa\PhoneNumberFormatter;
use Illuminate\Support\Facades\Http;
use InvalidArgumentException;
use RuntimeException;

class GeminiPaymentExtractionService implements PaymentExtractionService
{
    private const MAX_OUTPUT_TOKENS = 2048;

    public function __construct(private readonly PhoneNumberFormatter $phoneNumberFormatter)
    {
    }

    /**
     * @param array<string, mixed> $payload
     */
    public function extract(array $payload): PaymentDetailsDTO
    {
        $apiKey = (string) config('services.gemini.api_key');

        if ($apiKey === '') {
            throw new RuntimeException('Gemini API key is not configured.');
        }

        $timeout = $payload['type'] === 'text'
            ? (int) config('services.gemini.timeout', 8)
            : (int) config('services.gemini.file_timeout', 15);

        $client = Http::timeout($timeout)
            ->connectTimeout((int) config('services.gemini.connect_timeout', 2))
            ->retry(1, 150)
            ->withHeaders([
                'x-goog-api-key' => $apiKey,
            ])
            ->acceptJson();

        $response = $client->post($this->endpoint(), $this->buildRequest($payload));

        if (! $response->successful()) {
            throw new RuntimeException('Gemini extraction failed: '.json_encode([
                'status' => $response->status(),
                'body' => $response->json() ?? $response->body(),
            ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
        }

        $text = $this->candidateText($response->json());

        if (data_get($response->json(), 'candidates.0.finishReason') === 'MAX_TOKENS') {
            throw new RuntimeException('Gemini extraction response was truncated at the output token limit.');
        }

        if ($text === '') {
            throw new RuntimeException('Gemini extraction response was empty.');
        }

        $decoded = $this->decodeJsonObject($text);

        return $this->toPaymentDetails($decoded, $payload);
    }

    private function endpoint(): string
    {
        $baseUrl = rtrim((string) config('services.gemini.base_url'), '/');
        $model = (string) config('services.gemini.model', 'gemini-2.5-flash');

        return $baseUrl.'/models/'.$model.':generateContent';
    }

    /**
     * @param array<string, mixed> $payload
     *
     * @return array<string, mixed>
     */
    private function buildRequest(array $payload): array
    {
        $type = (string) $payload['type'];
        $parts = [
            ['text' => $this->prompt()],
        ];

        if ($type === 'text') {
            $parts[] = ['text' => (string) $payload['content']];
        } else {
            $parts[] = [
                'inline_data' => [
                    'mime_type' => (string) $payload['mime_type'],
                    'data' => $this->base64Content((string) $payload['content']),
                ],
            ];
        }

        if (isset($payload['phone_number'])) {
            $parts[] = ['text' => 'User-provided payer phone number hint: '.$payload['phone_number']];
        }

        return [
            'contents' => [
                [
                    'role' => 'user',
                    'parts' => $parts,
                ],
            ],
            'generationConfig' => [
                'temperature' => 0,
                'maxOutputTokens' => self::MAX_OUTPUT_TOKENS,
                'thinkingConfig' => [
                    'thinkingBudget' => 0,
                ],
                'responseMimeType' => 'application/json',
                'responseSchema' => $this->schema(),
            ],
        ];
    }

    private function prompt(): string
    {
        return <<<'PROMPT'
Extract Kenyan M-Pesa payment details from the provided content.

Return only fields that are explicitly visible or explicitly stated. Do not guess or infer missing paybill numbers, till numbers, account numbers, merchant names, phone numbers, or amounts.

Return a single JSON object only. Do not wrap it in markdown or include explanatory text.

Use exactly this compact JSON shape:
{
  "payment_account": {
    "type": "paybill|till|unknown",
    "paybill_no": "string or null",
    "account_no": "string or null",
    "till_no": "string or null",
    "merchant_name": "string or null"
  },
  "amount": 123 or null,
  "currency": "KES",
  "phone_number": "string or null",
  "confidence": 0.0,
  "missing_fields": ["field_name"],
  "warnings": ["short warning"]
}

The confidence field must be one number from 0 to 1. Do not return per-field confidence objects.

If the amount is not available, return amount as null and include "amount" in missing_fields. Extraction is allowed to be incomplete.

Classify payment_account.type as:
- "paybill" only when a paybill/business number is present or clearly labeled.
- "till" only when a till/buy goods number is present or clearly labeled.
- "unknown" when the destination account type is unclear.

For Kenyan shop signs, text such as "BUY GOODS", "TILL NO", "TILL NUMBER", or "LIPA NA M-PESA BUY GOODS" usually indicates a till payment. If digits are printed beside or under a "TILL NO" label, extract those digits as till_no exactly as shown, even when they start with 0. Do not treat a clearly labeled till number as a payer phone number.

If an account or merchant name appears in a nearby field labeled "ACCOUNT NAME", "NAME", "BUSINESS NAME", or similar, extract it as merchant_name.

Use KES as currency unless the content explicitly says otherwise. Keep numeric identifiers as strings. Confidence must reflect extraction certainty.
PROMPT;
    }

    /**
     * @return array<string, mixed>
     */
    private function schema(): array
    {
        return [
            'type' => 'object',
            'properties' => [
                'payment_account' => [
                    'type' => 'object',
                    'properties' => [
                        'type' => [
                            'type' => 'string',
                            'enum' => ['paybill', 'till', 'unknown'],
                            'description' => 'Destination account type.',
                        ],
                        'paybill_no' => [
                            'type' => 'string',
                            'nullable' => true,
                            'description' => 'Paybill/business number, only when explicitly present.',
                        ],
                        'account_no' => [
                            'type' => 'string',
                            'nullable' => true,
                            'description' => 'Paybill account/reference number, only when explicitly present.',
                        ],
                        'till_no' => [
                            'type' => 'string',
                            'nullable' => true,
                            'description' => 'Till number, only when explicitly present.',
                        ],
                        'merchant_name' => [
                            'type' => 'string',
                            'nullable' => true,
                            'description' => 'Merchant or payee name, only when explicitly present.',
                        ],
                    ],
                    'required' => ['type', 'paybill_no', 'account_no', 'till_no', 'merchant_name'],
                ],
                'amount' => [
                    'type' => 'number',
                    'nullable' => true,
                    'description' => 'Payment amount. Null when not explicitly available.',
                ],
                'currency' => [
                    'type' => 'string',
                    'description' => 'Currency code, usually KES.',
                ],
                'phone_number' => [
                    'type' => 'string',
                    'nullable' => true,
                    'description' => 'Payer phone number, only when explicitly available or supplied by the user.',
                ],
                'confidence' => [
                    'type' => 'number',
                    'minimum' => 0,
                    'maximum' => 1,
                    'description' => 'Overall extraction confidence from 0 to 1.',
                ],
                'missing_fields' => [
                    'type' => 'array',
                    'items' => ['type' => 'string'],
                    'description' => 'Important fields that were absent or unclear.',
                ],
                'warnings' => [
                    'type' => 'array',
                    'items' => ['type' => 'string'],
                    'description' => 'Ambiguities, conflicts, or safety notes.',
                ],
            ],
            'required' => ['payment_account', 'amount', 'currency', 'phone_number', 'confidence', 'missing_fields', 'warnings'],
        ];
    }

    private function base64Content(string $content): string
    {
        if (str_contains($content, ',')) {
            return (string) preg_replace('/^data:[^,]+,/', '', $content);
        }

        return $content;
    }

    private function candidateText(mixed $response): string
    {
        $parts = data_get($response, 'candidates.0.content.parts', []);

        if (! is_array($parts)) {
            return '';
        }

        return trim(implode('', array_map(
            fn (mixed $part): string => is_array($part) ? (string) ($part['text'] ?? '') : '',
            $parts
        )));
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJsonObject(string $text): array
    {
        $cleaned = trim($text);
        $cleaned = (string) preg_replace('/^```(?:json)?\s*/i', '', $cleaned);
        $cleaned = (string) preg_replace('/\s*```$/', '', $cleaned);

        $decoded = json_decode($cleaned, true);

        if (is_array($decoded)) {
            return $decoded;
        }

        $start = strpos($cleaned, '{');
        $end = strrpos($cleaned, '}');

        if ($start !== false && $end !== false && $end > $start) {
            $decoded = json_decode(substr($cleaned, $start, $end - $start + 1), true);

            if (is_array($decoded)) {
                return $decoded;
            }
        }

        throw new RuntimeException('Gemini extraction response was not valid JSON. Excerpt: '.mb_substr($cleaned, 0, 500));
    }

    /**
     * @param array<string, mixed> $decoded
     * @param array<string, mixed> $requestPayload
     */
    private function toPaymentDetails(array $decoded, array $requestPayload): PaymentDetailsDTO
    {
        $paymentAccount = is_array($decoded['payment_account'] ?? null) ? $decoded['payment_account'] : [];
        $missingFields = $this->stringList($decoded['missing_fields'] ?? []);
        $warnings = $this->stringList($decoded['warnings'] ?? []);

        $phoneNumber = $requestPayload['phone_number'] ?? ($decoded['phone_number'] ?? null);

        if (is_string($phoneNumber) && $phoneNumber !== '') {
            try {
                $phoneNumber = $this->phoneNumberFormatter->normalize($phoneNumber);
            } catch (InvalidArgumentException $exception) {
                $warnings[] = $exception->getMessage();
                $phoneNumber = null;
            }
        } else {
            $phoneNumber = null;
        }

        $type = $this->safeType($paymentAccount['type'] ?? 'unknown');

        $paybillNo = $this->nullableString($paymentAccount['paybill_no'] ?? null);
        $accountNo = $this->nullableString($paymentAccount['account_no'] ?? null);
        $tillNo = $this->nullableString($paymentAccount['till_no'] ?? null);

        if ($type === 'paybill') {
            if ($paybillNo === null) {
                $missingFields[] = 'paybill_no';
            }

            if ($accountNo === null) {
                $missingFields[] = 'account_no';
            }
        }

        if ($type === 'till' && $tillNo === null) {
            $missingFields[] = 'till_no';
        }

        if (! isset($decoded['amount']) || ! is_numeric($decoded['amount'])) {
            $missingFields[] = 'amount';
            $amount = null;
        } else {
            $amount = max(0, (float) $decoded['amount']);
        }

        $confidence = $decoded['confidence'] ?? 0;
        $confidence = is_numeric($confidence) ? (float) $confidence : 0;

        return PaymentDetailsDTO::fromArray([
            'type' => $type,
            'paybill_no' => $paybillNo,
            'account_no' => $accountNo,
            'till_no' => $tillNo,
            'merchant_name' => $this->nullableString($paymentAccount['merchant_name'] ?? ($decoded['merchant_name'] ?? null)),
            'amount' => $amount,
            'currency' => strtoupper((string) ($decoded['currency'] ?? 'KES')),
            'phone_number' => $phoneNumber,
            'confidence' => min(1, max(0, $confidence)),
            'missing_fields' => $this->relevantMissingFields(array_values(array_unique($missingFields)), $type),
            'warnings' => array_values(array_unique($warnings)),
        ]);
    }

    private function safeType(mixed $type): string
    {
        $type = is_string($type) ? $type : 'unknown';

        return in_array($type, ['paybill', 'till', 'unknown'], true) ? $type : 'unknown';
    }

    private function nullableString(mixed $value): ?string
    {
        if (! is_string($value) && ! is_numeric($value)) {
            return null;
        }

        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }

    /**
     * @param array<int, string> $missingFields
     *
     * @return array<int, string>
     */
    private function relevantMissingFields(array $missingFields, string $type): array
    {
        $irrelevant = match ($type) {
            'paybill' => ['till_no'],
            'till' => ['paybill_no', 'account_no'],
            default => [],
        };

        return array_values(array_diff($missingFields, $irrelevant));
    }

    /**
     * @return array<int, string>
     */
    private function stringList(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        return array_values(array_filter(array_map(
            fn (mixed $item): string => trim((string) $item),
            $value
        )));
    }
}
