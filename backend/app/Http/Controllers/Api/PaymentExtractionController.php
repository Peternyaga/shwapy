<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Extractions\PaymentExtractionRequest;
use App\Services\Extractions\MockPaymentExtractionService;
use App\Services\Payments\Mpesa\PhoneNumberFormatter;
use Illuminate\Http\JsonResponse;

class PaymentExtractionController extends Controller
{
    public function __construct(
        private readonly MockPaymentExtractionService $mockPaymentExtractionService,
        private readonly PhoneNumberFormatter $phoneNumberFormatter,
    ) {
    }

    public function store(PaymentExtractionRequest $request): JsonResponse
    {
        $payload = $request->validated();
        $details = $this->mockPaymentExtractionService->extract();

        $phoneNumber = isset($payload['phone_number'])
            ? $this->phoneNumberFormatter->normalize((string) $payload['phone_number'])
            : null;

        return response()->json([
            'success' => true,
            'data' => [
                'payment_account' => [
                    'type' => $details->type,
                    'paybill_no' => $details->paybillNo,
                    'account_no' => $details->accountNo,
                    'till_no' => $details->tillNo,
                    'merchant_name' => $details->merchantName,
                ],
                'amount' => $details->amount,
                'phone_number' => $phoneNumber,
                'confidence' => $details->confidence,
            ],
        ]);
    }
}
