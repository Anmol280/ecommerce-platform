# Gitleaks findings review

Reviewed 2026-11-13 at commit `47b776c9c1265c6d052a0b9147c06f05c4ac502a` with Gitleaks v8.30.1. History mode scanned all five commits; directory mode scanned the current project. Both produced 16 candidates. After normalizing the directory scan's `/repo/` prefix, all 16 history candidates match the current directory candidates by file, rule, and location. The scan report used a custom template that emitted only path, commit, rule, and location metadata; matched text and secret fields were not emitted or saved.

## Classification totals

| Classification | Count |
|---|---:|
| Confirmed live credential/secret | 0 |
| Historical credential or revoked secret | 0 |
| False positive | 16 |
| Test/example placeholder | 0 |
| Uncertain — requires manual review | 0 |

All findings use Gitleaks rule `generic-api-key`. They occur only in generated Trivy JSON image-scan reports. The matched spans are the `GPG_KEY` value in the Python base image's build metadata. The image history shows that this identifier is used to obtain a public signing key and verify the Python source archive. This is public signature-verification metadata, not a credential. The same 16 matches appear in the current files and commit history; there are no Gitleaks candidates in application code, configuration, tests, or `.env`.

## Per-finding classification

| File path | Commit identifier | Finding type/rule | Classification | Recommended action |
|---|---|---|---|---|
| `docs/evidence/trivy-image-scan-before-api-rebuild.json` | `47b776c9c1265c6d052a0b9147c06f05c4ac502a` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-before-api-rebuild.json` | `47b776c9c1265c6d052a0b9147c06f05c4ac502a` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-before-pip-upgrade.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-before-pip-upgrade.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-before-base-patch.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-before-base-patch.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-ci-policy.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-ci-policy.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-before-runtime-prune.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-before-runtime-prune.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-full.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-full.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-strict.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |
| `docs/evidence/trivy-image-scan-strict.json` | `113efae9a7c72f543ffc3aa780cc711947a400bc` | Gitleaks `generic-api-key` | False positive | Retain the scan evidence; no credential revocation is needed for this finding. |

## Credential and publication status

No confirmed credential was found in the tracked files or Git history by this scan. `.env` remains ignored and untracked. The database password and admin token previously exposed in conversation are separate from these findings; they remain unrotated and should be rotated through an approved process before public publication.

The repository contents can proceed to a **private staging** repository with `.env` kept excluded. No remote, repository, push, or image publication was created here. **Public publication is not ready:** rotate the previously exposed credentials through an approved process. The rebuilt image's strict Trivy scan is complete and fails; its 47 HIGH runtime findings have a temporary acceptance for local/private assignment preparation through 2026-12-13, not public production use. See `docs/verification-report.md` for the candidate comparison and review trigger.
