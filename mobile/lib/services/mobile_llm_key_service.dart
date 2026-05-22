import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../models/session.dart';
import 'api_client.dart';
import 'secure_session_store.dart';

class MobileLlmCredential {
  const MobileLlmCredential({
    required this.apiKey,
    required this.model,
    required this.baseUrl,
    required this.expiresAtUnix,
  });

  final String apiKey;
  final String model;
  final String baseUrl;
  final int expiresAtUnix;

  bool get isFresh {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAtUnix - now > 45;
  }
}

class MobileLlmKeyService {
  MobileLlmKeyService(this._api, this._store);

  final ApiClient _api;
  final SecureSessionStore _store;
  MobileLlmCredential? _cached;

  Future<MobileLlmCredential> credential(AuthSession session) async {
    final cached = _cached;
    if (cached != null && cached.isFresh) {
      return cached;
    }

    if (AppConfig.clientEncryptionSecret.isEmpty) {
      throw StateError('Mobile key encryption secret is not configured.');
    }

    final deviceId = await _store.deviceId();
    final response = await _api.dio.get('/llm/session-key', queryParameters: {
      'device_id': deviceId,
    });
    final data = Map<String, dynamic>.from(response.data['data'] as Map);
    final expiresAtUnix = data['expires_at_unix'] as int;
    final keyId = data['key_id'] as String;
    final tokenId = session.tokenId;
    final secretKey = await _secretKey(
      session: session,
      deviceId: deviceId,
      expiresAtUnix: expiresAtUnix,
      tokenId: tokenId,
    );
    final aad = utf8.encode([
      'shwapy-mobile-llm-key-v1',
      session.user.id,
      deviceId,
      expiresAtUnix,
      tokenId ?? 'transient',
      keyId,
    ].join('|'));
    final clearBytes = await AesGcm.with256bits().decrypt(
      SecretBox(
        base64Decode(data['encrypted_key'] as String),
        nonce: base64Decode(data['nonce'] as String),
        mac: Mac(base64Decode(data['tag'] as String)),
      ),
      secretKey: secretKey,
      aad: aad,
    );

    _cached = MobileLlmCredential(
      apiKey: utf8.decode(clearBytes),
      model: data['model'] as String,
      baseUrl: data['base_url'] as String,
      expiresAtUnix: expiresAtUnix,
    );

    return _cached!;
  }

  void clear() {
    _cached = null;
  }

  Future<SecretKey> _secretKey({
    required AuthSession session,
    required String deviceId,
    required int expiresAtUnix,
    required int? tokenId,
  }) async {
    final material = [
      AppConfig.clientEncryptionSecret,
      session.user.id,
      session.user.email,
      deviceId,
      expiresAtUnix,
      tokenId ?? 'transient',
    ].join('|');
    final digest = sha256.convert(utf8.encode(material));

    return SecretKey(digest.bytes);
  }
}
