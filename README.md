# snowflake-lab

A production-pattern data platform on Snowflake, built entirely from code. DEV only for now.

```
data/sample ─ingest/upload.sh─▶ S3 landing (versioned) ─S3 event─▶ Snowpipe ─▶ BRONZE (tables, mirror landing 1:1)
                                                                                │ dbt (GitHub Actions: push / daily / manual)
                                                                                ▼
                                       SILVER (views: latest file) ─▶ GOLD (FCT_SALES, AGG_DAILY_SALES,
                                                                            DAILY_SALES_NARRATIVE via Cortex AI_AGG)
                                                                                │
                                         semantic view GOLD.SALES_SV ─▶ Cortex Analyst ◀─ Streamlit "Ask the data"
                                                                       Streamlit dashboard (APP.SALES_DASHBOARD)
```

**Tutorial:** [doc/tutorial](doc/tutorial/README.md) (architecture, Terraform, dbt, Cortex AI, Streamlit, Snowsight walkthrough).

## Layout

| Path | What | Deployed by |
|---|---|---|
| `bootstrap/` | Run-once: Terraform state bucket, Snowflake `TERRAFORM_SVC` + `TERRAFORM_WH` | You (admin), once |
| `terraform/aws` | Budget + alerts, GitHub OIDC + CI role, landing bucket | `terraform.yml` |
| `terraform/snowflake/account` | Account monitor, Cortex cross-region | `terraform.yml` |
| `terraform/snowflake/env` | Per env: warehouse, database/schemas, roles, deploy user, S3 integration, stage, bronze, Snowpipes, `RELOAD_FILES` | `terraform.yml` |
| `dbt/` | Silver views, gold tables, AI narrative, semantic view macro | `pipeline.yml` |
| `streamlit/` | Dashboard + Cortex Analyst chat | `pipeline.yml` |
| `ingest/upload.sh` | Upload sample days to S3 | You |
| `data/sample/` | 7 days of synthetic e-commerce files | — |
| `doc/tutorial/` | How it all works, topic by topic | — |
| `scripts/` | CI helper, secret sync, GitHub hardening, `ask.sh` (Cortex Analyst), `nuke.sh` | You / CI |

## Run

```bash
export AWS_PROFILE=<admin-sso-profile>
ingest/upload.sh dev 2026-01-01 2026-01-07          # files -> S3 -> Snowpipe -> bronze (~1 min)
gh workflow run pipeline                            # dbt build + semantic view + app (also daily at 20:00 UTC)
scripts/ask.sh "What was net revenue by channel?"   # Cortex Analyst
```

Infrastructure changes: edit `terraform/**`, push to `main` → CI applies. Corrections to a landed file:
overwrite it in S3, then as `SYSADMIN`: `CALL SNOWLAB_DEV.BRONZE.RELOAD_FILES('<feed>', '.*<feed>/<date>/.*[.]csv')`.

## Security (public repo)

- No secrets, keys, state, tfvars or account identifiers in git. Local config lives in gitignored `backend.hcl`, `*.tfvars`, `.env`; CI gets it from GitHub secrets (`scripts/sync-ci-secrets.sh`).
- AWS via GitHub OIDC (immutable subject; only jobs in the `dev` environment, which deploys from `main` only). Snowflake via key-pair `TYPE = SERVICE` users.
- Actions allowlist + SHA pinning, read-only default token, fork-PR approval, `dev` environment limited to `main`. Logs never print plans.

## Prerequisites

AWS CLI (SSO), Terraform ≥ 1.10, Snowflake CLI, dbt Fusion, `gh`, `jq`.
