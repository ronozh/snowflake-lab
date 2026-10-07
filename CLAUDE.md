# snowflake-lab

Production-pattern Snowflake project: S3 landing → Snowflake bronze/silver/gold → semantic view, Streamlit, Cortex. Public repo `ronozh/snowflake-lab`.

## Rules
- Responses: very concise, clear.
- Work step by step per `plan/phase02-production/README.md`. Each step: write `NN-<step>.md` (Goal / Achieves / Why before next step first) → review → build → verify → next.
- Never commit secrets, keys, state, tfvars, account-specific config. Public repo.
- Commit locally freely; push only when asked. Solo: push to `main`, no PRs.
- Keep `cheatsheet/` updated with every new command (once, explained).
- Log every error/issue + fix in `gotcha.md` (gitignored), concisely.

## Access
- AWS: `--profile dpivoted` (SSO admin, ap-southeast-2). Never root.
- Snowflake: `snow` connection `snowlab` (personal, key-pair). Use `--format JSON | jq`. Read-only unless asked.

## Layers
landing = S3 files (versioned = audit) · bronze = tables mirroring landing 1:1 per file, typed, provenance; append-only per file, corrections replace whole files (`RELOAD_FILES`) · silver = views, latest file · gold = business tables.
