<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TransactionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $transactions = Transaction::query()
            ->with('paymentAccount')
            ->where('user_id', $request->user()->id)
            ->latest()
            ->limit(50)
            ->get()
            ->map(fn (Transaction $transaction): array => $this->serialize($transaction));

        return response()->json([
            'success' => true,
            'data' => $transactions,
        ]);
    }

    public function show(Request $request, Transaction $transaction): JsonResponse
    {
        abort_unless($transaction->user_id === $request->user()->id, 404);

        return response()->json([
            'success' => true,
            'data' => $this->serialize($transaction->load('paymentAccount')),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function serialize(Transaction $transaction): array
    {
        $account = $transaction->paymentAccount;

        return [
            'id' => $transaction->id,
            'status' => $transaction->status,
            'amount' => (float) $transaction->amount,
            'currency' => 'KES',
            'phone_number' => $transaction->phone_number,
            'merchant_request_id' => $transaction->merchant_request_id,
            'checkout_request_id' => $transaction->checkout_request_id,
            'result_description' => data_get($transaction->raw_callback, 'Body.stkCallback.ResultDesc'),
            'payment_account' => [
                'type' => $account?->type,
                'paybill_no' => $account?->paybill_no,
                'account_no' => $account?->account_no,
                'till_no' => $account?->till_no,
                'merchant_name' => $account?->merchant_name,
            ],
            'created_at' => $transaction->created_at?->toIso8601String(),
            'updated_at' => $transaction->updated_at?->toIso8601String(),
        ];
    }
}
