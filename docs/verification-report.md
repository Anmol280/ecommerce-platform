# Local verification report

Updated 2026-11-13. This pass continues the existing project from commit `9705b7a03e3a6345915b5c09e02cd7d4020a5146`. The assignment source reviewed earlier is `07_Cloud_Deployment_and_CI_CD_E_Commerce_Platform.docx`.

## Completed in this pass

- Verified Docker Desktop Linux Engine 28.5.2, Compose 2.40.3, and only the `ecommerce-platform` Compose services. The API image was rebuilt with `--no-cache`; only the API container was recreated. PostgreSQL and Nginx stayed in place.
- Confirmed the existing named volume `ecommerce-platform_postgres_data` before and after. Its creation time remained `2026-11-12T19:52:55Z`. The live table counts remained 3 products, 0 orders, 0 order items, and 0 audit events. No project data was reset or restored.
- Confirmed `.env` remains ignored and untracked. No secret values were printed or added to evidence.
- Ran the fresh no-cache Docker test target, live runtime verification, an isolated SQLite API/order test, an isolated PostgreSQL tmpfs backup/restore rehearsal, and the Nginx failure/recovery drill.
- Reviewed all 16 Gitleaks candidates from the current project directory and all Git history through this commit. All 16 are false positives in generated Trivy JSON evidence; the current directory and history findings overlap exactly by path, line, and rule. No candidate is in application/configuration files or `.env`.
- Refreshed the completed Trivy scan before rebuilding the production image. It reported 48 HIGH and 0 CRITICAL findings. A post-rebuild strict scan was attempted, but Trivy could not finish downloading its 133.47 MiB vulnerability database within the five-minute timeout. The rebuilt image's versions for all affected Debian packages matched the completed scan; setuptools remained absent from the final runtime. This comparison does not replace a completed post-rebuild Trivy scan.

## Passed verification

| Check | Result |
|---|---|
| Compose configuration and full stack | `docker compose config --quiet` passed. API, PostgreSQL, and Nginx all reported healthy after the API rebuild and proxy recovery. |
| No-cache Docker test target | Ruff lint and format checks passed; all 10 API tests passed. `pip-audit` reported no known vulnerabilities for the project dependencies and installed environment. The local project package is not published on PyPI, so that distribution itself is skipped by the index-based audit. |
| Rebuilt production API | `docker compose build --no-cache api` passed. The API image runs as `app:app`; local tag is `ecommerce-product-order-api:local`, image ID `sha256:a5f8401104ed2268a10ba8e07e494e297627bd1b69c020955efb61a68c337081`. No image was published. |
| Database authentication and data preservation | The rebuilt API made a read-only `SELECT 1` through its configured database connection. Readiness and migrations-at-head passed. The existing volume identity and table counts were unchanged. These checks used the current credentials; they were not rotated. |
| Live API checks | Liveness, database readiness, Swagger 200, product search/detail, admin missing-token 401 and configured-token 200, invalid-order 422, missing-order 404, and migration-at-head all passed through the running Compose stack. |
| Isolated API/order checks | In a separate SQLite tmpfs container: admin auth, product create/search/detail, order creation 201, stock decrement, same-key replay with the same order ID and no second decrement, changed-body key conflict 409, invalid order 422, and order retrieval 200 passed. The assignment database was not used for order writes. |
| Proxy failure and recovery | Nginx was stopped for the drill; proxy failure was detected while the API remained ready. Nginx restarted and liveness/readiness recovered. |
| Backup/restore rehearsal | A separate PostgreSQL test container used tmpfs for its data directory. A synthetic backup was restored successfully. The assignment database and volume were not used. |
| `.env` handling | `.env` matched `.gitignore` and is not tracked by Git. |
| CI configuration | The existing workflow had previously passed local `actionlint` validation. No workflow was run on GitHub; no remote is configured. |

## Failed or incomplete security verification

### Credential rotation

The tool's automatic safety review rejected the local database-password/admin-token rotation command before execution. I did not try another route around that restriction. No database role password, admin token, `.env` value, database container, or PostgreSQL volume was changed for rotation. The currently configured credentials still work, but the previously exposed credentials therefore remain a publication blocker.

### Secret scan

Gitleaks v8.30.1 returned 16 candidates in Git history and 16 in the current project directory. The safe metadata reports show an exact overlap across the two scans. All findings use the `generic-api-key` rule and point into eight generated Trivy image scan JSON files. The matched spans are the `GPG_KEY` fingerprint in Python base-image build metadata: the same image history uses that identifier to receive the public signing key and verify the Python source archive. This is public verification metadata, not a credential. Classification: 16 false positives, 0 confirmed secrets, 0 historical/revoked secrets, 0 placeholders, and 0 uncertain findings. No confirmed secret was found in tracked files or Git history by this scan. The local `.env` remains ignored and untracked.

