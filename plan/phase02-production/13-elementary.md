# 13 — Elementary: test results as data (DEV)

**Goal:** every `dbt build` records its test results (and run metadata) in Snowflake tables, using the Elementary dbt package.

**Achieves:**
- Elementary `0.26.1` (latest stable) installed via `dbt/packages.yml`, on dbt Core (step 12).
- New `SNOWLAB_DEV.ELEMENTARY` schema holding Elementary's tables and views.
- A clear model of what changes in those tables after one `dbt build` that runs a single test: a new `unique` on `slv_product.product_id`.

**Why before step 11:** PROD should start with result capture already in place, not have it added later.

---

| Item | Decision |
|---|---|
| Version | `elementary-data/elementary` pinned to `0.26.1` (exact pin, like dbt Core) |
| Schema | `ELEMENTARY`, owned by Terraform like the other schemas. Our `generate_schema_name` maps `+schema: elementary` to `ELEMENTARY` (no `SILVER_` prefix) |
| Grants | `TRANSFORMER`: `USAGE`, `CREATE TABLE`, `CREATE VIEW` on `ELEMENTARY`. `ANALYST`: none for now |
| Capture | The package's own `on-run-end` hook writes results. Nothing to add to our models |
| Test | New `models/silver/silver.yml`: `unique` on `slv_product.product_id` (402 rows, 402 distinct) |
| CI | `pipeline.yml` gets `dbt deps` before `dbt build`. `dbt_packages/` gitignored; `package-lock.yml` committed |
| dbt ≥ 1.8 | `macros/elementary_materialization.sql`: Elementary wraps the test materialization (required to capture results) |
| Rollout | Two pushes: (1) Terraform schema + grants, CI applies; (2) dbt changes. Avoids `pipeline.yml` racing `terraform.yml` |
| IAM drift found | S3 role had a hand-added trust for another project's Snowflake account. Codified as `extra_snowflake_trust` (values in gitignored tfvars + CI secret) |

## Build

1. Terraform (`terraform/snowflake/env`): add `ELEMENTARY` to `local.schemas`, plus the transformer grants. CI applies this on push to `main` (needs your go to push).
2. `dbt/packages.yml` → `dbt deps`; `dbt_project.yml`: `models: elementary: +schema: elementary`.
3. `dbt run --select elementary`: creates the empty Elementary tables.
4. **Snapshot "before":** list every object in `ELEMENTARY` with its row count.
5. `dbt build --select slv_product`: one model and exactly one test (`unique`).
6. **Snapshot "after":** row-count diff per table, and the new rows in the key tables (`dbt_invocations`, `dbt_run_results`, `elementary_test_results`, `dbt_tests`, `dbt_models`).
7. Write up the model: which table gets one row per build, per node, per test, per definition change.

## Done when

- [ ] `dbt build` passes locally and in CI with Elementary installed.
- [ ] `ELEMENTARY` objects listed; before/after diff explained table by table.
- [ ] One `unique` test result traced through `dbt_invocations` → `dbt_run_results` → `elementary_test_results`.
- [ ] Committed; cheatsheet and gotcha.md updated.
