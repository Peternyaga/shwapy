# Shwapy on HostAfrica

This release is prepared for HostAfrica Linux shared hosting and DirectAdmin. It contains the Laravel API, production Composer dependencies, and the prebuilt React frontend. Node.js, npm, Composer, Docker, Redis, and a persistent queue worker are not required on the server.

## Compatibility requirements

- PHP 8.2 or newer.
- PHP extensions: ctype, curl, dom, fileinfo, filter, hash, mbstring, openssl, pcre, PDO, pdo_mysql, session, tokenizer, and xml.
- MySQL or MariaDB with `utf8mb4` support.
- Apache-compatible rewrite rules (`public/.htaccess`) or equivalent routing to `public/index.php`.
- Outbound HTTPS access to Google Gemini and Safaricom Daraja.
- HTTPS for the public domain.

The package does not contain secrets, an `.env` file, user uploads, logs, database data, or development dependencies.

## Recommended directory mapping

Extract the archive into a private application directory, for example:

```text
/home/ACCOUNT/apps/shwapy
```

In DirectAdmin, set the selected domain or subdomain document root to:

```text
/home/ACCOUNT/apps/shwapy/public
```

Only `public/` may be web-accessible. Do not point the document root at the application root; doing so can expose configuration and source files.

If DirectAdmin cannot map a domain to a private custom document root, keep the application outside `public_html` and copy only the contents of this release's `public/` directory into the domain document root. Then update the two paths in `public/index.php` so they resolve to the private application's `vendor/autoload.php` and `bootstrap/app.php`. The custom-document-root arrangement is preferred because it does not require release-specific path edits.

## First deployment

1. In DirectAdmin, create a MySQL/MariaDB database and least-privilege database user. Record the exact host, port, prefixed database name, username, and password shown by the panel.
2. Select PHP 8.2 or newer and enable the extensions listed above.
3. Upload and extract the release archive into the private application directory.
4. Copy `.env.production.example` to `.env`. Replace every example hostname and fill all required secrets. Keep `.env` private and preserve it across later releases.
5. Generate `APP_KEY` locally with `php artisan key:generate --show`, or run `php artisan key:generate` once on the server after `.env` exists. Never rotate this key during an ordinary release.
6. Ensure `storage/` and `bootstrap/cache/` are writable by the PHP application user. Typical permissions are directories `0755` or `0775` depending on HostAfrica's PHP ownership model; do not use `0777`.
7. Set the domain document root to the release's `public/` directory and enable HTTPS.
8. Run the release commands below through DirectAdmin Terminal. If Terminal is unavailable, create one-time cron jobs with the PHP CLI path displayed by DirectAdmin, run each once, then remove it.

```sh
cd /home/ACCOUNT/apps/shwapy
php artisan migrate --force
php artisan optimize
```

Do not run `storage:link` unless a future Shwapy feature stores public uploads. Current application files are private.

### Without Terminal or working cron

For a new, empty Shwapy database, open phpMyAdmin from DirectAdmin, select the database configured by `DB_DATABASE`, choose **Import**, and upload `install.sql` from this release. The SQL creates the same initial tables as the included Laravel migrations and records those migrations as applied. It does not drop tables, create application users, or contain secrets. Do not use it to upgrade an existing Shwapy database; later releases must apply only their new migrations.

## DirectAdmin values

- Public URL: `https://YOUR_DOMAIN`
- Document root: `/home/ACCOUNT/apps/shwapy/public`
- Application log: `/home/ACCOUNT/apps/shwapy/storage/logs/laravel.log` (daily logs may include a date suffix)
- Health check: `https://YOUR_DOMAIN/up`
- M-Pesa callback: `https://YOUR_DOMAIN/api/payments/callback`

This is a request-oriented PHP deployment. Do not configure Passenger, a Node startup file, PM2, systemd, Docker, Redis, or a permanent Laravel queue worker. `QUEUE_CONNECTION=sync` ensures work executes in the web request on this shared-hosting plan.

## Release update

Back up the database and the persistent `.env` file first. Extract the new release into a new sibling directory when possible, copy the existing `.env` into it, ensure writable-directory permissions, run:

```sh
php artisan migrate --force
php artisan optimize
```

Then switch the document root to the new release's `public/` directory. Keep the previous release temporarily for rollback. Database migrations are forward changes, so application rollback may also require a database restore when a release changes schema.

If replacing files in place, never overwrite `.env` or persistent storage. Run `php artisan optimize:clear` before replacement if stale cached paths are suspected, and run `php artisan optimize` afterward.

## Verification

1. Open `/up` and confirm HTTP 200.
2. Open `/` and confirm the Shwapy web interface loads over HTTPS with no mixed-content errors.
3. Register or sign in, then confirm `/api/payments` succeeds.
4. Test a Gemini extraction with a non-sensitive sample.
5. Validate Daraja credentials in the intended environment before initiating a real payment.
6. Confirm Safaricom can reach the HTTPS callback URL.
7. Review `storage/logs/` without copying secrets into support tickets.

## Operational notes

- Process memory is not durable. Sessions and cache use MySQL; queues run synchronously.
- Daraja uses `MPESA_SHORTCODE` as the initiating organization shortcode and the reviewed extracted Paybill or Till as `PartyB`. Safaricom must have provisioned that destination relationship for the configured production credentials and passkey.
- Keep generated files and runtime data outside replaceable release files.
- Use DirectAdmin cron only for bounded scheduled commands. Persistent workers are not assumed.
- After editing `.env`, run `php artisan optimize:clear` followed by `php artisan optimize` so cached configuration reflects the new values.
- Rotate logs and watch account storage, CPU, memory, I/O, database connection, upload-size, and request-time limits.
- Production logs must not include credentials, tokens, cookies, payment secrets, or full sensitive payloads.
