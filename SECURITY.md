# Credential handling

Keep M-Pesa, Google/Gemini, database and application credentials in private environment configuration. Example documents must contain empty values or explicit placeholders. The test suite generates an ephemeral application encryption key for each test; it never uses a deployment key.

Previously committed M-Pesa credentials and any real database password in earlier deployment examples require provider-side rotation. The historical phpunit.xml application key was scoped to testing; verify it was never reused in deployment before dismissing its alert. Rotating a production Laravel APP_KEY requires planning for existing encrypted data and sessions. No production credentials were changed by this source cleanup.
