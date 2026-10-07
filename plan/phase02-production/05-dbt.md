# 05 — dbt: silver and gold (DEV)

**Goal:** bronze becomes analytics-ready gold through version-controlled dbt models.

**Achieves:**
- dbt project (`dbt/`), runnable locally with dbt Fusion as the DEV deploy user.
- Silver views: latest file per dimension feed; latest file per day for transactions; `_file_date` derived from the path.
- Gold tables: `FCT_SALES` (wide intermediate) and `AGG_DAILY_SALES` (completed sales by day/channel/category).

**Why before step 6:** CI can only automate a project that builds locally.

---

| Item | Decision |
|---|---|
| Identity | `SNOWLAB_DEV_DEPLOY_SVC` / `SNOWLAB_DEV_TRANSFORMER`, key-pair. Same as CI |
| Profile | `dbt/profiles.yml` committed, all values from env vars. Locally a gitignored `dbt/.env` |
| Schemas | `generate_schema_name` macro uses `SILVER`/`GOLD` exactly (no `<target>_` prefix) |
| Names | Model files `slv_*.sql` with `alias` → `SILVER.TRANSACTION` etc. (dbt needs unique model names) |
| Silver | Views over the `bronze` source. No joins, no business rules |
| Gold | `table` materialization. Business rule `is_completed` lives here. Future grants give `ANALYST` read access automatically |
| Tests | Minimal (DQ deferred): `unique` + `not_null` on `FCT_SALES.transaction_id` |

## Done when

- [ ] `dbt build` passes locally against DEV.
- [ ] Silver counts equal bronze for day 1; `FCT_SALES` = 1006 rows; `AGG_DAILY_SALES` net revenue = completed sum in `FCT_SALES`.
- [ ] `ANALYST` can read gold.
- [ ] Committed and pushed; gotcha.md and cheatsheet updated.

## As built (2026-10-08)

- Silver keeps the latest load per file as well as the latest file (review-01 R4).
- `dbt/.env.example` committed (was hidden by the `.env.*` ignore rule).
