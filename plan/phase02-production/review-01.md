# Review 01 — independent code review (2026-10-08)

Reviewer: separate agent, no shared context, read-only over tracked files. 16 findings.
Fixes in commits `6b9dd6f` and `a53d161`; CI (terraform + pipeline) green after both.

| ID | Sev | Finding | Agree? | Action | Verified by |
|---|---|---|---|---|---|
| R1 | High | `RELOAD_FILES` deleted by pattern, then loaded by pattern: a mismatch could delete without reloading (or duplicate) and still "succeed"; bad input `RETURN`ed instead of failing | Partly: `_src_file` and COPY's path are the same for this external stage (verified earlier), but delete-before-load is still fragile | **Fixed**: COPY first, then delete older loads of exactly the files just loaded (same `_src_file`); 0 files → rollback + raise; bad input raises | Reload day 1: loaded 1006 / removed 1006, total unchanged 9,919; no-match → error, nothing changed |
| R2 | Med | `snow streamlit deploy \| grep -v` with no `pipefail` could hide a failed deploy; `grep` exiting 1 could fail a good one | Yes | **Fixed**: `defaults.run.shell: bash` (→ `-eo pipefail`) in both workflows; `{ grep -v … \|\| true; }` | Pipeline run green |
| R3 | Med | Bronze future grant and table creation could run in parallel → TRANSFORMER can't read bronze after a fresh rebuild | Yes (real race on rebuild) | **Fixed**: tables `depends_on` the future grant; added `SELECT ON ALL TABLES` grant | CI applied (+1 grant) |
| R4 | Med | After 14 days Snowpipe *will* reload an overwritten file → duplicate rows per file in bronze/silver | Yes | **Fixed**: silver keeps the latest load per `_src_file` (second `QUALIFY` condition). RELOAD's "remove older loads" also cleans bronze | `dbt build` 9/9; `unique` test passes |
| R5 | Med | Narrative incremental `order_date > max()` skips days that land out of order | Yes | **Fixed**: `order_date not in (select order_date from this)` | `dbt build` green |
| R6 | Low | Pattern concatenated into COPY with only `'` doubled (backslash escapes) → injection under owner's rights; README didn't say which role can CALL | Yes | **Fixed**: allowlist regex `^[]A-Za-z0-9_./*[-]+$` before use; README says call as `SYSADMIN` | Injection attempt `'.*x'' FORCE=TRUE --[.]csv'` rejected |
| R7 | Low | App runs Cortex Analyst SQL with owner's role (TRANSFORMER); re-executes all history on every rerun | Yes | **Fixed**: only a single `SELECT`/`WITH` statement runs; results go through the cached `query()` | Unit check of guard (SELECT/WITH pass; DROP, multi-statement rejected); app redeployed |
| R8 | Low | CI trust allowed `environment:prod` (env doesn't exist yet → would be unprotected) and unused `ref:main` | Yes | **Fixed**: trust = `environment:dev` only; add prod with its branch policy in step 11 | CI applied (role updated) and still assumes it |
| R9 | Low | TERRAFORM_SVC key at job level → visible to third-party actions | Yes | **Fixed**: `SNOWFLAKE_*` env only on the two Snowflake tf steps (YAML anchor) | Terraform run green |
| R10 | Low | dbt Fusion via `curl \| sh`, snowflake-cli without hash pinning | Valid hardening | **Not addressed**: versions are pinned, sources are official; checksum plumbing adds maintenance for a lab. Revisit before PROD | — |
| R11 | Low | `CORTEX_ENABLED_CROSS_REGION = ANY_REGION` sends prompts outside AU | Valid for real data | **Not addressed now**: data is synthetic and the trial's available AI functions may need cross-region. Decide (e.g. `AWS_APJ`) at step 11 | — |
| R12 | Low | Comments implied resource monitors cap all spend | Yes | **Fixed**: comments say warehouses only; Snowpipe/Cortex serverless not capped | — |
| R13 | Low | Budget emailed directly *and* via SNS → duplicate alerts | Yes | **Fixed**: SNS only | CI applied (budget updated) |
| R14 | Low | `ask.sh` silent on API errors; no check for empty host/JWT | Yes | **Fixed**: `--fail-with-body`, input checks, prints error body | Bad semantic view → 404 + message shown |
| R15 | Low | `bootstrap/**` changes never trigger validation | Yes | **Fixed**: added to `terraform.yml` paths | — |
| R16 | Low | `*.tfvars.json` not ignored | Yes | **Fixed**: added to `.gitignore` | — |

**Summary:** 14 fixed (R1 adjusted after verifying the reviewer's premise), 2 deferred with reasons (R10, R11 → step 11).
