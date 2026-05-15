<?php

namespace App\Providers;

use App\Services\Extractions\GeminiPaymentExtractionService;
use App\Services\Extractions\MockPaymentExtractionService;
use App\Services\Extractions\PaymentExtractionService;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(PaymentExtractionService::class, function ($app) {
            if (config('services.gemini.api_key') === null || config('services.gemini.api_key') === '') {
                return $app->make(MockPaymentExtractionService::class);
            }

            return $app->make(GeminiPaymentExtractionService::class);
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
