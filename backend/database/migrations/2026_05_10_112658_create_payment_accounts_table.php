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
        Schema::create('payment_accounts', function (Blueprint $table) {
            $table->id();
            $table->enum('type', ['paybill', 'till']);
            $table->string('paybill_no')->nullable();
            $table->string('account_no')->nullable();
            $table->string('till_no')->nullable()->unique();
            $table->string('merchant_name')->nullable();
            $table->foreignId('created_by_user_id')->constrained('users');
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->unique(['paybill_no', 'account_no']);
            $table->index('type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payment_accounts');
    }
};
