# Assignment compliance checklist

Compared against every section and table in the supplied assignment, 07_Cloud_Deployment_and_CI_CD_E_Commerce_Platform.docx. The supplied source is a DOCX file, not a PDF. Its paragraphs and tables were extracted and reviewed in full. The 15-day schedule is guidance; it is not a project acceptance requirement.

Complete means the requested capability exists and was verified locally where practical. Partially Complete means a configuration or local proof exists but hosted, external, or candidate-specific evidence is still missing. Missing means the required artifact or candidate action has not been completed.

## Business scope and API

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Build the assigned small product and order API, not a full storefront or marketplace. | Complete | FastAPI provides the allocated product/order workflow. Payments and storefront UI remain out of scope. |
| Use a domain-specific service implementing the brief. | Complete | Product, order, admin, audit and status routes are implemented. |
| Expose health and readiness, product search/details, and order creation. | Complete | Live Compose checks passed for health/readiness, Swagger, catalog search and product details. |
| Validate availability and quantities; snapshot price and product data at checkout. | Complete | The 10-test suite passed. Isolated API checks created and retrieved an order; the suite covers checkout rules and snapshots. |
| Prevent negative stock and make repeated order creation idempotent. | Complete | The isolated smoke verified 201 on creation and replay, the same order ID, unchanged stock, 409 for a different payload with the same key, and 422 for invalid input. PostgreSQL concurrency locking remains an untested edge case. |
| Protect admin product/stock operations and write audit events. | Complete | The test suite passed admin authorization/audit cases. The isolated smoke verified unauthorized 401, authorized 200, and product creation. |
| Include seed products and a simple order status endpoint. | Complete | The seed script, product search, order lookup, and status routes are present. |

## Technical expectations

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Use a secure, reproducible Dockerfile, non-root runtime, and limited layers/dependencies. | Partially Complete | A no-cache image build passed, the Python base is digest-pinned, the runtime runs as app:app, and build-only setuptools is removed. Debian packages are upgraded from live repositories rather than a pinned snapshot. The strict image scan also reports 47 high-severity Debian package entries with no fix version in its database. |
| Orchestrate the app and database with persistent storage and health checks. | Complete | Compose validation passed; API, PostgreSQL, and Nginx are healthy. The existing PostgreSQL volume identity was the same before and after rebuild. |
| Run formatting/lint, tests, and an image build on PR/push; use versioned tags and avoid committed secrets. | Partially Complete | The workflow passed actionlint and includes lint/format, tests, dependency audit, image build/scan, and tag-only version/SHA/latest publishing. No remote is configured, so hosted CI and the versioned artifact have not run. |
| Demonstrate a VM/container deployment with reverse proxy and HTTPS configuration. | Partially Complete | The local Compose/Nginx deployment and Linux host-Nginx/Certbot example exist. No VM, controlled domain, certificate, or live HTTPS endpoint was deployed. |
| Use environment configuration, least privilege, secret management, and appropriate network exposure. | Partially Complete | Secrets are required from local environment settings; API/database ports remain private; the API runs non-root; .env is ignored and untracked. A cloud secret manager is not configured. Credentials were previously exposed in conversation and must be rotated by the user before sharing or recording. |
| Include dependency and container scans where feasible. | Complete | pip-audit found no known application or installed-environment vulnerabilities. The Trivy CI-policy scan passed with zero findings after ignoring unfixable entries and one expiring, version-specific exception for setuptools 70.3.0 metadata absent from the final runtime. A strict scan still reports 47 unfixable Debian package findings; see the verification report. |
| Provide health/readiness, structured logs, and useful troubleshooting; metrics are optional. | Complete | Live health/readiness passed; JSON request logs include request IDs. Runbook troubleshooting is documented. Metrics are not implemented and are a stretch goal. |
| Demonstrate backup/restore, restart/recovery, and document rollback. | Complete | A disposable PostgreSQL tmpfs backup/restore rehearsal and the Nginx failure/recovery drill both passed. Rollback steps are documented. The assignment database and volume were not reset or restored. |
| Include deployment configuration and a concise reproducible runbook. | Complete | Compose, Nginx configuration, README, architecture diagram and operations runbook are present. Fresh-machine onboarding is not independently tested. |

## Acceptance tests

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Repeating checkout with the same idempotency key creates no duplicate order and does not deduct stock twice. | Complete | Verified in the 10-test suite and isolated API smoke. PostgreSQL concurrent-request behavior is not separately stress-tested. |
| A clean environment can build and start using documented steps. | Complete | A no-cache Docker test build passed and the full Compose stack started healthy from the documented project configuration. A separate new laptop was not used. |
| A CI run executes checks/tests and produces a versioned artifact/image. | Partially Complete | Workflow configuration passed actionlint. A hosted run and registry artifact require a selected GitHub repository; neither was created or published. |
| Show health/logs and deliberately stop or break a service, then detect and recover. | Complete | The Nginx outage drill detected proxy failure while API health remained ready, restarted Nginx, and restored health/readiness. |
| Restore a backup or show rollback evidence. | Complete | A custom-format dump restored the expected synthetic marker in an isolated tmpfs PostgreSQL database. |

