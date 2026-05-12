<?php

namespace App\Services\Payments\Checkout;

use App\DTOs\CheckoutRequestDTO;
use App\Models\User;
use App\Services\Payments\Mpesa\MpesaStkPushService;
use App\Services\Payments\Mpesa\PhoneNumberFormatter;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use RuntimeException;
use Throwable;

class CheckoutService
{
    public function __construct(
        private readonly PaymentAccountResolver $paymentAccountResolver,
        private readonly TransactionRecorder $transactionRecorder,
        private readonly PhoneNumberFormatter $phoneNumberFormatter,
        private readonly MpesaStkPushService $mpesaStkPushService,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function checkout(User $user, CheckoutRequestDTO $request): array
    {
        $phoneNumber = $this->phoneNumberFormatter->normalize($request->phoneNumber);

        $paymentAccount = DB::transaction(function () use ($request, $user) {
            return $this->paymentAccountResolver->resolve($request->paymentAccount, $user->id);
        });

        $transaction = $this->transactionRecorder->createPending(
            $user,
            $paymentAccount,
            $phoneNumber,
            $request->amount,
            $request->extractionConfidence,
            $request->rawExtraction,
        );

        try {
            $stkResponse = $this->mpesaStkPushService->initiate(
                $transaction,
                $paymentAccount,
                $phoneNumber,
                $request->amount,
            );

            if ((string) data_get($stkResponse, 'ResponseCode') !== '0') {
                $this->transactionRecorder->markFailed($transaction, $stkResponse);

                throw new RuntimeException((string) data_get($stkResponse, 'errorMessage', 'STK push rejected.'));
            }

            $transaction = $this->transactionRecorder->markProcessingWithStkIds(
                $transaction,
                (string) data_get($stkResponse, 'MerchantRequestID', ''),
                (string) data_get($stkResponse, 'CheckoutRequestID', ''),
            );

            return [
                'transaction_id' => $transaction->id,
                'status' => $transaction->status,
                'merchant_request_id' => $transaction->merchant_request_id,
                'checkout_request_id' => $transaction->checkout_request_id,
                'message' => (string) data_get($stkResponse, 'CustomerMessage', 'STK request accepted.'),
            ];
        } catch (Throwable $exception) {
            Log::error('Checkout failed.', [
                'transaction_id' => $transaction->id,
                'error' => $exception->getMessage(),
            ]);

            $this->transactionRecorder->markFailed($transaction);

            throw $exception;
        }
    }
}
