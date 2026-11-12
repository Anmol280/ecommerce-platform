# Submission evidence checklist

- [ ] `docker compose ps` shows database, API, and Nginx healthy.
- [ ] `/health/live` and `/health/ready` return success through Nginx.
- [ ] Product search and one product detail response are visible.
- [ ] Admin update without `X-Admin-Token` returns 401.
- [ ] Authorized product/stock update appears in audit events with the chosen actor.
- [ ] New order shows the item price snapshot and total; stock decreases.
- [ ] Exact retry with the same idempotency key returns the same order ID.
- [ ] Reusing the key with a different payload returns 409.
- [ ] Insufficient stock returns 409 and leaves stock unchanged.
- [ ] Cancellation restores stock and records an audit event.
- [ ] CI run is green for lint and tests; a `vX.Y.Z` tag publishes the versioned image.
- [ ] A backup file is created and a restore is demonstrated only in a disposable environment.
- [ ] README, architecture, and runbook are included in the submitted repository.
- [ ] Assignment form accurately discloses AI tools used, following its exact wording.
