# 07 — semantic view + Cortex Analyst (DEV)

**Goal:** ask questions of gold in plain English.

**Achieves:** `GOLD.SALES_SV` over `FCT_SALES` (dimensions, facts, metrics, synonyms), deployed by CI after `dbt build`; `ANALYST` can query it; `scripts/ask.sh` calls Cortex Analyst's REST API.

**Why before step 8:** the app's "Ask the data" tab calls Cortex Analyst with this semantic view.

| Item | Decision |
|---|---|
| Deploy | dbt macro `deploy_semantic_view` (`dbt run-operation`), a step in `pipeline.yml`. DDL in git; database from the target |
| Scope | Single table (`FCT_SALES`, already denormalised) |
| Metrics | Revenue/orders/margin count `completed` only (business rule); `transaction_count` = all statuses |
| Access | Owner `TRANSFORMER`; `GRANT SELECT, REFERENCES` to `ANALYST` (+ `CORTEX_USER` from step 2) |
| Gotcha | Customer tiers are named bronze/silver/gold; the dimension comment disambiguates |

## Done when
- [ ] CI deploys the semantic view.
- [ ] `SEMANTIC_VIEW()` query works as `ANALYST`.
- [ ] `scripts/ask.sh "What was net revenue by channel?"` returns SQL and the answer matches `AGG_DAILY_SALES`.

## As built (2026-10-08)

- Verified queries are **not persisted**: `CREATE OR REPLACE` on each run would wipe UI-added ones. Add them to the macro when needed.
- Facts are aliased `*_f` so metric expressions are unambiguous.
