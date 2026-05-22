import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.backendBaseUrl,
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 12),
            sendTimeout: const Duration(seconds: 12),
            headers: {'Accept': 'application/json'},
          ),
        );

  final Dio dio;

  void setToken(String? token) {
    if (token == null) {
      dio.options.headers.remove('Authorization');
      return;
    }

    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  String messageFor(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        return (data['error']['message'] as String?) ?? 'Request failed.';
      }

      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    }

    return 'Network request failed.';
  }
}
