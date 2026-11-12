# Assignment compliance checklist

Compared with the complete text of the attached assignment, `07_Cloud_Deployment_and_CI_CD_E_Commerce_Platform.docx`. The attachment was DOCX, although it was described as a PDF. Its text and tables were extracted and reviewed; visual page rendering was unavailable in this environment.

The assignment’s business scope, technical expectations, acceptance tests, submission package, evaluation weights, and submission rules are treated as requirements. Its 15-day schedule is presented as guidance, not a personalized deadline. “Complete” means the project contains the requested capability and there is relevant verification evidence; “Partially Complete” means some work exists but a test, deployment, artifact, or user-specific step is outstanding; “Missing” means the artifact or action does not exist yet.

## Product and order requirements

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Build a small product and order API rather than a storefront or marketplace. | Complete | FastAPI service exposes catalog and checkout functions; README states storefront and payments are out of scope. |
| Provide health/readiness, product search/details, and order creation. | Complete | Routes exist and passed earlier local smoke checks; a fresh post-change smoke run is pending Docker access. |
| Validate availability and quantity, snapshot price and product details, and prevent negative stock. | Complete | Checkout validates stock in a transaction and saves item snapshots; earlier API tests covered stock rejection and price snapshots. |
| Make repeated order creation idempotent. | Complete | `Idempotency-Key`, request hash, and unique constraint are implemented; earlier tests covered exact retry and conflicting reuse. PostgreSQL concurrent behavior still needs a dedicated concurrency test. |
| Protect and audit admin product/stock changes. | Complete | Admin routes require a non-empty configured token and create audit events; earlier API tests covered denied access and audit records. |
| Include seed products and a simple order status endpoint. | Complete | Idempotent demo seed script and order lookup/status transitions exist; three missing demo products were added to the local database previously without replacing existing SKUs. |

## Technical expectations

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Keep the service domain-specific and small. | Complete | Product, order, admin, and audit API only; no payment or storefront dependency. |
| Use a secure, reproducible Dockerfile, non-root where practical, and avoid unnecessary layers/dependencies. | Partially Complete | Runtime uses a slim Python base and a non-root user. Base-image tags are mutable, and a clean rebuild after the latest edits could not be checked. Pin base images by digest and verify a clean build for stronger reproducibility. |
| Orchestrate app and database with persistent storage and health checks. | Partially Complete | Compose has private API/database networking, health checks, and a named persistent database volume. Compose validation and current health could not be rerun after changing required secret handling. |
| Run formatting/lint/static checks, tests, and build an image on PR/push; publish versioned tags without broad secrets. | Partially Complete | Workflow now runs Ruff lint/format, tests, dependency audit, and builds/scans on PR/push. A separate tag-only job has `packages:write` and publishes semantic-version/SHA/latest tags. Remote GitHub Actions and image publication are unverified because no remote is configured. Core Actions still use release tags rather than full commit SHAs. |
| Demonstrate local VM/container deployment, reverse proxy, and HTTPS configuration. | Partially Complete | Local Compose/Nginx deployment and a Linux host-Nginx/Certbot example exist. No VM, controlled domain, certificate, or public HTTPS endpoint has been deployed. |
| Use environment-based configuration, least privilege, secret handling, and restricted network exposure. | Partially Complete | `.env` is ignored and untracked; Compose now requires non-empty database/admin secrets and does not expose API/DB host ports. URL building safely encodes punctuation. Credentials were exposed in the earlier conversation and should be rotated before sharing/deployment; no cloud secret manager is configured. |
| Add dependency/container scanning where feasible. | Partially Complete | CI now runs `pip-audit` and Trivy for high/critical image vulnerabilities. Those scans could not be executed here; any findings or clean result remain unknown. |
| Provide health/readiness, structured logs, actionable troubleshooting; metrics are a stretch goal. | Complete | Liveness/readiness and JSON request logs with request IDs exist; the runbook describes diagnosis. Metrics are not implemented and are an optional stretch item. Earlier live health checks passed. |
| Demonstrate backup/restore, restart/recovery, and document rollback. | Partially Complete | Backup/restore scripts, explicit restore guard, persistent-volume recovery, image rollback instructions, and a safe Nginx recovery drill script exist. The recovery drill and disposable-database backup/restore rehearsal were not executable from this session. |
| Include deployment configuration and a reproducible runbook. | Complete | Compose, Nginx examples, README, architecture notes, and operations runbook exist. New documentation changes passed whitespace checks; runtime validation remains pending. |

## Acceptance tests

| Acceptance requirement | Status | Evidence and remaining work |
|---|---|---|
| Reusing an idempotency key does not duplicate orders or deduct stock twice. | Complete | Earlier API suite passed the exact retry and key-conflict cases. PostgreSQL concurrency remains outside SQLite test coverage. |
| A clean environment can build/start from the documentation. | Partially Complete | README documents prerequisites and commands; a fresh-machine setup was not run. Latest Compose edits need a Docker-enabled validation. |
| CI runs checks/tests and produces a versioned image artifact. | Partially Complete | Workflow is configured, but it cannot run until a GitHub repository/remote exists and a version tag is pushed. No pipeline run or digest is available. |
| Show health/readiness and logs; deliberately fail a service and show detection/recovery. | Partially Complete | Health and JSON logging exist; `scripts/failure-recovery-check.ps1` safely stops/restarts only Nginx and checks recovery. It was not run because Docker access was rejected. A recording remains to be made. |
| Restore a backup or show rollback procedure with evidence. | Partially Complete | Rollback is documented. Backup/restore scripts are present, but the requested rehearsal/evidence is still pending. |

