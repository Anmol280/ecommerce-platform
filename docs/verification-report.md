# Local verification report

Updated 2026-11-13. This pass continues the existing project from commit `3439cb8a663425e912b55341f13736c4c3c36c17`. The assignment source reviewed earlier is `07_Cloud_Deployment_and_CI_CD_E_Commerce_Platform.docx`.

## Completed in this pass

- Verified Docker Desktop Linux Engine 28.5.2, Compose 2.40.3, and only the `ecommerce-platform` Compose services. The API image was rebuilt with `--no-cache`; only the API container was recreated. PostgreSQL and Nginx stayed in place.
- Confirmed the existing named volume `ecommerce-platform_postgres_data` before and after. Its creation time remained `2026-11-12T19:52:55Z`. The live table counts remained 3 products, 0 orders, 0 order items, and 0 audit events. No project data was reset or restored.
- Confirmed `.env` remains ignored and untracked. No secret values were printed or added to evidence.
- Ran the fresh no-cache Docker test target, live runtime verification, an isolated SQLite API/order test, an isolated PostgreSQL tmpfs backup/restore rehearsal, and the Nginx failure/recovery drill.
- Reviewed all 16 Gitleaks candidates from the current project directory and all Git history through this commit. All 16 are false positives in generated Trivy JSON evidence; the current directory and history findings overlap exactly by path, line, and rule. No candidate is in application/configuration files or `.env`.
- Ran a fresh strict Trivy 0.76.2 scan against the rebuilt API image by immutable digest, using vulnerability DB version 2 updated 2026-11-13. The scan included all severities, did not ignore unfixed findings, and returned exit code 1. The complete JSON report and a per-finding runtime/fix classification CSV are saved in `docs/evidence/`.
- Built and tested a separate official `python:3.12-slim-trixie` candidate without changing the project Dockerfile or current services. The official base digest and all 87 final OS packages matched the current image; the candidate strict scan returned the same counts and the exact same 47 HIGH runtime findings. The candidate passed the existing 10-test suite and read-only live checks, but was not adopted.

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

The rebuilt production API image was scanned as `ecommerce-product-order-api@sha256:a5f8401104ed2268a10ba8e07e494e297627bd1b69c020955efb61a68c337081`. Its Docker image ID and the running API container's image ID both match `sha256:a5f8401104ed2268a10ba8e07e494e297627bd1b69c020955efb61a68c337081`.

Trivy 0.76.2 used vulnerability DB v2, updated at `2026-11-13T07:00:07Z` and downloaded at `2026-11-13T09:14:26Z`. The scan included OS and library vulnerabilities at all severities, applied no `ignore-unfixed` filter, and used exit code 1 as the failure threshold. It returned exit code **1 (fail)** with 208 findings across 94 advisory IDs:

| Severity | Findings | Present in final runtime | Layer-history only | Fix version listed |
|---|---:|---:|---:|---:|
| CRITICAL | 0 | 0 | 0 | 0 |
| HIGH | 48 | 47 | 1 | 1 |
| MEDIUM | 90 | 89 | 1 | 1 |
| LOW | 66 | 65 | 1 | 1 |
| UNKNOWN | 4 | 4 | 0 | 0 |
| **Total** | **208** | **205** | **3** | **3** |

The 205 Debian findings affect 42 distinct OS packages. Every named package and installed version is present in the final runtime image. Trivy listed no fixed version for these entries: 47 HIGH, 89 MEDIUM, 65 LOW, and 4 UNKNOWN. “No fix listed” means the current Trivy database supplied no fixed version; it does not establish that Debian has no patch or mitigation. The full affected-package and advisory list is in `trivy-image-scan-rebuilt-classification.csv`.

The 47 HIGH runtime entries group as follows:

| Advisory group | Affected runtime package entries | Count |
|---|---|---:|
| `CVE-2026-76642`, `CVE-2026-78408`, `CVE-2026-78409`, `CVE-2026-78410` | Each advisory maps to `bsdutils`, `libblkid1`, `liblastlog2-2`, `libmount1`, `libsmartcols1`, `libuuid1`, `login`, `mount`, and `util-linux` (versions `2.41.5-0+deb13u1` family; `login` is `1:4.16.0-2+really2.41.5-0+deb13u1`). | 36 |
| `CVE-2026-54369` | `libacl1` `2.3.2-2+b1` | 1 |
| `CVE-2025-69720` | `libncursesw6`, `libtinfo6`, `ncurses-base`, `ncurses-bin` `6.5+20250216-2` | 4 |
| `CVE-2026-119373`, `CVE-2026-119374`, `CVE-2026-119379` | `libsqlite3-0` `3.46.1-7+deb13u2` | 3 |
| `CVE-2026-16742` | `libsystemd0`, `libudev1` `257.13-1~deb13u1` | 2 |
| `CVE-2026-9538` | `perl-base` `5.40.1-6+deb13u1` | 1 |
| **Total** | **18 package names across 11 advisory IDs** | **47** |

The other three findings refer to `setuptools@70.3.0` in image-layer history. The final runtime has no importable setuptools module or distribution metadata. Trivy lists fixed versions for all three: HIGH `CVE-2025-47273` at `78.1.1`, MEDIUM `CVE-2026-59890` at `83.0.0`, and LOW `GHSA-xmj3-9gf7-h52w` at `84.1.0`. The finding layer is the Dockerfile layer that upgrades build tooling and uninstalls setuptools. The existing `.trivyignore.yaml` exception remains limited to the exact `CVE-2025-47273` PURL/version and expires `2026-12-13`; no suppression was added in this pass.

