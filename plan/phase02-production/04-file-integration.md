# 04 — file integration: S3 landing → Snowpipe → bronze (DEV)

**Goal:** files dropped in S3 land in typed bronze tables automatically.

**Achieves:**
- Per-env storage integration ↔ IAM role (read-only, `dev/` prefix only).
- External stage, CSV file format, 4 bronze tables with provenance columns.
- 4 Snowpipes (auto-ingest), with S3 → Snowpipe SQS event notification.
- `RELOAD_FILES(feed, pattern)` for corrections (bronze mirrors landing).
- Sample data (7 days) in the repo, plus an `ingest/upload.sh` script.

**Why before step 5:** dbt reads bronze. Bronze must fill itself from S3 before any transformation exists.

---

## Design

| Item | Decision |
|---|---|
| Where | `terraform/snowflake/env` gains the AWS provider. Everything per env lives in one state, so the integration and the IAM trust apply together |
| Trust | Integration created with **our own external ID** (`snowflake-lab-<env>`); IAM role trust reads Snowflake's IAM user from the integration's `describe_output`. One apply, no two-pass |
| IAM role | `snowflake-lab-<env>-snowflake-s3`: `s3:GetObject*` on `<bucket>/<env>/*`; `s3:ListBucket` limited to the `<env>/` prefix |
| Stage | `SNOWLAB_<ENV>.LANDING.ECOMMERCE` → `s3://<bucket>/<env>/ecommerce/` |
| Bronze tables | `snowflake_execute` running `CREATE OR ALTER TABLE` (in-place schema changes; revert is a no-op, so destroy never drops data). The table resource is preview-only |
| Provenance | `_src_file`, `_src_row_number`, `_src_file_checksum` (`METADATA$FILE_CONTENT_KEY`), `_src_file_modified`, `_loaded_at`. `_file_date` is derived in silver from the path, which keeps the COPY transform simple |
| Pipes | `snowflake_pipe` (preview): `AUTO_INGEST = TRUE`, `PATTERN = '.*[.]csv'`, `ON_ERROR = SKIP_FILE`. The COPY SQL is generated from one `feeds` map |
| Notification | `aws_s3_bucket_notification` with a `dev/` prefix → the pipes' SQS queue. It's a bucket singleton, so it moves to a shared stack at step 11 |
| `RELOAD_FILES` | SQL procedure (preview resource), `EXECUTE AS OWNER`: in one transaction, delete the rows from matching files, then `COPY ... FORCE = TRUE` with the same generated SQL |
| Data | `data/sample/ecommerce/<feed>/<date>/` for 2026-01-01..07 (synthetic, 2.6 MB). `ingest/upload.sh <env> <from> <to>` copies it to S3 |

## Done when

- [ ] CI applies the env stack (`aws`/`snowflake` resources), and local plan shows *No changes*.
- [ ] Uploading day 1 → all 4 bronze tables load within ~2 min; counts match `.ctrl` (1006 / 1200 / 400 / 18).
- [ ] Overwriting one file + `CALL RELOAD_FILES(...)` → that file's row count is unchanged, with no duplicates.
- [ ] Committed and pushed; gotcha.md and cheatsheet updated.

## As built (2026-10-08)

- `RELOAD_FILES` was redesigned (review-01 R1/R6): **load first** (`COPY ... FORCE`), then delete older loads of exactly the files just loaded; raises on no match, unknown feed or unsafe pattern (allowlist `^[]A-Za-z0-9_./*[-]+$`, must end `[.]csv`). Call as `SYSADMIN`.
- Bronze grants: tables depend on the future grant, plus a `SELECT ON ALL TABLES` grant (review-01 R3).
- Verified: Snowpipe does **not** reload an overwritten file within 14 days (dedupes by name); after 14 days it will, hence silver's latest-load-per-file rule (step 5).
