# Five-minute demo script

Run `docker compose up --build -d`, seed the sample products, and open `http://localhost:8080/docs` before recording.

1. **Deployment and health (30 sec):** show `docker compose ps` and call `/health/live` and `/health/ready`.
2. **Catalog (45 sec):** call `GET /api/v1/products?q=wireless`, open one result with `GET /api/v1/products/{id}`, and point out price/currency/stock.
3. **Admin protection and audit (60 sec):** call `POST /api/v1/admin/products` without the admin token and show the 401. Repeat with `X-Admin-Token` and `X-Admin-Actor`, then show the `product.created` record in `GET /api/v1/admin/audit-events`.
4. **Order and price snapshot (90 sec):** create an order with `Idempotency-Key: demo-order-0001`, show its total and item price snapshot, then replay the exact same request and show the same order ID. Reuse the key with a different quantity and show the 409 response.
5. **Stock and recovery behavior (60 sec):** show the reduced stock, request more than the available quantity and show that checkout returns 409, then cancel the first order through the admin status endpoint and show stock restored.
6. **CI and operations (45 sec):** show the workflow file, latest test result, a backup file from `scripts/backup.ps1`, and the rollback/HTTPS instructions in the runbook.

Before recording, replace the local demo token in `.env`. Do not show credentials in the video. Explain that local tests use SQLite while Compose runs PostgreSQL; the current test suite does not simulate concurrent requests against PostgreSQL.
