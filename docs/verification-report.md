# Local verification report

Verified on 2026-11-13 with Docker Desktop on Windows. Checks ran against the project folder and its existing Compose database volume.

## Results

- Ruff: passed.
- Automated API suite: 8 passed. One upstream deprecation warning came from Starlette's test client and AnyIO.
- Production API image: built successfully; API and Nginx were brought up against the existing database.
- Live smoke checks: liveness and database readiness passed; Swagger, product search, and product detail returned success; unauthenticated admin access returned 401; configured admin audit read returned 200; invalid order input returned 422; missing order lookup returned 404.
- Database migration: Alembic reports the current revision at `head`.
- Sample catalog: the idempotent demo seed added three products that were missing. It does not overwrite existing SKUs.
- Data safety: no database volume was removed or reset. No order or admin-write request was made against the live database.

The isolated API suite covers product creation/search/detail, admin authentication and audit events, order price snapshots, idempotency replay/conflict, stock checks, cancellation stock recovery, empty admin-token configuration, and invalid request validation.

## Checks not performed

- The assignment PDF was not present in the project or the available assignment output folder, so the code could not be checked against the instructor's exact rubric.
- GitHub Actions could not be run remotely because this folder had no Git repository or remote when inspected. The workflow is present at `.github/workflows/ci.yml`; the same lint and test commands passed locally in Docker.
- The backup script was reviewed but not run, to avoid creating another copy of the live database. The restore script was reviewed and its explicit `-ConfirmRestore` guard was checked; a restore was not run because it replaces database objects.

## Before sharing or publishing

- Credentials were exposed in the prior conversation. Rotate both the PostgreSQL password and admin token before using a shared or public deployment. The local `.env` is ignored by Git and Docker; do not add it to a commit or include it in screenshots.
- The assignment PDF and intended GitHub repository/account are still needed for a rubric review and any push. No remote was invented and nothing was published.
