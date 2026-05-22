import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

class SecureSessionStore {
  SecureSessionStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _token = 'auth_token';
  static const _userId = 'user_id';
  static const _name = 'user_name';
  static const _email = 'user_email';
  static const _phone = 'user_phone';
  static const _deviceId = 'device_id';

  Future<AuthSession?> load() async {
    final token = await _storage.read(key: _token);
    final id = int.tryParse((await _storage.read(key: _userId)) ?? '');
    final name = await _storage.read(key: _name);
    final email = await _storage.read(key: _email);

    if (token == null || id == null || name == null || email == null) {
      return null;
    }

    return AuthSession(
      token: token,
      user: AuthUser(
        id: id,
        name: name,
        email: email,
        phoneNumber: await _storage.read(key: _phone),
      ),
    );
  }

  Future<void> save(AuthSession session) async {
    await _storage.write(key: _token, value: session.token);
    await _storage.write(key: _userId, value: session.user.id.toString());
    await _storage.write(key: _name, value: session.user.name);
    await _storage.write(key: _email, value: session.user.email);
    await _storage.write(key: _phone, value: session.user.phoneNumber ?? '');
  }

  Future<void> clear() async {
    final deviceId = await deviceId();
    await _storage.deleteAll();
    await _storage.write(key: _deviceId, value: deviceId);
  }

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceId);
    if (existing != null && existing.length >= 16) {
      return existing;
    }

    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final value = List.generate(
      32,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    await _storage.write(key: _deviceId, value: value);

    return value;
  }
}