## Required submission package

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Repository containing source, Dockerfile, Compose, CI and deployment configuration. | Partially Complete | These files are in the existing local Git repository. No GitHub remote or reviewer-accessible repository exists yet. |
| README with build/run/deploy steps, environment variables, ports and rollback. | Complete | README documents prerequisites, configuration, port exposure, run, recovery and rollback. |
| Architecture diagram and runbook for deployment, restart, logs, backup/restore and incidents. | Complete | Mermaid architecture and the operations runbook are present. |
| Pipeline URL/screenshot, image tag/digest, and deployment/health evidence. | Partially Complete | Local tag ecommerce-product-order-api:local, local image ID and health/test logs exist. Hosted workflow URL, registry digest, and screenshots are missing. A browser screenshot of Swagger was not captured because the localhost browser origin approval was declined. |
| Backup/restore evidence and API test output. | Complete | Test, backup/restore, and recovery logs plus Trivy JSON are in docs/evidence. |
| 3–5 minute demo of pipeline, deployment, health/logs and failure/recovery or restore. | Missing | The demo script is prepared, but a recording/link has not been provided. |

## Submission form and rules

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Candidate full name, registration number and university email. | Missing | Candidate-specific fields must be supplied by the candidate in the official form. |
| Internship role and exact assigned project title. | Partially Complete | The assignment states DevOps & Cloud Engineering and Cloud Deployment & CI/CD – E-Commerce Platform; the candidate still needs to enter and confirm these in the form. |
| Repository URL, primary branch, final commit ID and reviewer access if private. | Partially Complete | Local branch is main and the source project exists. There is no remote or reviewer access. Record the final local commit after review, then add the chosen repository URL. |
| Video link or local-only demo declaration. | Missing | Record and link the demo, or use the form's local-only option if allowed. |
| README/report and architecture/schema diagram links. | Partially Complete | Files exist locally; reviewer-accessible links depend on repository publication. |
| Technology, setup notes and known limitations. | Complete | README, architecture and verification report describe the stack, setup and limits. |
| AI tools, purpose, dataset/library/source attribution. | Partially Complete | README discloses ChatGPT assistance and synthetic demo data. Complete the official form's exact fields. |
| Originality, ability to explain the code, no sensitive data/secrets, and working links. | Partially Complete | .env is ignored and untracked and no secrets were printed or committed in this work. The candidate must rotate previously exposed credentials, review/explain the code, and verify final links before declaring. |
| Role-specific pipeline/deployment/image/architecture/backup evidence. | Partially Complete | Local deployment, image ID, architecture and backup evidence exist; hosted pipeline URL and registry digest remain pending. |
| Keep the reviewer-accessible repository, report and video links working. | Missing | No public/private reviewer links or video link exist yet. |
| Use the candidate's own free-tier/local environment. | Complete | Verification ran against the candidate's local Docker Desktop environment; no paid cloud environment was used. |
| Prepare for the 15-minute walkthrough and 10-minute live change/debugging task. | Missing | Candidate preparation and walkthrough remain outstanding. |
| Submit a correct MVP and state unfinished features. | Complete | The project documents that storefront, payment processing, live cloud/TLS deployment and PostgreSQL concurrency stress testing remain outside verified scope. |

## Evaluation rubric crosswalk

| Rubric category | Status | Remaining gap |
|---|---|---|
| 20 - Containerization and reproducibility | Partially Complete | No-cache build and non-root runtime passed; Debian repository inputs are not snapshot-pinned and strict Trivy findings remain. |
| 20 - CI/CD automation | Partially Complete | Workflow is linted and configured; hosted execution and versioned registry artifact await a repository. |
| 15 - Deployment, networking and security | Partially Complete | Local reverse proxy, private ports and HTTPS example exist; no live TLS endpoint, external secrets manager, or credential rotation evidence. |
| 15 - Observability and troubleshooting | Complete | Health/readiness, structured request logs, and a passed failure/recovery drill are documented. |
| 15 - Backup, restore and rollback | Complete | Isolated database restore and rollback instructions are documented; production-data restore was intentionally not attempted. |
| 10 - Reliability and documentation | Complete | Runbook, architecture, configuration and local evidence are present; onboarding on a new machine remains untested. |
| 5 - Domain API correctness | Complete | Ten automated tests and isolated endpoint checks passed; PostgreSQL concurrency stress testing remains a limitation. |

## Candidate actions still required

1. Rotate the database password and admin token that were exposed earlier. Do this privately in the local .env and update any intended deployment secret store before sharing or recording; no credential was changed here.
2. Choose the GitHub account, repository name and visibility. After reviewing the local changes, add that remote and push only when ready. No repository or remote was created and nothing was published.
3. Run the workflow in the chosen GitHub repository, then record its URL, published version tag and registry digest. Keep the local image ID distinct from a registry digest.
4. Capture the Swagger/local deployment screenshot after granting the browser origin permission, or capture it directly on the laptop. The browser approval gate declined access during this run; no workaround was attempted.
5. Record the 3–5 minute demo and complete candidate-specific form fields, declarations and AI attribution. Prepare for the walkthrough and live debugging task.
6. Decide how to address the 47 high-severity Debian package findings that Trivy currently lists without a fix version; refresh the base image/scan when vendor fixes become available. The strict scan did not pass its high/critical threshold.

The assignment's 15-day schedule is advisory. The supplied document does not include the individualized invitation's issue date/time or deadline.
