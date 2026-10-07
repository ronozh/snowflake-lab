# Review 02 — independent doc review of `doc/tutorial/` (2026-10-08)

Reviewer: separate agent, no shared context, read-only, every claim checked against the code. 15 findings, no security issues.

| ID | Sev | Finding | Agree? | Action | Verified by |
|---|---|---|---|---|---|
| D1 | High | `scripts/ci/tf-apply.sh` shown as a local check, but it **applies** changes | Yes | **Fixed**: commented out under "break-glass only (APPLIES changes; repo root, needs jq)"; prose says it applies | Re-read 02 |
| D2 | High | Cortex diagram said SQL runs as the caller's role; the app runs it as owner `TRANSFORMER`, `ask.sh` doesn't run it | Yes | **Fixed** diagram label | `streamlit_app.py` uses the owner's session |
| D3 | Med | `RELOAD_FILES` call missing database and role | Yes | **Fixed**: "as `SYSADMIN`: `CALL SNOWLAB_DEV.BRONZE.RELOAD_FILES(...)`" | Matches root README |
| D4 | Med | "Add as verified query" is lost on the next `CREATE OR REPLACE`, and ANALYST may not be able to save it | Yes | **Fixed**: playground = try only; persist in the macro (not implemented yet); UI edits overwritten | Macro uses `CREATE OR REPLACE` |
| D5 | Med | No setup for the deploy key or the `snowlab_dev_deploy` connection → dbt, `ask.sh` and Streamlit deploy fail on a fresh clone | Yes | **Fixed**: new "Setup: deploy key and connection" section in 03, linked from 04 and 05 | — |
| D6 | Med | Streamlit deploy mixes `uvx` and bare `snow`; no role, so a personal connection gives the wrong owner | Yes | **Fixed**: one pinned invocation with `--role SNOWLAB_DEV_TRANSFORMER --warehouse SNOWLAB_DEV_WH` | Same as `pipeline.yml` |
| D7 | Low | `FCT_SALES` rows "= bronze rows" is wrong after reloads | Yes | **Fixed**: "= SILVER.TRANSACTION rows" | Silver dedupes per file/load |
| D8 | Low | AI_AGG example made the LLM sum several rows (the anti-pattern doc 04 warns about) | Yes | **Fixed**: aggregate in a subquery first | — |
| D9 | Low | Trial-blocked function lists differ between 04 and 06 | Yes | **Fixed**: 06 links to 04's list | — |
| D10 | Low | Wrong reason given for the `slv_` prefix | Yes | **Fixed** wording (clarity; `alias` sets the relation name) | — |
| D11 | Low | `_src_file_modified` missing from the provenance list | Yes | **Fixed** | `ingestion.tf` provenance |
| D12 | Low | `COPY_HISTORY` table name only partly qualified | Yes | **Fixed**: `SNOWLAB_DEV.BRONZE.TRANSACTION` | — |
| D13 | Low | `SHOW RESOURCE MONITORS` needs ACCOUNTADMIN; `snow sql` had no `-c` | Yes | **Fixed**: `-c <conn>`; note `--role ACCOUNTADMIN` | — |
| D14 | Low | `nuke.sh` prerequisites not stated | Yes | **Fixed**: `AWS_PROFILE`, `SNOW_ADMIN_CONN`, `.env` shown | `scripts/nuke.sh` |
| D15 | Low | Workflow trigger paths incomplete | Yes | **Fixed**: terraform flow mentions `bootstrap/**`; dbt doc lists `dbt/**`, `streamlit/**` | Workflow `paths` |

**Summary:** 15/15 fixed. No findings rejected.
