<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users');
            $table->foreignId('payment_account_id')->constrained('payment_accounts');
            $table->string('merchant_request_id')->nullable();
            $table->string('checkout_request_id')->nullable()->unique();
            $table->string('transaction_type');
            $table->string('phone_number', 12);
            $table->decimal('amount', 12, 2);
            $table->enum('status', ['pending', 'processing', 'success', 'failed', 'cancelled', 'timeout'])
                ->default('pending');
            $table->decimal('extraction_confidence', 5, 4)->nullable();
            $table->json('raw_extraction')->nullable();
            $table->json('raw_callback')->nullable();
            $table->timestamps();

            $table->index('merchant_request_id');
            $table->index('status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
