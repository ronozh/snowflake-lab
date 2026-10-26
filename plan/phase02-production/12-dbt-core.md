# 12 — Switch dbt Fusion → dbt Core (DEV)

**Goal:** dbt runs on dbt Core, locally and in CI, with the same project.

**Achieves:**
- `dbt-core 1.12.6` + `dbt-snowflake 1.12.4`, pinned in `dbt/requirements.txt`.
- Local: project venv `dbt/.venv` (Python 3.13). CI: `pip install -r dbt/requirements.txt`.
- No model, macro or profile changes.

**Why before step 13:** Elementary is fully supported on Core. On Fusion it is beta and drops error tests, source freshness, compiled code and failed row counts.

---

| Item | Decision |
|---|---|
| Versions | Latest stable: `dbt-core==1.12.6`, `dbt-snowflake==1.12.4` (exact pins) |
| Python | 3.13 (system 3.15 is newer than dbt supports). CI: `actions/setup-python` (GitHub-owned, already allowed), pinned by SHA |
| Local | `uv venv dbt/.venv --python 3.13`; activate it so its `dbt` wins over Fusion's `~/.local/bin/dbt` |
| CI | Replace the Fusion `curl` installer with setup-python + pip |
| Unchanged | Models, macros, `dbt_project.yml`, `profiles.yml`, `.gitignore` (`.venv/` already ignored) |

## Done when

- [ ] `dbt --version` (venv) → Core 1.12.6, snowflake 1.12.4.
- [ ] `dbt build` and `dbt run-operation deploy_semantic_view` pass locally against DEV.
- [ ] CI `pipeline.yml` passes on Core.
- [ ] README, tutorial, plan README, cheatsheet updated; 05/06 note "superseded by step 12".
