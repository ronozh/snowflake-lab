# 06 — CI for dbt (DEV)

**Goal:** gold rebuilds itself: on every dbt change, on a daily schedule, and on demand.

**Achieves:** `.github/workflows/pipeline.yml` runs `dbt build` as `SNOWLAB_DEV_DEPLOY_SVC` in the `dev` environment, with pinned dbt Fusion.

**Why before step 7:** the semantic view and app read gold; gold must be refreshed by automation, not a laptop.

| Item | Decision |
|---|---|
| Triggers | push to `main` (`dbt/**`, workflow file), daily cron 20:00 UTC (~06:00/07:00 Sydney, after files land), `workflow_dispatch` |
| Install | Official Fusion installer with `--version` pinned to the local version (not an action, so the allowlist is unaffected) |
| Auth | `SNOWFLAKE_DEPLOY_PRIVATE_KEY` env secret → temp file (0600) → `DBT_SNOWFLAKE_PRIVATE_KEY_PATH`. Account from existing repo secrets |
| Later | Steps 7–9 append semantic view, Streamlit and AI steps to this same workflow |

## Done when
- [ ] Push runs `dbt build` successfully in CI.
- [ ] `workflow_dispatch` run succeeds; logs leak nothing.
- [ ] Committed and pushed; gotcha/cheatsheet updated.

## As built (2026-10-08)

- `pipeline.yml` also deploys the semantic view (step 7) and the Streamlit app (step 8, `snowflake-cli` 3.28.0 via pipx), with `bash` pipefail.
