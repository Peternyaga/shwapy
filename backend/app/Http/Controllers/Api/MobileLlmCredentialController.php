<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Security\MobileLlmCredentialService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Throwable;

class MobileLlmCredentialController extends Controller
{
    public function __construct(private readonly MobileLlmCredentialService $credentialService)
    {
    }

    public function show(Request $request): JsonResponse
    {
        $request->validate([
            'device_id' => ['required', 'string', 'min:16', 'max:128'],
        ]);

        $user = $request->user();

        if (! $user) {
            return response()->json([
                'success' => false,
                'error' => ['message' => 'Unauthenticated.'],
            ], 401);
        }

        try {
            $token = $user->currentAccessToken();
            $tokenId = $token instanceof PersonalAccessToken ? $token->id : null;

            return response()->json([
                'success' => true,
                'data' => $this->credentialService->issue(
                    $user,
                    (string) $request->string('device_id'),
                    $tokenId
                ),
            ]);
        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'success' => false,
                'error' => ['message' => $exception->getMessage()],
            ], 422);
        }
    }
}
