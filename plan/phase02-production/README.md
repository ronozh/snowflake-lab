# Phase 02 — production pattern

Public repo `github.com/ronozh/snowflake-lab`. Raw files land in S3; every layer from
bronze to gold, the semantic view, Streamlit and Cortex lives in Snowflake.
Everything is built from code.

**Working method:** one step at a time. For each step, write a detailed plan
(`NN-<step>.md`), get it reviewed, build it, verify against its *done-when*, then move on.

## Target shape

```
GitHub (public) ── Actions ──OIDC──▶ AWS (no keys)      key-pair secret ──▶ Snowflake
   │                                   │                                        │
   ├ terraform/aws        ───────────▶ budget, state, CI roles, landing bucket  │
   ├ terraform/snowflake  ─────────────────────────────────────────────────────▶ roles, WH, DBs (DEV/PROD),
   │                                                                             integration, stage, bronze, pipes
   ├ ingest/   files ──▶ s3://<landing>/<env>/ecommerce/<feed>/<date>/ ──event──▶ Snowpipe ──▶ BRONZE
   ├ dbt/      ─────────────────────────────────────────────────────────────────▶ SILVER views ▶ GOLD tables
   ├ semantic/ ─────────────────────────────────────────────────────────────────▶ semantic view ▶ Cortex Analyst
   └ streamlit/ ────────────────────────────────────────────────────────────────▶ dashboard + "Ask the data"
```

## Settled decisions

| Area | Decision |
|---|---|
| Repo | One public monorepo. `plan/phase02-production/` is published; `cheatsheet/`, `gotcha.md` and `plan/phase01-manual/` stay local. Solo dev: push straight to `main`, no branch protection or PRs (add later if collaborators join) |
| Environments | `dev` and `prod`: two Snowflake databases in one account, two S3 prefixes. **DEV only until the whole end-to-end is accepted**; PROD is then created and deployed in one go (step 11) |
| Identities | AWS via GitHub OIDC (no keys; immutable `sub`, `environment:dev` only). Snowflake via `TYPE = SERVICE` users with key-pair auth; keys only in GitHub `dev` environment secrets |
| Terraform state | New private, versioned S3 bucket with native locking (`use_lockfile`) |
| Ingestion | S3 external stage + storage integration + Snowpipe auto-ingest into bronze (EL). dbt starts at bronze (T). Snowpipe loads only on S3 events, never rescans; history and missed files use a bulk `COPY` with the pipe's SQL |
| Transform | dbt Fusion (pinned 2.0.6), locally and in GitHub Actions (`pipeline.yml`: push, daily 20:00 UTC, manual) |
| Layers | landing (S3, versioned) → bronze (tables, **mirrors landing 1:1 per file**, typed, provenance) → silver (views, latest file per date) → gold (tables) |
| Corrections | Bronze is **append-only per file** and mirrors landing 1:1. A wrong file is overwritten in S3 (versioning keeps the audit trail), then `RELOAD_FILES(feed, pattern)` (as SYSADMIN) loads it with forced `COPY` and removes older loads of the same file, in one transaction; silver also keeps only the latest load per file. No row-level edits. Full rebuild only for disasters |
| Cost | AWS budget $30/mo (60/90% actual, 100% forecast, via SNS email). Snowflake monitors: account 50, DEV 10 credits/mo (warehouses only, not serverless). XS warehouses, 60s auto-suspend |

## Steps

