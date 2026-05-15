<?php

namespace App\Http\Requests\Extractions;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\UploadedFile;

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
            'content' => ['required'],
            'mime_type' => ['nullable', 'string', 'in:image/jpeg,image/png,image/webp,application/pdf'],
            'phone_number' => ['nullable', 'string', 'max:20'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            $type = (string) $this->input('type');
            $content = $this->input('content');

            if ($type === 'text') {
                if (! is_string($content)) {
                    $validator->errors()->add('content', 'Text extraction content must be a string.');

                    return;
                }

                if (mb_strlen($content) > 12000) {
                    $validator->errors()->add('content', 'Text extraction content may not exceed 12,000 characters.');
                }

                return;
            }

            $file = $this->file('content');
            $mimeType = $file instanceof UploadedFile
                ? (string) $file->getMimeType()
                : (string) $this->input('mime_type');

            if ($mimeType === '') {
                $validator->errors()->add('mime_type', 'The mime_type field is required for image and pdf extraction.');

                return;
            }

            if ($type === 'image' && ! in_array($mimeType, ['image/jpeg', 'image/png', 'image/webp'], true)) {
                $validator->errors()->add('mime_type', 'Image extraction supports JPEG, PNG, and WebP files.');
            }

            if ($type === 'pdf' && $mimeType !== 'application/pdf') {
                $validator->errors()->add('mime_type', 'PDF extraction requires application/pdf.');
            }

            $maxBytes = (int) config('services.gemini.max_file_bytes', 3 * 1024 * 1024);

            if ($file instanceof UploadedFile) {
                if (! $file->isValid()) {
                    $validator->errors()->add('content', 'The uploaded file is invalid.');

                    return;
                }

                if ($file->getSize() !== null && $file->getSize() > $maxBytes) {
                    $validator->errors()->add('content', 'File extraction content is too large.');
                }

                return;
            }

            if (! is_string($content)) {
                $validator->errors()->add('content', 'File extraction content must be a base64 string or uploaded file.');

                return;
            }

            $base64 = (string) preg_replace('/^data:[^,]+,/', '', $content);
            $decoded = base64_decode($base64, true);

            if ($decoded === false) {
                $validator->errors()->add('content', 'File extraction content must be valid base64.');

                return;
            }

            if (strlen($decoded) > $maxBytes) {
                $validator->errors()->add('content', 'File extraction content is too large.');
            }
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function extractionPayload(): array
    {
        $payload = $this->validated();
        $file = $this->file('content');

        if ($file instanceof UploadedFile) {
            $payload['content'] = base64_encode((string) file_get_contents($file->getRealPath()));
            $payload['mime_type'] = (string) $file->getMimeType();
        }

        return $payload;
    }
}
