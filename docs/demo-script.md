# Three to five minute demo script

Use a private local .env and keep credentials out of the screen recording. Start the existing Compose stack, seed the sample products, and open the Swagger page before recording. The demo should take about 4 minutes 50 seconds.

1. Deployment and health (35 seconds): show docker compose ps, /health/live, /health/ready, and Swagger.
2. Catalog (40 seconds): search for a wireless product, open its detail, and point out price, currency, and stock.
3. Admin protection and audit (45 seconds): show an admin request without the token returning 401, then a valid update with an actor and its audit record.
4. Order and idempotency (85 seconds): create an order with a stable Idempotency-Key, show the order total and item price snapshot, then replay the same request and show the same order ID with no second stock deduction. Reuse the key with a different quantity to show 409, then show invalid-order validation.
5. Failure and recovery (40 seconds): run scripts/failure-recovery-check.ps1 and show the proxy outage detection and restored health/readiness. This briefly interrupts Nginx.
6. CI and operations (45 seconds): show the workflow configuration and the saved local test output. Show the isolated PostgreSQL tmpfs backup/restore evidence and the rollback/HTTPS guidance. Be clear that GitHub-hosted CI, registry publication, public HTTPS, and the demo video are still pending; do not present them as completed.

Order creation for this recording may use a dedicated demo product in the local project. The verification session used an isolated SQLite tmpfs database for order creation/idempotency so it would not write test orders to the existing assignment database. The PostgreSQL backup/restore rehearsal also used a separate tmpfs database. Explain that the test suite does not stress concurrent PostgreSQL checkout requests.
