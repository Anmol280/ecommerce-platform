# Local verification report

Updated 2026-11-13. This report continues the existing project at commit 61d20476f2b019b4d2934995d3d4968a946fe470. The supplied assignment source was 07_Cloud_Deployment_and_CI_CD_E_Commerce_Platform.docx; its full text and tables were reviewed.

## Access and safety

- The existing project folder was accessible. Docker Engine Server 28.5.2 and Compose 2.40.3 were reachable.
- The project remains on local branch main. No Git remote is configured; no repository was created and no GitHub content was published.
- The existing PostgreSQL volume, ecommerce-platform_postgres_data, was inspected before and after the API rebuild and kept unchanged. No database reset, volume removal, or restore was run against the assignment database. The API's normal startup migration check remained at head.
- Order creation, replay and input-validation writes used a separate API container with a SQLite database in tmpfs. Backup/restore used a separate PostgreSQL container with its data directory verified as tmpfs. The outage drill stopped/restarted only the Nginx service.
- Secret values were not read into evidence output, printed, or committed. .env remains ignored and untracked. Credentials exposed in earlier conversation should be rotated privately by the candidate before sharing or recording; no credential was changed here.

## Changes in this verification pass

- Fixed formatting in the API and test files and expanded the automated suite to 10 tests.
- Updated pinned FastAPI, Starlette and development dependencies after dependency-audit findings. Pinned pip and build tooling for image construction, then removed setuptools from the final runtime filesystem.
- Pinned the Python base image by digest and applied Debian security updates during image builds. The APT repository itself is not snapshot-pinned, so byte-for-byte reproducibility is not guaranteed.
- Added isolated API smoke and PostgreSQL backup/restore rehearsal scripts. Made the PowerShell HTTP checks work with Windows PowerShell 5 and safely capture container logs.
- Updated CI with actionlint-validated workflow checks, pip-audit and Trivy scan steps. Added a narrowly scoped, expiring Trivy exception for the stale setuptools 70.3.0 base-layer record, which is absent from the final runtime filesystem.
- Updated the assignment checklist, README, architecture, runbook and evidence checklist.

## Passed verification

| Check | Result |
|---|---|
| Compose configuration | docker compose config --quiet passed. |
| Expanded Docker test target | No-cache build passed Ruff lint, Ruff format check, all 10 API tests, pip-audit of project dependencies, and pip-audit of the installed test environment. Both audits reported no known vulnerabilities. |
| Production API image and Compose | No-cache API image rebuild succeeded. Compose started and reported API, PostgreSQL and Nginx healthy. The API image runs as app:app. Local tag: ecommerce-product-order-api:local. Local image ID: sha256:fd31b7e4e4f169d7497be960bec60cc4a1403791970336b759798d912abaed33. This is a local image ID, not a registry digest. |
| Live runtime smoke | Liveness, PostgreSQL readiness, Swagger 200, product search/detail, admin 401/200, invalid-order 422, missing-order 404 and migration-at-head checks passed through the running Compose stack. |
| Isolated order/API smoke | Liveness/readiness, Swagger, admin authentication, product create/search/detail, order create 201, stock decrement, exact idempotent replay with the same order ID and no second decrement, conflicting key reuse 409, invalid order 422 and order retrieval 200 passed. This data was isolated in SQLite tmpfs. |
| Reverse-proxy failure/recovery | Stopping Nginx caused proxy health failure while API readiness remained healthy. Restarting Nginx restored liveness and readiness. |
| Backup/restore rehearsal | The isolated PostgreSQL data directory was verified as tmpfs. A custom-format backup was created; after changing a synthetic marker, restore returned the marker to its backed-up value. The assignment database was not used. |
| Dependency audit | pip-audit . and pip-audit --local --skip-editable both passed with no known vulnerabilities. |
| CI workflow configuration | actionlint 1.7.12 passed on .github/workflows/ci.yml. It has PR/push quality and image checks and a version-tag-only publish job. Hosted GitHub Actions was not run. |
| Trivy CI-policy scan | Passed with zero findings after applying the workflow's ignore-unfixed rule and the version-specific, expiring exception described below. See trivy-image-scan-ci-policy.json and trivy-image-scan-ci-policy.log. |

## Failed verification and security findings

- The full Trivy high/critical gate failed. Its report contains 48 HIGH package entries and no CRITICAL entries: 47 Debian package entries have no fixed version in the current Trivy database, across 11 CVE IDs; one finding is a setuptools 70.3.0 record inherited from the pinned Python base layer. The final runtime image has no setuptools distribution metadata or importable setuptools package, but Trivy still reports that base-layer record.
- The CI-policy scan ignores unfixed findings and uses a one-package, one-version exception for pkg:pypi/setuptools@70.3.0, expiring 2026-12-13. It does not suppress other setuptools versions or packages. This is a passing scan under the configured policy, not a claim that the full image has no vulnerabilities. The strict and policy reports are both retained in docs/evidence.
- The Python image uses a pinned digest, but APT package versions come from live Debian repositories. Pin a Debian snapshot or document the intended update policy if reproducible package-level rebuilds are required.
- The local API suite does not stress PostgreSQL row-lock behavior with concurrent orders. The endpoint checks that create/replay an order ran against an isolated SQLite database; the live PostgreSQL stack was checked for readiness and read-oriented API paths.
- A Swagger screenshot was not captured. The browser tool reported that approval for the localhost origin had been declined. No alternate browser path or workaround was attempted.

## Evidence files

- expanded-test-build.log - no-cache test image build, lint/format, test and dependency-audit output.
- rebuild-and-compose.log - API image rebuild, Compose startup, service health and database-volume identity before/after.
- runtime-smoke.log - checks against the running Compose deployment.
- isolated-api-smoke.log - order creation/idempotency smoke using temporary SQLite storage, plus request logs without credentials.
- recovery-drill.log - reverse-proxy outage and recovery output.
- backup-restore-rehearsal.log - isolated PostgreSQL tmpfs backup/restore output.
- ci-workflow-lint.log - actionlint version and successful workflow lint.
- trivy-image-scan-strict.json and .log - strict high/critical scan; the command returned 1 because findings remain.
- trivy-image-scan-full.json and .log - complete high/critical finding set for the final image.
- trivy-image-scan-ci-policy.json and .log - CI-policy scan result.
- trivyignore-used.yaml - exact exception file used for the local policy scan.

Earlier failed harness attempts and pre-fix scans are retained with filenames identifying them as attempts or superseded reports; the final successful logs above are the authoritative verification outputs. None contains secret values.

## Still pending for submission

1. Rotate the previously exposed database password and admin token privately, then verify the new values work without sharing them.
2. Choose the GitHub account, repository name and visibility. Add a remote and push only after reviewing the local changes. This task did not publish or create a repository.
3. Run the workflow in GitHub and save its URL, version tag and registry digest. The local image ID above is not a registry digest.
4. Resolve or reassess the Debian high-severity findings when vendor-fixed packages become available; rerun the strict Trivy gate. Review the temporary setuptools exception before its expiry.
5. Capture a Swagger/deployment screenshot after allowing localhost browser access, or capture it on the laptop.
6. Record the required 3-5 minute demo, fill candidate identity fields and form declarations, verify reviewer links, and prepare for the 15-minute walkthrough and 10-minute live task.
7. For a live local-only review, keep Docker Desktop and the laptop awake while the services need to be available. For public HTTPS evidence, configure a controlled host/domain and certificate; that deployment has not been performed.

See docs/assignment-compliance-checklist.md for status against every assignment requirement.
