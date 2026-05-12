<?php

namespace App\Http\Controllers\Api;

use App\DTOs\CheckoutRequestDTO;
use App\Http\Controllers\Controller;
use App\Http\Requests\Payments\CheckoutStoreRequest;
use App\Services\Payments\Checkout\CheckoutService;
use Illuminate\Http\JsonResponse;
use Throwable;

class CheckoutController extends Controller
{
    public function __construct(private readonly CheckoutService $checkoutService)
    {
    }

    public function store(CheckoutStoreRequest $request): JsonResponse
    {
        try {
            $result = $this->checkoutService->checkout(
                $request->user(),
                CheckoutRequestDTO::fromArray($request->validated())
            );

            return response()->json([
                'success' => true,
                'data' => $result,
            ]);
        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'success' => false,
                'error' => [
                    'message' => $exception->getMessage(),
                ],
            ], 422);
        }
    }
}
