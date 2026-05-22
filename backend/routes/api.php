<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\MobileLlmCredentialController;
use App\Http\Controllers\Api\MpesaCallbackController;
use App\Http\Controllers\Api\PaymentExtractionController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function (): void {
    Route::post('register', [AuthController::class, 'register']);
    Route::post('login', [AuthController::class, 'login']);
    Route::post('google', [AuthController::class, 'google']);

    Route::middleware('auth:sanctum')->post('logout', [AuthController::class, 'logout']);
});

Route::middleware('auth:sanctum')->group(function (): void {
    Route::post('extractions/payment', [PaymentExtractionController::class, 'store']);
    Route::get('llm/session-key', [MobileLlmCredentialController::class, 'show'])
        ->middleware('throttle:30,1');
    Route::post('payments/checkout', [CheckoutController::class, 'store']);
});

Route::post('payments/callback', [MpesaCallbackController::class, 'store']);
