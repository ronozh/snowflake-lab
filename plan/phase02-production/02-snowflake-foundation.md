# 02 — Snowflake foundation (Terraform)

**Goal:** the Snowflake platform for DEV and PROD, built and owned by Terraform.

**Achieves:**
- Account-level settings and a hard credit ceiling, in code.
- Per environment: a warehouse with a resource monitor, a database with layer schemas, roles with least-privilege grants, and a deploy service user for CI.
- DEV and PROD are isolated: separate Terraform state, separate objects, and roles that can't cross over.

**Why before step 3:** CI needs Snowflake identities (deploy users) and targets (databases, warehouses) to deploy to. Steps 4–9 create objects inside these databases with these roles.

---

## 2.1 Layout: two stacks

```
terraform/snowflake/
├── account/                 # account-level singletons, one state (key snowflake/account.tfstate)
│   └── versions.tf  main.tf  variables.tf
└── env/                     # one config, applied per environment
    ├── versions.tf          # backend key passed at init: snowflake/<env>.tfstate
    ├── providers.tf         # aliases: sysadmin (default), securityadmin, accountadmin
    ├── warehouse.tf  database.tf  roles.tf  users.tf  outputs.tf  variables.tf
    └── env.tfvars.example   # real dev.tfvars / prod.tfvars gitignored
```

**Why two stacks:** account-level objects (account parameters, account-wide monitor) are singletons. If both env states managed them, the two states would fight over the same objects.

**Per-env state:** `terraform init -reconfigure -backend-config=../../backend.hcl -backend-config="key=snowflake/dev.tfstate"`, then `apply -var-file=dev.tfvars`. Destroying DEV can't touch PROD.

## 2.2 Provider and auth

| Item | Value |
|---|---|
| Provider | `snowflakedb/snowflake ~> 2.x` (exact minor pinned at build time; preview features only if a resource needs them) |
| Identity | `TERRAFORM_SVC`, key-pair (`SNOWFLAKE_JWT`) |
| Local auth | `SNOWFLAKE_PROFILE=terraform_svc`, read from `~/.snowflake/config.toml`. Nothing account-specific in the repo |
| CI auth (step 3) | `SNOWFLAKE_*` env vars from GitHub environment secrets/variables |
| Role per resource | `sysadmin`: warehouses, databases, schemas. `securityadmin`: roles, users, grants. `accountadmin`: resource monitors, account parameters, and storage integrations (step 4) |

## 2.3 Account stack

| Object | Value |
|---|---|
| `CORTEX_ENABLED_CROSS_REGION` | `ANY_REGION` (moves the phase 1 manual setting into code) |
| Resource monitor `SNOWLAB_ACCOUNT_RM` | Account-level, 50 credits/month; notify at 75%, suspend all warehouses at 100%. A hard ceiling above the per-env monitors |

## 2.4 Env stack (DEV shown; PROD identical with its own tfvars)

**Naming:** `SNOWLAB_<ENV>_*`, e.g. `SNOWLAB_DEV`, `SNOWLAB_DEV_WH`.

| Object | Detail |
|---|---|
| Warehouse `SNOWLAB_<ENV>_WH` | XSMALL, `AUTO_SUSPEND = 60`, auto-resume, initially suspended. One per env; split into transform/app later if needed |
| Resource monitor `SNOWLAB_<ENV>_RM` | On that warehouse. DEV 10, PROD 20 credits/month; notify 80%, suspend 100% |
| Database `SNOWLAB_<ENV>` | `DATA_RETENTION_TIME_IN_DAYS`: DEV 1, PROD 7 (time travel) |
| Schemas | `LANDING` (external stage + file formats, step 4) · `BRONZE` · `SILVER` · `GOLD` · `APP` (Streamlit) |

**Roles** (account roles, one set per env, all granted to `SYSADMIN` so admins see everything):

| Role | Gets | Used by |
|---|---|---|
| `SNOWLAB_<ENV>_ANALYST` | Warehouse `USAGE`; DB/`GOLD`/`APP` `USAGE`; `SELECT` on current and future tables/views in `GOLD`; `SNOWFLAKE.CORTEX_USER` | People reading gold, the Streamlit viewer, Cortex Analyst |
| `SNOWLAB_<ENV>_TRANSFORMER` | Inherits `ANALYST`. `SELECT` on `BRONZE` (current and future); `CREATE VIEW/TABLE/DYNAMIC TABLE` on `SILVER`, `GOLD`; `CREATE STREAMLIT` on `APP`; `CREATE SEMANTIC VIEW` on `GOLD` | dbt, semantic view and Streamlit deploys (one CI identity) |

Bronze, the stage and pipes stay **owned by Terraform** (`SYSADMIN`). Transformer can read bronze but never alter it. `RELOAD_FILES` is granted in step 4.

**Users:**

| User | Detail |
|---|---|
| `SNOWLAB_<ENV>_DEPLOY_SVC` | `TYPE = SERVICE`, default role `TRANSFORMER`, default warehouse `SNOWLAB_<ENV>_WH`, RSA public key from tfvars. Private key generated locally into `~/.snowflake/keys/`; goes into the GitHub env secret in step 3 |
| You (`"ronozh"`, from tfvars) | Granted DEV `TRANSFORMER` (local dbt in step 5) and PROD `ANALYST` (read-only in prod) |

## 2.5 Execution order

1. Pin the provider version; write both stacks.
2. Apply `account`.
3. Generate deploy keys for dev and prod. Write `dev.tfvars` / `prod.tfvars` (gitignored).
4. Apply `env` for DEV, verify, then apply PROD.

## Done when

- [ ] `terraform plan` → *No changes* for `account`, `env` DEV and `env` PROD. `fmt` and `validate` are clean.
- [ ] `SHOW` checks: warehouses, monitors and databases with 5 schemas exist per env; the account parameter is set; the monitor is attached.
- [ ] As `SNOWLAB_DEV_DEPLOY_SVC`:
  - can create and drop a view in `SNOWLAB_DEV.SILVER`;
  - can `SELECT` from `BRONZE` but can't create objects there;
  - can't use or see `SNOWLAB_PROD` at all.
- [ ] As `SNOWLAB_DEV_ANALYST`: a `GOLD` test table is readable; `SILVER`/`BRONZE` aren't.
- [ ] Your user: DEV transformer works; PROD is read-only.
- [ ] Nothing account-specific in git; tfvars and keys are ignored. Committed.
- [ ] Cheatsheet updated (provider aliases, per-env state, future grants, `TYPE = SERVICE` users).

## As built (2026-10-08)

- PROD was applied, verified and then **destroyed** (DEV-only decision). `prod.tfvars` and the prod deploy key stay local for step 11.
- Local auth is `SNOWFLAKE_*` env vars from gitignored `terraform/snowflake/.env` (not `SNOWFLAKE_PROFILE`); it unsets a `SNOWFLAKE_PASSWORD` exported by the shell profile.
- Account stack uses `snowflake_account_parameter` (Cortex) + `snowflake_execute` (`ALTER ACCOUNT SET RESOURCE_MONITOR`): `snowflake_current_account` failed on a deprecated parameter.
- Warehouse monitor is attached with `snowflake_execute` as ACCOUNTADMIN; the warehouse ignores `resource_monitor` drift.
- Role tests must use `USE SECONDARY ROLES NONE`. Your admin user inherits every env role, so "read-only PROD" applies to non-admin users only.
