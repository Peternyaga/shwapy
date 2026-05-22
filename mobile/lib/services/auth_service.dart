import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../models/session.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<AuthSession> register({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'password': password,
      'password_confirmation': password,
    });

    return _sessionFromResponse(response.data as Map<String, dynamic>);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    return _sessionFromResponse(response.data as Map<String, dynamic>);
  }

  Future<AuthSession> loginWithGoogle({String? phoneNumber}) async {
    final google = GoogleSignIn(
      serverClientId: AppConfig.googleServerClientId.isEmpty
          ? null
          : AppConfig.googleServerClientId,
      scopes: const ['email', 'profile'],
    );
    final account = await google.signIn();
    final auth = await account?.authentication;
    final idToken = auth?.idToken;

    if (idToken == null) {
      throw StateError('Google sign-in was cancelled.');
    }

    final response = await _api.dio.post('/auth/google', data: {
      'id_token': idToken,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phone_number': phoneNumber.trim(),
    });

    return _sessionFromResponse(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _api.dio.post('/auth/logout');
  }

  AuthSession _sessionFromResponse(Map<String, dynamic> json) {
    final data = Map<String, dynamic>.from(json['data'] as Map);

    return AuthSession(
      token: data['token'] as String,
      user: AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
    );
  }
}
