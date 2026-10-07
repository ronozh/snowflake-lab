# 10 — run it and harden (DEV)

**Goal:** the whole pipeline proven over 7 days, with a clean way to tear it down.

**Achieves:** days 1–7 ingested and reconciled end to end; pipeline run from CI; Cortex Analyst multi-day questions; `scripts/nuke.sh` (reverse-order teardown incl. versioned buckets and state); repo README.

**Why before step 11:** PROD should be a copy of something proven, not an experiment.

## Results (2026-10-08)
- Bronze = `.ctrl` totals: transaction 9,919 · customer 8,409 · product 2,806 · campaign 126 (7 files each).
- Gold: `FCT_SALES` 9,919 rows, 7 days, 0 missing dims; `AGG_DAILY_SALES` = completed `FCT_SALES` (3,402,876.37 AUD).
- Narrative: 7 days, numbers match gold; day 1 not regenerated (incremental).
- Teardown: `--dry-run` verified (47 + 3 + 15 resources, landing, bootstrap, state). **Full nuke + rebuild not executed**: destructive; run when you choose.

## As built (2026-10-08)

- Added afterwards: tutorial `doc/tutorial/`, independent reviews `review-01.md` (code) and `review-02-docs.md` (tutorial).
