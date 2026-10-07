# 09 — Cortex AI use case (DEV)

**Goal:** an AI-generated insight produced by the pipeline and shown in the app.

**Achieves:** `GOLD.DAILY_SALES_NARRATIVE`, a 3-sentence manager summary per day written by Cortex `AI_AGG`; incremental dbt model (each day summarised once); shown in the dashboard.

**Why before step 10:** completes the end-to-end use case that step 10 runs over 7 days.

| Item | Decision |
|---|---|
| Function | `AI_AGG`. **Trial accounts block** `AI_COMPLETE`, `COMPLETE`, `AI_CLASSIFY`, `SENTIMENT`, `SUMMARIZE`, `TRANSLATE`, `AI_EXTRACT`, `AI_FILTER`; only `AI_AGG` / `AI_SUMMARIZE_AGG` work |
| Accuracy | All numbers computed in SQL (totals, margin %, top channel/category, refund share); the LLM only phrases them. The first version let the LLM aggregate and it invented totals |
| Cost | Incremental on `order_date`: only new days call the LLM. `--full-refresh` regenerates |
| Deploy | Part of `dbt build` in `pipeline.yml`; the app reads the table (from step 8) |

## Done when
- [ ] Summary numbers match gold exactly (day 1: 357,620.05 AUD, 917 orders, 37.6%, web, Home).
- [ ] CI builds it; new days add rows without regenerating old ones.

## As built (2026-10-08)

- Incremental filter is `order_date not in (select order_date from this)` so late-arriving days are summarised (review-01 R5).
