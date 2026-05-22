class PaymentDetails {
  const PaymentDetails({
    required this.account,
    required this.amount,
    required this.currency,
    required this.phoneNumber,
    required this.confidence,
    required this.missingFields,
    required this.warnings,
  });

  final PaymentAccount account;
  final double? amount;
  final String currency;
  final String? phoneNumber;
  final double confidence;
  final List<String> missingFields;
  final List<String> warnings;

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      account: PaymentAccount.fromJson(
        Map<String, dynamic>.from(json['payment_account'] as Map? ?? {}),
      ),
      amount: (json['amount'] as num?)?.toDouble(),
      currency: (json['currency'] as String?) ?? 'KES',
      phoneNumber: json['phone_number'] as String?,
      confidence: ((json['confidence'] as num?) ?? 0).toDouble(),
      missingFields: _stringList(json['missing_fields']),
      warnings: _stringList(json['warnings']),
    );
  }

  Map<String, dynamic> toJson() => {
        'payment_account': account.toJson(),
        'amount': amount,
        'currency': currency,
        'phone_number': phoneNumber,
        'confidence': confidence,
        'missing_fields': missingFields,
        'warnings': warnings,
      };
}

class PaymentAccount {
  const PaymentAccount({
    required this.type,
    required this.paybillNo,
    required this.accountNo,
    required this.tillNo,
    required this.merchantName,
  });

  final String type;
  final String? paybillNo;
  final String? accountNo;
  final String? tillNo;
  final String? merchantName;

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    return PaymentAccount(
      type: (json['type'] as String?) ?? 'unknown',
      paybillNo: json['paybill_no'] as String?,
      accountNo: json['account_no'] as String?,
      tillNo: json['till_no'] as String?,
      merchantName: json['merchant_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'paybill_no': paybillNo,
        'account_no': accountNo,
        'till_no': tillNo,
        'merchant_name': merchantName,
      };
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value.whereType<Object>().map((item) => item.toString()).toList();
}
