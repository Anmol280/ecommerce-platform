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

Load sample products once:

```powershell
docker compose exec api python -m scripts.seed_demo_data
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

An editable starting point is [`deploy/nginx/host-https.conf.example`](../deploy/nginx/host-https.conf.example); replace `api.example.com` with the controlled domain before enabling it.
