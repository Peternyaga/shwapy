<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Extractions\PaymentExtractionRequest;
use App\Services\Extractions\PaymentExtractionService;
use Illuminate\Http\JsonResponse;
use Throwable;

class PaymentExtractionController extends Controller
{
    public function __construct(private readonly PaymentExtractionService $paymentExtractionService)
    {
    }

    public function store(PaymentExtractionRequest $request): JsonResponse
    {
        try {
            $details = $this->paymentExtractionService->extract($request->extractionPayload());
        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'success' => false,
                'error' => [
                    'message' => $exception->getMessage(),
                ],
            ], 422);
        }

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
                'currency' => $details->currency,
                'phone_number' => $details->phoneNumber,
                'confidence' => $details->confidence,
                'missing_fields' => $details->missingFields,
                'warnings' => $details->warnings,
            ],
        ]);
    }
}
