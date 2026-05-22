import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/payment_details.dart';
import '../models/session.dart';
import 'api_client.dart';
import 'image_processor.dart';
import 'mobile_llm_key_service.dart';

class GeminiExtractionService {
  GeminiExtractionService(this._api, this._keyService);

  final ApiClient _api;
  final MobileLlmKeyService _keyService;

  Future<PaymentDetails> extractImage({
    required AuthSession session,
    required PreparedImage image,
    String? phoneNumber,
  }) async {
    try {
      final credential = await _keyService.credential(session);
      final response = await Dio(
        BaseOptions(
          baseUrl: credential.baseUrl,
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 8),
          headers: {
            'Accept': 'application/json',
            'x-goog-api-key': credential.apiKey,
          },
        ),
      ).post(
        '/models/${credential.model}:generateContent',
        data: _geminiPayload(image, phoneNumber),
      );

      return _detailsFromGemini(response.data);
    } catch (_) {
      return _extractViaBackend(image, phoneNumber);
    }
  }

  Future<PaymentDetails> extractText({
    required AuthSession session,
    required String content,
    String? phoneNumber,
  }) async {
    final response = await _api.dio.post('/extractions/payment', data: {
      'type': 'text',
      'content': content,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phone_number': phoneNumber.trim(),
    });

    return PaymentDetails.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Map<String, Object?> _geminiPayload(
      PreparedImage image, String? phoneNumber) {
    return {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {
                'mime_type': image.mimeType,
                'data': image.base64,
              },
            },
            if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
              {'text': 'User-provided payer phone number hint: $phoneNumber'},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'maxOutputTokens': 1024,
        'responseMimeType': 'application/json',
      },
    };
  }

  PaymentDetails _detailsFromGemini(Object? response) {
    final map = Map<String, dynamic>.from(response as Map);
    final parts = map['candidates']?[0]?['content']?['parts'] as List?;
    final text = parts
            ?.whereType<Map>()
            .map((part) => part['text']?.toString() ?? '')
            .join()
            .trim() ??
        '';
    final decoded = jsonDecode(_jsonObject(text)) as Map<String, dynamic>;

    return PaymentDetails.fromJson(decoded);
  }

  Future<PaymentDetails> _extractViaBackend(
    PreparedImage image,
    String? phoneNumber,
  ) async {
    final response = await _api.dio.post('/extractions/payment', data: {
      'type': 'image',
      'mime_type': image.mimeType,
      'content': image.base64,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phone_number': phoneNumber.trim(),
    });

    return PaymentDetails.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  String _jsonObject(String value) {
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('Gemini response did not contain JSON.');
    }

    return value.substring(start, end + 1);
  }
}

const _prompt = '''
Extract Kenyan M-Pesa payment details from the provided image.

Return only fields that are explicitly visible or explicitly stated. Do not guess or infer missing paybill numbers, till numbers, account numbers, merchant names, phone numbers, or amounts.

Return one compact JSON object only:
{
  "payment_account": {
    "type": "paybill|till|unknown",
    "paybill_no": "string or null",
    "account_no": "string or null",
    "till_no": "string or null",
    "merchant_name": "string or null"
  },
  "amount": 123 or null,
  "currency": "KES",
  "phone_number": "string or null",
  "confidence": 0.0,
  "missing_fields": ["field_name"],
  "warnings": ["short warning"]
}

Use KES unless another currency is explicitly shown. Keep numeric identifiers as strings. For labels such as BUY GOODS, TILL NO, TILL NUMBER, or LIPA NA M-PESA BUY GOODS, classify as till and extract the nearby digits as till_no.
''';
