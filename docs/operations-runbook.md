# Operations runbook

Commands below are written for PowerShell on Windows 11. Run them from the project folder.

## Start and inspect

```powershell
Copy-Item .env.example .env
# Edit .env and replace ADMIN_TOKEN and POSTGRES_PASSWORD before any shared deployment.
docker compose up --build -d
docker compose ps
docker compose logs --tail 100 api
Invoke-RestMethod http://localhost:8080/health/live
Invoke-RestMethod http://localhost:8080/health/ready
```

Run the read-only application smoke checks after startup. The script verifies health, Swagger, a seeded product, admin authentication, input validation, a missing-order response, and the applied migration revision. It reads the admin token from `.env` without printing it.

```powershell
.\scripts\verify-runtime.ps1
```

For order creation and retry checks without writing test orders to the assignment database, run the isolated API smoke. It creates a temporary read-only API container and stores its SQLite database in tmpfs; the script removes only that named test container when it finishes.

```powershell
.\scripts\verify-isolated-api.ps1
```

On startup, the API seeds the three demo products only if the product table is empty. Existing product data is left unchanged. Search the catalog with:

```powershell
Invoke-RestMethod 'http://localhost:8080/api/v1/products?q=wireless'
```

## Routine restart and recovery

```powershell
docker compose restart api
docker compose ps
Invoke-RestMethod http://localhost:8080/health/ready
```

If the database is unavailable, Compose health checks prevent the API from starting before PostgreSQL is ready. Inspect logs and restart the unhealthy service after fixing its cause:

```powershell
docker compose logs --tail 150 db
docker compose logs --tail 150 api
docker compose up -d db
docker compose up -d api
```

Do not run `docker compose down -v` during routine recovery: `-v` deletes the persistent database volume.

### Incident response and recovery drill

1. Check `docker compose ps` and the liveness/readiness endpoints to identify whether the proxy, API, or database is unhealthy.
2. Inspect only the affected service's recent logs with `docker compose logs --tail 150 <service>`. Request logs include request IDs; never paste `.env` contents or admin headers into tickets or screenshots.
3. Restore service using `docker compose up -d <service>` after correcting its configuration or dependency. Confirm `/health/live`, `/health/ready`, and one catalog request.
4. Record the failure symptom, recovery action, and health-check result. For an application regression, use the image rollback steps below. For suspected data damage, stop writes, preserve the current database volume, verify the backup file, and follow the restore procedure only against the intended database.

The automated proxy recovery drill stops only Nginx, verifies that the external health request fails while the API remains running, restarts Nginx in a `finally` path, and verifies liveness/readiness recovery. It does not touch the database or its volume:

```powershell
.\scripts\failure-recovery-check.ps1
```

The 2026-11-13 local rehearsal detected the Nginx outage and restored liveness/readiness after restarting the proxy. The recorded output is in `docs/evidence/recovery-drill.log`.

## Backup and restore

Back up before a release or database maintenance:

```powershell
.\scripts\backup.ps1
Get-ChildItem .\backups
```

Restore a chosen dump only after verifying its file and accepting that matching database objects are replaced:

```powershell
.\scripts\restore.ps1 -BackupPath .\backups\ecommerce-YYYYMMDD-HHMMSS.dump -ConfirmRestore
Invoke-RestMethod http://localhost:8080/health/ready
```

Copy backups off the VM and protect them as sensitive data. The example does not implement automatic retention or off-site scheduling.

The disposable rehearsal has passed. It creates a unique Compose project and a PostgreSQL data directory verified as tmpfs, makes a synthetic table, backs it up, changes a marker, restores the dump, and checks that the original marker returns. It does not use the assignment database or create a persistent test volume:

```powershell
.\scripts\test-backup-restore.ps1
```

The recorded output is in `docs/evidence/backup-restore-rehearsal.log`. This rehearsal validates the helper scripts, but it is not a restore of production data. Continue to verify the dump and target database before any real restore.

## Container vulnerability status and temporary risk acceptance

As of 2026-11-13, the strict Trivy scan of the production API image exits 1. It reports 47 HIGH Debian findings in the final runtime, plus one HIGH setuptools finding in image-layer history; the full scan has 208 findings. The findings, package groups, and complete JSON are in `docs/verification-report.md` and `docs/evidence/`.

The official `python:3.12-slim-trixie` candidate was built separately and scanned with a fresh Trivy database. Its base digest matched the existing Python base, its final OS package inventory matched all 87 packages in the current image, and all 47 HIGH runtime finding tuples were identical. The candidate passed the 10-test API suite, non-root check, and read-only health, readiness/PostgreSQL, and product-list checks. It was not adopted. The current Dockerfile, production image, running services, and database were left unchanged.

Temporary acceptance is limited to local/private assignment preparation through **2026-12-13**. It is not an assertion that the image is vulnerability-free or secure, and it does not approve public production exposure. Until review, retain the non-root API user, do not enable privileged mode or add Linux capabilities, keep PostgreSQL private and the API behind the loopback-bound reverse proxy, and avoid introducing untrusted local files or shell/utility inputs into the API workflow. These controls reduce exposure; they do not make the strict scan pass.

Review earlier if Debian publishes a security update for any listed Trixie package, Trivy adds or changes a relevant advisory, or before public release. Otherwise, review by 2026-12-13: check Debian security status and the official Python 3.12 Trixie digest, rebuild a separate candidate, run the full strict Trivy scan, compare findings, and repeat runtime checks before requesting approval to replace the production image. Do not suppress findings to satisfy the scan.

## Release and rollback

After the version-tag workflow publishes `ghcr.io/OWNER/REPOSITORY:1.0.0`, set these values in the deployment `.env`:

```dotenv
IMAGE_NAME=ghcr.io/OWNER/REPOSITORY
IMAGE_TAG=1.0.0
```

Then deploy:

```powershell
docker compose pull api
docker compose up -d --no-build api
docker compose ps
Invoke-RestMethod http://localhost:8080/health/ready
```

To roll back, restore the prior known-good `IMAGE_TAG`, then repeat `pull`, `up -d --no-build api`, and health checks. Database schema migrations are forward-only in this MVP; take a backup and review migration compatibility before rolling an image back across a schema change.

## HTTPS for a Linux VM

For a small single-VM deployment, keep Compose bound to `127.0.0.1:8080` and terminate TLS with host Nginx. Point DNS for a domain to the VM, allow ports 80/443 in the firewall, install Nginx and Certbot, then request a certificate:

```bash
sudo apt update
sudo apt install nginx certbot python3-certbot-nginx
sudo certbot --nginx -d api.example.com
```

Use a host Nginx site whose TLS server proxies to `http://127.0.0.1:8080`, then verify renewal with `sudo certbot renew --dry-run`. Keep certificate files and private keys out of Git. Do not expose the app publicly until the admin token and database password have been replaced.

An editable starting point is [`deploy/nginx/host-https.conf.example`](../deploy/nginx/host-https.conf.example); replace `api.example.com` with the controlled domain before enabling it. This configuration is an example only; no certificate or public HTTPS endpoint has been provisioned.