| # | Step | Builds | Done when | Status |
|---|---|---|---|---|
| 0 | **[Repo and bootstrap](00-repo-bootstrap.md)** | Repo, `.gitignore`, secret scanning + push protection; `bootstrap/aws` state bucket; Snowflake `TERRAFORM_SVC` + `TERRAFORM_WH` | Repo pushed; push protection on; state in S3; `snow`/`aws` work as the right identities | Done |
| 1 | **[AWS foundation (TF)](01-aws-foundation.md)** | Budget + SNS alerts; GitHub OIDC + `snowflake-lab-ci` role (`environment:dev` only); landing bucket | Plan clean; alert emails confirmed; bucket checks pass | Done |
| 2 | **[Snowflake foundation (TF)](02-snowflake-foundation.md)** | `account` stack (account monitor, Cortex cross-region) + per-env `env` stack: warehouse + monitor, `SNOWLAB_DEV` + 5 schemas, `ANALYST`/`TRANSFORMER`, `DEPLOY_SVC` | Plans clean; role isolation tests pass (`USE SECONDARY ROLES NONE`) | Done (PROD destroyed; DEV only) |
| 3 | **[CI for Terraform](03-ci-terraform.md)** | `terraform.yml`: validate → `dev` job applies `aws` → `account` → `env(dev)`; hardening (allowlist, SHA pins, read-only token, fork approval, `dev` env from `main` only, pipefail); public-log-safe `tf-apply.sh` | CI applies a real change; no log leaks; disallowed action rejected | Done |
| 4 | **[File integration (TF + ingest)](04-file-integration.md)** | Integration ↔ IAM role (one apply, own external ID); stage; file format; bronze tables (provenance incl. checksum); 4 Snowpipes + S3 notification; `RELOAD_FILES`; sample data + `ingest/upload.sh` | Day 1 lands in ~1 min, counts = `.ctrl`; reload swaps rows with no duplicates | Done |
| 5 | **[dbt: silver and gold](05-dbt.md)** | Silver views (latest file / latest load per file); gold `FCT_SALES`, `AGG_DAILY_SALES`; tests: `unique`/`not_null` on `transaction_id` (DQ deferred) | `dbt build` passes; gold reconciles | Done |
| 6 | **[CI for dbt](06-ci-dbt.md)** | `pipeline.yml`: dbt build on push / daily / manual, as `DEPLOY_SVC` | Push, schedule and manual runs succeed; no leaks | Done |
| 7 | **[Semantic view + Cortex Analyst](07-semantic-view.md)** | `GOLD.SALES_SV` (dbt macro, deployed by CI); `scripts/ask.sh` | `SEMANTIC_VIEW()` matches gold; Analyst answers reference questions | Done (verified queries not persisted yet) |
| 8 | **[Streamlit](08-streamlit.md)** | `SALES_DASHBOARD` (warehouse runtime, Streamlit 1.52.2): dashboard + Cortex Analyst chat; deployed by CI | App renders; chat answers; KPIs reconcile | Done |
| 9 | **[Cortex AI use case](09-cortex-ai.md)** | Daily sales narrative with `AI_AGG` (trial blocks `AI_COMPLETE`); numbers computed in SQL; incremental | Numbers match gold; shown in app | Done |
| 10 | **[Run it and harden (DEV)](10-run-harden.md)** | 7 days end to end; `nuke.sh`; README; tutorial (`doc/tutorial`); independent code + doc reviews | Bronze = `.ctrl`; gold reconciles; reviews addressed | Done (nuke dry-run only) |
| 11 | **Promote to PROD** | Move S3 bucket notification to a shared stack; add `prod` to CI role trust + GitHub `prod` environment (approval, `main` only); re-apply `snowflake/env` for prod; `prod` jobs in both workflows; ingest to `prod/`. Decide review items R10 (checksums) and R11 (Cortex region) | Same done-when checks as DEV pass in PROD | Todo |

Reviews: [review-01.md](review-01.md) (code: 16 findings, 14 fixed, 2 deferred) · [review-02-docs.md](review-02-docs.md) (tutorial: 15 findings, all fixed).

## Order rationale

- **0–3 before any data:** identity, state, cost guardrails and CI come first, so every later change is deployed by CI.
- **4 before 5:** dbt needs bronze to read from.
- **7–9 after gold is stable:** the semantic view, app and AI all read gold.
- **DEV first, PROD last:** steps 3–10 deploy to DEV only. Step 11 adds PROD in one go: same code, a `prod` job after a manual approval in the `prod` environment.

## Out of scope (until it hurts)

Separate Snowflake accounts per environment · Airflow · Snowpipe Streaming · DCM
projects · data contracts · masking/row-access policies · SCIM user provisioning.
