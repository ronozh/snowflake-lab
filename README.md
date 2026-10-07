# snowflake-lab

A production-pattern data platform on Snowflake, built entirely from code.

```
files ─▶ S3 (landing) ─▶ Snowpipe ─▶ BRONZE ─dbt─▶ SILVER ─dbt─▶ GOLD ─▶ semantic view · Streamlit · Cortex
```

| Path | Purpose |
|---|---|
| `bootstrap/` | Run-once setup a human does with admin rights: Terraform state bucket, Snowflake `TERRAFORM_SVC` |

More layers are added step by step.

## Prerequisites

AWS CLI (SSO profile), Terraform ≥ 1.10, Snowflake CLI (`snow`), `gh`, `jq`.

## Security

- Public repo: no secrets, keys, state or account-specific config are committed.
- Account-specific values live in gitignored `backend.hcl` / `*.tfvars` locally, and in GitHub variables/secrets in CI.
