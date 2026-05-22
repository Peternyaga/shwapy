# Shwapy Mobile App

## Runtime Configuration

Pass these values with `--dart-define` for local and release builds:

```bash
flutter run \
  --dart-define=SHWAPY_API_BASE_URL=https://api.example.com/api \
  --dart-define=SHWAPY_CLIENT_ENCRYPTION_SECRET=replace-with-mobile-secret \
  --dart-define=SHWAPY_GOOGLE_SERVER_CLIENT_ID=replace-with-google-web-client-id
```

The backend must use the same `GEMINI_MOBILE_ENCRYPTION_SECRET` value as
`SHWAPY_CLIENT_ENCRYPTION_SECRET`.

## Backend Environment

Configure:

```bash
GEMINI_API_KEY=
GEMINI_MODEL=gemini-2.5-flash
GEMINI_MOBILE_KEY_TTL=600
GEMINI_MOBILE_ENCRYPTION_SECRET=
GOOGLE_CLIENT_IDS=ios-client-id,android-client-id,web-client-id
```

## Native App Setup

After installing Flutter, generate the platform wrappers from `mobile`:

```bash
flutter create --platforms=android,ios .
flutter pub get
```

Then configure:

- Android package id and signing config.
- iOS bundle id, signing team, and release capabilities.
- Camera permission strings:
  - Android `CAMERA`.
  - iOS `NSCameraUsageDescription`.
- Google sign-in client ids for Android and iOS.

Do not commit provider API keys or release signing secrets into the app.
