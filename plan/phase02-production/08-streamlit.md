# 08 — Streamlit app (DEV)

**Goal:** a dashboard and an "Ask the data" chat on gold, deployed from git.

**Achieves:** `SNOWLAB_DEV.APP.SALES_DASHBOARD` (Streamlit in Snowflake, warehouse runtime): filters, KPIs, charts, top products; a Cortex Analyst chat tab (`_snowflake.send_snow_api_request` → `SALES_SV`); deployed by CI with `snow streamlit deploy`.

**Why before step 9:** the AI use case's output is shown in this app.

| Item | Decision |
|---|---|
| Project | `streamlit/snowflake.yml` (definition v2), db/warehouse templated from env (default DEV) |
| Deploy | `pipeline.yml`: pinned `snowflake-cli` via pipx, temporary connection (`-x`) as the deploy user; then `GRANT USAGE` to `ANALYST` |
| Queries | Read `GOLD.FCT_SALES` only; filters as bind parameters; cached 10 min |
| Ask tab | Chat history in Analyst message format; renders text, SQL (+ result, + chart for 2 columns), suggestions |

## Done when
- [ ] CI deploys the app; `SHOW STREAMLITS` shows owner `TRANSFORMER`.
- [ ] App SQL reconciles with gold (917 orders / 357,620.05 for day 1, completed).
- [ ] **You** open the app URL and confirm both tabs render (no browser access from CLI).

## As built (2026-10-08)

- `runtime_name: SYSTEM$WAREHOUSE_RUNTIME` pinned: Snowflake defaulted to the container runtime, which has no `_snowflake` module.
- `environment.yml` pins `streamlit=1.52.2` (default warehouse-runtime Streamlit had no `st.chat_input`).
- Ask tab runs generated SQL only if it is a single `SELECT`/`WITH`, through the cached query helper (review-01 R7).
- UI verified by you: dashboard renders, chat answers; out-of-range dates return empty (data covers 2026-01-01..07).