## Submission package and evidence

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Repository source, Dockerfile, Compose/orchestration, CI, and deploy configuration. | Complete | All are present in this local project. No GitHub publication has been performed. |
| README build/run/deploy instructions, environment variables, port map, and rollback. | Complete | README now includes setup prerequisites, variable/port tables, and rollback steps. Recheck in a browser after any deployment-specific edits. |
| Architecture/schema diagram and operations runbook for deploy/restart/logs/backup/restore/incident response. | Partially Complete | Architecture diagram and runbook are present; the runbook now includes incident response. Architecture/schema links are local project files, not public reviewer links. |
| Pipeline URL/screenshot, image tag/digest, deployment/health evidence. | Missing | Requires a chosen GitHub repository/account, remote, successful hosted workflow, version-tag publication, and deployment target or accepted local-only proof. |
| Backup/restore evidence and API test output. | Partially Complete | Earlier API suite passed 8 tests; two configuration-focused tests were added but not rerun. Backup/restore rehearsal is pending. |
| 3–5 minute demo showing pipeline, deployment, health/logs, and failure recovery or restore. | Missing | The demo script is prepared; a human must record the walkthrough and provide its link, or declare local-only proof if permitted. |

## Submission form and declarations

| Requirement | Status | Evidence and remaining work |
|---|---|---|
| Candidate full name, registration number, and university email. | Missing | Candidate-specific details were not provided and should be entered by the candidate in the official form. |
| Internship role and exact project title. | Partially Complete | Project title is documented as “E-Commerce Product and Order API”; confirm the exact role/title wording from the individual invitation. |
| Repository URL, branch, final commit ID, and reviewer access if private. | Partially Complete | Local branch is `main`; there is no remote. The final local commit can be cited after review. Repository URL and reviewer access require the candidate’s chosen GitHub account/repository. |
| Video/demo link or local-only declaration. | Missing | Needs the candidate’s recording/link or the form’s local-only option. |
| README/report and architecture/schema diagram links. | Partially Complete | Files exist locally; convert them to reviewer-accessible repository links after publication. |
| Tech stack, setup, and known limitations. | Complete | README and architecture/runbook cover stack, setup, SQLite-vs-PostgreSQL concurrency limits, and operational limitations. |
| AI tools, purpose, dataset, library, and source attribution. | Partially Complete | README discloses ChatGPT assistance and synthetic demo data; complete the official form’s exact AI/dependency/source fields. |
| Originality/explainability, no sensitive data, and working links declarations. | Partially Complete | Project docs disclose AI assistance and known limits; `.env` is ignored/untracked. Candidate must review/explain the work, rotate previously exposed credentials, and verify final public/private links before declaring. |
| Role-specific pipeline/deployment/image/architecture/backup evidence. | Partially Complete | Architecture and local deployment proof exist; pipeline URL, image digest, and backup/restore rehearsal evidence remain pending. |

## Evaluation rubric crosswalk

| Weight/category | Status | Main remaining gap |
|---|---|---|
| 20 — Containerization and reproducibility | Partially Complete | Mutable base-image tags and no clean rebuild after current changes. |
| 20 — CI/CD | Partially Complete | Workflow configured but no remote run or versioned registry artifact. |
| 15 — Deployment, network, and security | Partially Complete | Local private networking and HTTPS example exist; no live VM/TLS deployment, secret manager, or credential rotation evidence. |
| 15 — Observability and troubleshooting | Complete | Health/readiness, request logs, and incident runbook exist; metrics are optional. |
| 15 — Backup, restore, and rollback | Partially Complete | Scripts/runbook exist; isolated restore rehearsal and evidence remain. |
| 10 — Reliability and documentation | Partially Complete | Docs are extensive; clean-environment and recovery/backup execution need verification. |
| 5 — Domain API correctness | Complete | Earlier automated API tests and live smoke checks passed; PostgreSQL concurrency testing remains a stated limitation. |

## Candidate actions still required

1. Run the Docker validation, test suite, dependency/image scans, recovery drill, and disposable-database backup/restore rehearsal in a session with Docker Desktop access. Do not restore against the existing assignment database.
2. Rotate the previously exposed database password and admin token before sharing, deploying, or recording. Keep replacement values private in `.env`.
3. Choose the GitHub account/repository and whether it is private; then add the remote, push the reviewed local commit, and verify reviewer access. Nothing has been published.
4. After a successful hosted workflow, record its URL, image tag/digest, and a screenshot; deploy to an approved VM/domain if that is part of the candidate’s submission.
5. Record the demo and complete candidate-specific form fields and declarations. Verify all reviewer links and confirm the exact role wording from the invitation.

The assignment’s suggested 15-day schedule is advisory. No individualized deadline was included in the attachment, so the candidate should follow the date in their own invitation.