This result concerns the 16 Gitleaks candidates only. The database password and admin token previously exposed in conversation remain unrotated and should still be rotated through an approved process; the Gitleaks candidates do not correspond to those credentials.

### Container vulnerabilities

The last completed Trivy scan before the production-image rebuild found 48 HIGH and 0 CRITICAL entries across 12 CVE IDs. Trivy listed no fixed version for 47 Debian package entries across 11 CVE IDs. Each affected Debian package is present in the rebuilt runtime image, and the rebuilt image's package versions match the completed scan:

| CVE group | Package entries |
|---|---|
| CVE-2026-76642, CVE-2026-78408, CVE-2026-78409, CVE-2026-78410 | `bsdutils`, `libblkid1`, `liblastlog2-2`, `libmount1`, `libsmartcols1`, `libuuid1`, `login`, `mount`, `util-linux` (9 entries for each CVE) |
| CVE-2026-54369 | `libacl1` |
| CVE-2025-69720 | `libncursesw6`, `libtinfo6`, `ncurses-base`, `ncurses-bin` |
| CVE-2026-119373, CVE-2026-119374, CVE-2026-119379 | `libsqlite3-0` (one entry for each CVE) |
| CVE-2026-16742 | `libsystemd0`, `libudev1` |
| CVE-2026-9538 | `perl-base` |

The remaining entry is `CVE-2025-47273` for `setuptools@70.3.0`, with a Trivy fixed version of `78.1.1`. Trivy reports the package in image-layer history, but the final runtime has neither an importable setuptools module nor distribution metadata after the Dockerfile's upgrade/uninstall step. The existing `.trivyignore.yaml` exception is limited to this exact PURL/version and expires `2026-12-13`; it does not broadly suppress the Debian findings. The prior CI-policy scan passed under its `ignore-unfixed` rule plus this exception, but that policy scan was not rerun on the rebuilt image.

The post-rebuild strict Trivy run did not finish: its database download timed out after five minutes, before a report was created. Therefore a completed strict scan of the rebuilt image is still pending. The previous completed report is retained, and the package-version comparison is documented as supporting evidence only, not as a replacement scan.

## Evidence files

- `docs/evidence/docker-test-target-fresh.log` — no-cache test build, Ruff, 10 tests, and dependency-audit output.
- `docs/evidence/docker-api-rebuild-current.log` — no-cache production API image rebuild and API-only Compose recreation.
- `docs/evidence/runtime-check-after-api-rebuild.log` and `docs/evidence/runtime-check-final-stack.log` — runtime checks after image rebuild and after proxy recovery.
- `docs/evidence/isolated-api-check-final.log` — isolated order/idempotency scenario and request logs without credential values.
- `docs/evidence/proxy-failure-recovery-final.log` — proxy outage detection and recovery.
- `docs/evidence/backup-restore-rehearsal-final.log` — isolated PostgreSQL tmpfs backup/restore.
- `docs/security-findings-report.md` — per-finding redacted classifications and recommendations for all 16 candidates.
- `docs/evidence/gitleaks-history-redacted.log` and `docs/evidence/gitleaks-worktree-redacted.log` — earlier redacted scanner summaries. The final safe metadata review is recorded in the security findings report.
- `docs/evidence/trivy-image-scan-before-api-rebuild.json` and `.log` — completed 48-HIGH scan from immediately before the API image rebuild. This report command recorded findings but did not enable Trivy's non-zero exit-code gate.
- `docs/evidence/trivy-image-scan-final-after-rebuild.log` — failed post-rebuild scan log showing the vulnerability-database download timeout; no post-rebuild JSON report was created.
- Earlier CI-policy, strict-scan, and workflow-lint evidence remains in `docs/evidence/` and is identified by its original filenames.

## Remaining blockers

1. Rotate the previously exposed database password and admin token through an approved local process, then recheck database authentication, admin authentication, `.env` ignore status, and data preservation.
2. Rotate the previously exposed database password and admin token through an approved process. They were not found in tracked files or history by Gitleaks, but their prior exposure remains a security concern.
3. Run a completed strict Trivy scan on the rebuilt image when the vulnerability database can be downloaded. Address or explicitly risk-accept the 47 runtime Debian findings; review the narrow setuptools exception before its expiry.
4. Choose a GitHub account, repository name, and visibility. No remote, repository, push, tag, or image publication has been created.
5. Run hosted CI and capture its URL and registry digest after publication is approved. The local image ID is not a registry digest.
6. Capture the Swagger/deployment screenshot and complete the remaining assignment demo/submission artifacts. The earlier browser attempt was blocked for localhost access; no workaround was attempted.

**Private staging status: repository content can proceed to private staging with `.env` kept excluded.** No repository or remote was created in this task. **Public publication status: not ready.** The previously exposed live credentials remain unrotated, and the rebuilt image still needs a completed strict Trivy scan with the 47 runtime Debian findings resolved or formally accepted.
