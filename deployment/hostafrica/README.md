# HostAfrica deployment package

Build the upload-ready release from the repository root:

```powershell
.\deployment\hostafrica\build-hostafrica.ps1
```

The command creates:

- `dist/shwapy-hostafrica.zip`: Laravel, production Composer dependencies, and the prebuilt web client.
- `dist/shwapy-hostafrica.zip.sha256`: archive integrity checksum.
- `dist/shwapy-hostafrica-stage/`: inspectable uncompressed release contents.

The archive contains `DEPLOYMENT.md` with the DirectAdmin installation, update, rollback, and verification guidance. Runtime secrets are deliberately excluded.

For hosting accounts without Terminal or working cron, `install.sql` can initialize a new empty database through phpMyAdmin.
