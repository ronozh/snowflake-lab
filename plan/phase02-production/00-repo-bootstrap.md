# 00 — repo and bootstrap

**Goal:** a safe public repo, and the few things that must exist *before* Terraform can manage anything.

**Achieves:**
- Local git repo pushed to `ronozh/snowflake-lab`, with secret scanning and push protection on.
- An S3 bucket for Terraform state (versioned, encrypted, private, TLS-only). Its own state lives inside it.
- Snowflake service user `TERRAFORM_SVC` (key-pair only), plus a local `snow` connection for it.

**Why before step 1:** Terraform needs a remote state backend and an identity in each cloud. These can't be created by the Terraform that depends on them (chicken and egg), so a human with admin rights creates them once, from code kept in `bootstrap/`.

---

## 0.1 Repo layout created in this step

```
snowflake-lab/
├── CLAUDE.md
├── README.md                     # what this is, how to run, layout
├── .gitignore
└── bootstrap/
    ├── README.md                 # run-once instructions
    ├── aws/                      # Terraform: state bucket
    │   ├── main.tf  variables.tf  outputs.tf  versions.tf
    │   └── backend.hcl.example   # real backend.hcl is gitignored
    └── snowflake/
        └── terraform_svc.sql     # creates TERRAFORM_SVC; public key passed as a variable
```

## 0.2 `.gitignore` (key entries)

`plan/` · `cheatsheet/` · `.terraform/` · `*.tfstate*` · `*.tfvars` (but keep `*.tfvars.example`) · `backend.hcl` · `*.p8` `*.pem` `*.key` · `.env*` · `dbt/target/` `dbt/logs/` · `.venv/` · `.DS_Store`

**Account-specific values** (account ID, bucket name, Snowflake account) stay out of git. Locally they live in gitignored `backend.hcl` / `*.tfvars`; in CI they come from GitHub variables (step 3).

## 0.3 Git and GitHub

1. Run `git init -b main` in `snowflake-lab/`, add the files, and make the first commit.
2. `git remote add origin https://github.com/ronozh/snowflake-lab.git`. Push only once you approve.
3. Turn on secret scanning and push protection:
   ```bash
   gh api -X PATCH repos/ronozh/snowflake-lab \
     -f 'security_and_analysis[secret_scanning][status]=enabled' \
     -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
   ```

## 0.4 AWS bootstrap: Terraform state bucket

| Item | Value |
|---|---|
| Bucket | `snowflake-lab-tfstate-<account_id>` |
| Settings | Versioning on, SSE-S3, all public access blocked, `BucketOwnerEnforced`, bucket policy denying non-TLS access |
| Destroy safety | `force_destroy = false`. The `nuke` script (step 10) empties it explicitly |
| Providers | Terraform `>= 1.10` (needed for `use_lockfile`), AWS provider `~> 6.0`, `default_tags` with `project = snowflake-lab`, `managed_by = terraform` |
| State | First apply uses local state. Then add `backend "s3"` (key `bootstrap/aws.tfstate`, `use_lockfile = true`) and run `terraform init -migrate-state`, so the bootstrap's own state moves into the bucket |

```bash
export AWS_PROFILE=dpivoted
terraform -chdir=bootstrap/aws init && terraform -chdir=bootstrap/aws apply
# then add the backend block, copy backend.hcl.example → backend.hcl, then:
terraform -chdir=bootstrap/aws init -backend-config=backend.hcl -migrate-state
```

## 0.5 Snowflake bootstrap: `TERRAFORM_SVC`

| Item | Decision |
|---|---|
| User | `TERRAFORM_SVC`, `TYPE = SERVICE` (no password, no MFA, key-pair only) |
| Roles granted | `SYSADMIN` (objects), `SECURITYADMIN` (roles, users, grants), `ACCOUNTADMIN` (storage integration, resource monitor; only `ACCOUNTADMIN` can create those) |
| How Terraform uses them | Provider aliases per role (step 2), so each resource is created with the least role that can do it |
| Key | New pair at `~/.snowflake/keys/terraform_svc.p8`, separate from your personal key. Goes into a GitHub secret in step 3 |
| Run as | You, via `snow sql --role ACCOUNTADMIN -f bootstrap/snowflake/terraform_svc.sql -D pubkey=...` |
| Local connection | `snow connection add` → `terraform_svc` (role `SYSADMIN`) |

Granting `ACCOUNTADMIN` to an automation user is a trade-off: it's needed for two object types. Mitigations: the key is held only by you and GitHub's `prod`/`dev` environments, and the user is `TYPE = SERVICE`, so it can't sign in to the UI.

## Done when

- [ ] `git log` shows the first commit; `git status` is clean; no ignored file is tracked (`git ls-files | grep -E 'tfstate|tfvars$|\.p8|backend.hcl$'` returns nothing).
- [ ] After pushing: `gh api repos/ronozh/snowflake-lab --jq .security_and_analysis` shows both features `enabled`.
- [ ] `aws s3api get-bucket-versioning` shows `Enabled`; public access block is all `true`; `bootstrap/aws.tfstate` is in the bucket; no local `terraform.tfstate` is left.
- [ ] `terraform -chdir=bootstrap/aws plan` → *No changes*.
- [ ] `snow connection test -c terraform_svc` → OK, user `TERRAFORM_SVC`.
- [ ] `SHOW GRANTS TO USER TERRAFORM_SVC` → `SYSADMIN`, `SECURITYADMIN`, `ACCOUNTADMIN`.
- [ ] Cheatsheet updated (git/gh, Terraform state, `CREATE USER ... TYPE = SERVICE`).

## As built (2026-10-08)

- `bootstrap/snowflake/terraform_svc.sql` also creates `TERRAFORM_WH` (XS) as `TERRAFORM_SVC`'s default warehouse: the Snowflake provider needs a warehouse for some reads.
- Account ID was found in `CLAUDE.md` before the first commit and removed; every commit is now scanned for 12-digit IDs, emails and account names.
