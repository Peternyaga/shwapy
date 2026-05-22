# Shwapy Agent Guide

## Repo Map

- `backend/`: Laravel 12 API for auth, payment extraction, checkout, M-Pesa callbacks, and mobile LLM session credentials.
- `mobile/`: Flutter app source. Platform wrappers may need to be generated with `flutter create --platforms=android,ios .` from this directory.
- `web/`: React/Vite web client for the current extraction and checkout flows.
- `docs/`: Architecture, setup notes, MVP planning, and mobile release/config guidance.

## Required Global Tooling

Install these so commands work from any shell:

- Git
- Node.js and npm
- PHP 8.2 or newer with common extensions enabled
- Composer
- Flutter stable, including Dart

On Windows, this repo has been prepared to work with Scoop-installed user-global tools:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
scoop bucket add extras
scoop install php composer flutter
```

Open a new terminal after installing so the user-level `PATH` is refreshed. If using Android builds, also install Android command-line tools or Android Studio, Java/JDK, and accept Android licenses with `flutter doctor --android-licenses`.

## Backend Setup

From `backend/`:

```powershell
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan migrate
php artisan test
```

Important backend environment variables:

- `APP_URL`: public backend URL.
- `DB_CONNECTION`: defaults to SQLite in `.env.example`.
- `SANCTUM_STATEFUL_DOMAINS`: browser origins that should receive Sanctum cookies.
- `MPESA_*`: Daraja/M-Pesa credentials and callback URL.
- `GEMINI_API_KEY`: provider key used by backend extraction and mobile session-key issuance.
- `GEMINI_MODEL`: defaults to `gemini-2.5-flash`.
- `GEMINI_MOBILE_KEY_TTL`: short-lived mobile credential TTL in seconds.
- `GEMINI_MOBILE_ENCRYPTION_SECRET`: shared secret used to encrypt mobile LLM session keys.
- `GOOGLE_CLIENT_IDS`: comma-separated allowed Google OAuth client ids.

To run the backend locally:

```powershell
php artisan serve
```

## Mobile Setup

From `mobile/`:

```powershell
flutter create --platforms=android,ios .
flutter pub get
flutter analyze
flutter test
```

Run with production-relevant configuration:

```powershell
flutter run `
  --dart-define=SHWAPY_API_BASE_URL=http://10.0.2.2:8000/api `
  --dart-define=SHWAPY_CLIENT_ENCRYPTION_SECRET=replace-with-mobile-secret `
  --dart-define=SHWAPY_GOOGLE_SERVER_CLIENT_ID=replace-with-google-web-client-id
```

`SHWAPY_CLIENT_ENCRYPTION_SECRET` must match backend `GEMINI_MOBILE_ENCRYPTION_SECRET`. Configure native camera permissions and Google sign-in client ids before release builds.

## Web Setup

From `web/`:

```powershell
npm install
npm run dev
npm run build
```

The web client resolves its API host from `VITE_API_BASE_URL` when present. Otherwise it uses `localhost:8000` on local hosts and the current LAN hostname on port `8000`.

## Verification Checklist

Before committing backend/mobile work, run the highest-signal checks available:

```powershell
cd backend
php artisan test

cd ..\mobile
flutter analyze
flutter test

cd ..\web
npm run build
```

If local tooling is unavailable, document the exact missing command and error in the final handoff.

## Working Rules For Agents

- Prefer existing service boundaries: controllers validate/shape requests, services hold provider/payment logic, DTOs carry structured extraction results.
- Do not commit secrets, API keys, release signing files, or generated build outputs.
- Keep mobile UI minimal and workflow-oriented. The capture path should remain fast: crop, resize, compress, then extract.
- Keep backend extraction as a fallback even when the mobile app calls Gemini directly.
- Do not overwrite unrelated working-tree changes. Inspect `git status -sb` before editing and stage only files that belong to the task.
