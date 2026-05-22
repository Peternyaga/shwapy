class AppConfig {
  static const backendBaseUrl = String.fromEnvironment(
    'SHWAPY_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static const clientEncryptionSecret = String.fromEnvironment(
    'SHWAPY_CLIENT_ENCRYPTION_SECRET',
    defaultValue: '',
  );

  static const googleServerClientId = String.fromEnvironment(
    'SHWAPY_GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
}
