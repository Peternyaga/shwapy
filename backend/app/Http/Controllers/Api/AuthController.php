<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\GoogleLoginRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Models\User;
use App\Services\Auth\GoogleIdentityService;
use App\Services\Payments\Mpesa\PhoneNumberFormatter;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Throwable;

class AuthController extends Controller
{
    public function __construct(private readonly PhoneNumberFormatter $phoneNumberFormatter)
    {
    }

    public function register(RegisterRequest $request): JsonResponse
    {
        $payload = $request->validated();

        $user = User::create([
            'name' => $payload['name'],
            'email' => $payload['email'],
            'phone_number' => $this->phoneNumberFormatter->normalize($payload['phone_number']),
            'password' => Hash::make($payload['password']),
        ]);

        $token = $user->createToken('auth-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'data' => [
                'token' => $token,
                'user' => $user,
            ],
        ], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $payload = $request->validated();

        $user = User::where('email', $payload['email'])->first();

        if (! $user || ! Hash::check($payload['password'], $user->password)) {
            return response()->json([
                'success' => false,
                'error' => [
                    'message' => 'Invalid credentials',
                ],
            ], 401);
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'data' => [
                'token' => $token,
                'user' => $user,
            ],
        ]);
    }

    public function google(GoogleLoginRequest $request, GoogleIdentityService $googleIdentityService): JsonResponse
    {
        try {
            $identity = $googleIdentityService->verify($request->validated('id_token'));
        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'success' => false,
                'error' => [
                    'message' => $exception->getMessage(),
                ],
            ], 401);
        }

        $user = User::where('google_id', $identity['sub'])
            ->orWhere('email', $identity['email'])
            ->first();

        if (! $user) {
            $phoneNumber = $request->validated('phone_number');

            if (! is_string($phoneNumber) || trim($phoneNumber) === '') {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'message' => 'Phone number is required for first-time Google signup.',
                    ],
                ], 422);
            }

            try {
                $user = User::create([
                    'name' => $identity['name'],
                    'email' => $identity['email'],
                    'phone_number' => $this->phoneNumberFormatter->normalize($phoneNumber),
                    'google_id' => $identity['sub'],
                    'avatar_url' => $identity['picture'],
                    'email_verified_at' => now(),
                    'password' => Hash::make(Str::random(48)),
                ]);
            } catch (QueryException) {
                return response()->json([
                    'success' => false,
                    'error' => [
                        'message' => 'A user with those details already exists.',
                    ],
                ], 422);
            }
        } else {
            $user->forceFill([
                'google_id' => $user->google_id ?: $identity['sub'],
                'avatar_url' => $identity['picture'] ?: $user->avatar_url,
                'email_verified_at' => $user->email_verified_at ?: now(),
            ])->save();
        }

        $token = $user->createToken('auth-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'data' => [
                'token' => $token,
                'user' => $user,
            ],
        ]);
    }

    public function logout(): JsonResponse
    {
        $user = request()->user();

        if ($user) {
            $user->currentAccessToken()?->delete();
        }

        return response()->json([
            'success' => true,
            'data' => [
                'message' => 'Logged out successfully',
            ],
        ]);
    }
}