### Risk and mitigation options

### Official Slim Trixie candidate comparison and temporary acceptance

The tested official `python:3.12-slim-trixie` tag resolves to the exact base digest already pinned in the Dockerfile: `sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b`. The separately tagged candidate image is `ecommerce-product-order-api:trixie-candidate`, image ID `sha256:a27ccd04076979aab1f98a59cb3e8c431c91f3ae401ca029134df1b2f6a65f6c`. Both current and candidate final images have the same 87 OS package entries. Candidate Trivy returned exit code 1 with 208 findings (48 HIGH, 90 MEDIUM, 66 LOW, 4 UNKNOWN); the 47 HIGH runtime tuples match the baseline exactly. The candidate was not adopted.

Candidate compatibility checks passed: Ruff and format checks, all 10 API tests, both pip-audit checks, non-root UID 999, liveness 200, readiness/PostgreSQL 200, and product-list 200. A disposable Compose one-off container used read-only requests and bypassed the migration entrypoint; the existing API, PostgreSQL, and Nginx containers remained healthy. The assignment database was not written.

The runtime package findings remain real package matches; Trivy did not test exploitability or code-path reachability. The container runs as non-root UID 999 without privileged mode or added capabilities. The API is exposed through the loopback-bound proxy, PostgreSQL stays private, `systemd-homed` is absent, and production Compose uses PostgreSQL. The image still contains the affected system libraries/utilities; the SQLite library also supports the project's existing SQLite configuration and tests. These controls reduce exposure but do not make the strict scan pass or eliminate residual risk.

**Temporary risk acceptance:** for local/private assignment preparation only, accept the residual runtime package risk through **2026-12-13** while retaining the controls above. This is not a statement that the image is vulnerability-free or secure, and it is not approval for public production exposure. Review earlier if Debian publishes a Trixie fix, Trivy changes an applicable advisory, or before any public release. At the review date, check Debian advisories and the official Python Trixie digest, build and strictly scan a separate candidate, compare results, and rerun compatibility checks before asking approval to replace the current image. Do not suppress findings to achieve a pass.

No permanent base image, dependency, application code, credential, Docker Compose, or database change was made.

## Evidence files

- `docs/evidence/docker-test-target-fresh.log` — no-cache test build, Ruff, 10 tests, and dependency-audit output.
- `docs/evidence/docker-api-rebuild-current.log` — no-cache production API image rebuild and API-only Compose recreation.
- `docs/evidence/runtime-check-after-api-rebuild.log` and `docs/evidence/runtime-check-final-stack.log` — runtime checks after image rebuild and after proxy recovery.
- `docs/evidence/isolated-api-check-final.log` — isolated order/idempotency scenario and request logs without credential values.
- `docs/evidence/proxy-failure-recovery-final.log` — proxy outage detection and recovery.
- `docs/evidence/backup-restore-rehearsal-final.log` — isolated PostgreSQL tmpfs backup/restore.
- `docs/security-findings-report.md` — per-finding redacted classifications and recommendations for all 16 candidates.
- `docs/evidence/gitleaks-history-redacted.log` and `docs/evidence/gitleaks-worktree-redacted.log` — earlier redacted scanner summaries. The final safe metadata review is recorded in the security findings report.
- `docs/evidence/trivy-image-scan-rebuilt-strict.json` and `.log` — complete scan against the rebuilt image digest, with strict exit code and updated vulnerability database.
- `docs/evidence/trivy-image-scan-rebuilt-classification.csv` — all 208 findings classified by severity, package, runtime presence, and fix availability.
- `docs/evidence/trivy-image-scan-trixie-candidate.json` and `.log` — complete candidate scan and redacted summary; strict exit 1, same 208 findings, identical 47 HIGH runtime entries.
- `docs/evidence/trivy-image-scan-before-api-rebuild.json` and `.log` — completed 48-HIGH scan from immediately before the API image rebuild. This report command recorded findings but did not enable Trivy's non-zero exit-code gate.
- `docs/evidence/trivy-image-scan-final-after-rebuild.log` — earlier post-rebuild database-download timeout, superseded by the completed strict scan in `trivy-image-scan-rebuilt-strict.json` and `.log`.
- Earlier CI-policy, strict-scan, and workflow-lint evidence remains in `docs/evidence/` and is identified by its original filenames.

## Remaining blockers

1. Rotate the previously exposed database password and admin token through an approved process, then recheck database authentication, admin authentication, `.env` ignore status, and data preservation.
2. Review the temporary local/private acceptance of the 47 HIGH runtime findings by `2026-12-13`, or earlier on a Debian Trixie fix, applicable Trivy advisory change, or before public release. The strict image scan still fails. Review the narrow setuptools exception before its `2026-12-13` expiry.
3. Choose a GitHub account, repository name, and visibility before any later publication. No remote, repository, push, tag, or image publication has been created.
4. Run hosted CI and capture its URL and registry digest after publication is approved. The local image ID is not a registry digest.
5. Capture the Swagger/deployment screenshot and complete the remaining assignment demo/submission artifacts. The earlier browser attempt was blocked for localhost access; no workaround was attempted.

**Private staging status: repository content can proceed to private staging with `.env` kept excluded.** The temporary risk acceptance covers only local/private assignment preparation. No repository or remote was created in this task. **Public publication status: not ready.** The previously exposed live credentials remain unrotated, and the strict scan still fails with 47 HIGH runtime findings lacking a fixed Trixie version in the scan database.
