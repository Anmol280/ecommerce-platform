# Local verification report

Updated 2026-11-13 after comparing the project with the complete attached assignment text. The supplied assignment file is DOCX (not PDF). Its paragraphs and tables were extracted and reviewed. Visual page rendering was unavailable because the bundled document renderer could not find LibreOffice; this does not affect text requirement extraction.

## Changes made in this pass

- Compose now refuses to start when `POSTGRES_PASSWORD` or `ADMIN_TOKEN` is empty; no weak fallback credentials are configured.
- PostgreSQL connection URLs are built with SQLAlchemy's URL builder, including proper handling of punctuation in passwords.
- Added two API tests for reserved-character database passwords and explicit `DATABASE_URL` precedence. The suite should now contain 10 tests; these new tests have not run yet.
- CI now checks Ruff formatting as well as lint, runs `pip-audit`, builds and scans an image for high/critical vulnerabilities on PR/push, and limits registry write access to the version-tag publish job.
- README now documents required settings, port exposure, and rollback. The runbook now covers incident response. Added an automated Nginx stop/detect/restart health drill.
- Added `docs/assignment-compliance-checklist.md` with requirement-by-requirement status and remaining actions.

## Checks completed in this pass

- `git diff --check`: passed.
- PowerShell parser checks for the recovery, runtime-verification, backup, and restore scripts: passed.
- Python syntax parsing for the changed configuration module and API test module: passed.
- `.env` is ignored by Git and is not tracked. Secret values were not read or printed. The example environment file contains empty secret fields, and Compose requires the candidate to set them.
- Project remains on local branch `main`; no GitHub remote is configured and no content was published.

## Checks not completed in this pass

- Docker Compose validation, build, automated API tests, dependency scan, image scan, live smoke checks, and Nginx failure/recovery drill were not run after these changes.
- The Docker named pipe returned “Access is denied” while checking service state. A request for elevated Docker access was automatically rejected by the current approval policy, which disallows that escalation in this session. I did not try to bypass the restriction. As a result, the current container health and rebuilt image state are unknown.
- Backup/restore scripts and guards were reviewed previously, but a disposable-database restore rehearsal and evidence were not completed. No restore was attempted against the assignment database; this pass did not alter its data or volume.
- GitHub Actions cannot be verified remotely without a repository/remote. No versioned image tag or registry digest exists yet.

## Previous baseline (before this pass)

The earlier local verification, against the pre-change revision, recorded Ruff passing, 8 API tests passing with one upstream Starlette/AnyIO deprecation warning, a successful production image build, healthy PostgreSQL/API/Nginx containers, and live health/catalog/admin/order smoke checks passing. The existing database migration was at `head`, and three missing demo products were added idempotently. No database volume was removed or reset. These are baseline results only; they do not replace rerunning checks after this pass.

## Security and submission notes

- The local `.env` remains outside Git. Credentials were exposed in the earlier conversation; rotate the database password and admin token before sharing, deploying, or recording. Their values are intentionally omitted here.
- No user data or customer dataset was added. Demo catalog values are synthetic.
- No GitHub repository/account was guessed, no remote was added, and no push was performed.
- See `docs/assignment-compliance-checklist.md` for the full rubric mapping and candidate-only submission items.

## Required next verification

In a session where Docker Desktop is accessible to Codex, run the project test target and Compose checks, rebuild/recreate only the API service while retaining the existing database volume, run `scripts/verify-runtime.ps1` and `scripts/failure-recovery-check.ps1`, and perform backup/restore only against a separately verified disposable database. Record actual results here before treating the assignment as submission-ready.
