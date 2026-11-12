# Architecture and design notes

## Runtime layout

```mermaid
flowchart LR
    Client[Demo client / operator] -->|HTTP| Proxy[Nginx reverse proxy]
    Proxy -->|private Compose network| API[FastAPI Product and Order API]
    API -->|SQLAlchemy / PostgreSQL| DB[(PostgreSQL 16)]
    DB --- Volume[(Persistent Docker volume)]
    GitHub[GitHub Actions] -->|tests and lint| CI[Quality job]
    CI -->|version tag only| Registry[GitHub Container Registry]
    Registry -. release image .-> VM[Optional Linux VM]
```

The public Compose port is bound to `127.0.0.1:8080` by default. For a VM, a host Nginx installation can terminate HTTPS and proxy to this local port. The API and database have no public host ports; they communicate on the private Compose network.

## Checkout and consistency

Order creation normalizes repeated product lines, locks product rows in ascending ID order on PostgreSQL, validates active state and stock, records the current price/name/SKU in order items, decrements stock, and writes the order in one transaction. Each order requires an `Idempotency-Key`. A canonical request hash lets an exact retry replay the first response while rejecting reuse of that key for different order contents. A database uniqueness constraint closes the concurrent duplicate-request race; a losing transaction rolls back its stock changes.

The automated tests use SQLite for a fast self-contained run. SQLite does not implement PostgreSQL row-level `FOR UPDATE` locking, so the local tests verify functional and transaction outcomes but do not prove concurrent checkout behavior. The Docker Compose deployment uses PostgreSQL, where those locks apply.

## Security boundaries

- Admin product changes, order status changes, and audit reads require `X-Admin-Token`.
- Compare tokens with a constant-time comparison; never log the token.
- Compose's local default token is for a private demo only. Replace it with a long random secret before using a VM.
- API/database ports stay inside Compose; Nginx is the only published service.
- The API image runs as a non-root user and reads configuration from environment variables.
- TLS certificates and deployment secrets are intentionally external to the repository.

## Recovery model

The PostgreSQL named volume preserves data across normal container replacement. `scripts/backup.ps1` creates a custom-format dump; `scripts/restore.ps1` replaces matching objects only after an explicit `-ConfirmRestore` flag. CI publishes immutable version and commit tags on `vX.Y.Z`. A previous version can be selected by changing `IMAGE_TAG` and recreating the API container.
