<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transaction extends Model
{
    use HasFactory;

    public const STATUS_PENDING = 'pending';
    public const STATUS_PROCESSING = 'processing';
    public const STATUS_SUCCESS = 'success';
    public const STATUS_FAILED = 'failed';
    public const STATUS_CANCELLED = 'cancelled';
    public const STATUS_TIMEOUT = 'timeout';

    /**
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'payment_account_id',
        'merchant_request_id',
        'checkout_request_id',
        'transaction_type',
        'phone_number',
        'amount',
        'status',
        'extraction_confidence',
        'raw_extraction',
        'raw_callback',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'extraction_confidence' => 'decimal:4',
            'raw_extraction' => 'array',
            'raw_callback' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function paymentAccount(): BelongsTo
    {
        return $this->belongsTo(PaymentAccount::class);
    }
}
