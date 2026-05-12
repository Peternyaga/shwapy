<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Payments\Mpesa\MpesaCallbackService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MpesaCallbackController extends Controller
{
    public function __construct(private readonly MpesaCallbackService $mpesaCallbackService)
    {
    }

    public function store(Request $request): JsonResponse
    {
        $payload = $request->all();
        $checkoutRequestId = data_get($payload, 'Body.stkCallback.CheckoutRequestID');

        if (! is_string($checkoutRequestId) || $checkoutRequestId === '') {
            return response()->json([
                'success' => false,
                'error' => [
                    'message' => 'Invalid callback payload',
                ],
            ], 422);
        }

        $transaction = $this->mpesaCallbackService->handle($payload);

        return response()->json([
            'success' => true,
            'data' => [
                'transaction_id' => $transaction?->id,
                'status' => $transaction?->status,
            ],
        ]);
    }
}
