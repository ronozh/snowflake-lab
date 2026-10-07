# 03 — CI for Terraform

**Goal:** every infrastructure change is deployed by GitHub Actions, not a laptop.

**Achieves:**
- Push to `main` → validate → apply DEV automatically. **DEV only**: the PROD job is added in step 11.
- No long-lived AWS keys: AWS via OIDC; Snowflake via `TERRAFORM_SVC`'s key held only in GitHub environment secrets.
- The public repo is hardened: only allowed actions, pinned by SHA; fork PRs can't run with secrets; logs leak no emails or account IDs.

**Why before step 4:** step 4 is the first change that touches AWS and Snowflake together (storage integration ↔ IAM trust). From here on, every infrastructure change should go through the same reviewed, repeatable path. Local `terraform apply` becomes break-glass only.

---

## 3.1 Workflow `.github/workflows/terraform.yml`

| Item | Value |
|---|---|
| Triggers | `push` to `main` (paths `terraform/**`, the workflow file), `workflow_dispatch`. **No `pull_request` trigger**: there are no PRs, so fork PRs trigger nothing |
| Permissions | `contents: read`, `id-token: write` (OIDC). Nothing else |
| Concurrency | One run at a time (`group: terraform`, no cancel). Also protects the state locks |
| Tools | `hashicorp/setup-terraform` pinned to the local version (1.15.x) |
| Actions | `actions/checkout`, `hashicorp/setup-terraform`, `aws-actions/configure-aws-credentials`. All pinned to a full commit SHA |

**Jobs:**

```
validate ──▶ dev
```

| Job | Environment | Does |
|---|---|---|
| `validate` | none, no secrets | `terraform fmt -check -recursive`; `init -backend=false` + `validate` for every stack |
| `dev` | `dev` (auto) | Plan + apply, in order: `aws` → `snowflake/account` → `snowflake/env` (key `snowflake/dev.tfstate`) |

**Shared stacks:** `aws` and `snowflake/account` are account-wide. While only DEV exists they run in the `dev` job. Step 11 moves them behind the `prod` approval.

## 3.2 Secrets and variables (nothing account-specific in the repo)

Everything account-specific is stored as a **secret**, so GitHub masks it in logs. Plain variables aren't masked.

| Scope | Name | Content |
|---|---|---|
| Repo secret | `AWS_CI_ROLE_ARN` | `snowflake-lab-ci` role ARN |
| Repo secret | `TF_BACKEND_HCL` | Contents of `terraform/backend.hcl` (state bucket name) |
| Repo secret | `SNOWFLAKE_ORGANIZATION_NAME`, `SNOWFLAKE_ACCOUNT_NAME` | Snowflake account |
| `dev` env secret | `SNOWFLAKE_PRIVATE_KEY` | `TERRAFORM_SVC` private key. Environment-scoped, so only `main` jobs in `dev` can read it |
| `dev` env secret | `TFVARS_SNOWFLAKE_ENV`, `TFVARS_AWS` | Contents of `dev.tfvars` and `terraform/aws/terraform.tfvars` (alert emails) |

Jobs write the tfvars/backend secrets to files at runtime. **The local files stay the source of truth**; a small script, `scripts/sync-ci-secrets.sh`, pushes them with `gh secret set`, so the two never drift by hand.

## 3.3 Public logs

- Plans are written to a file with `-out`, and the full plan text **is not printed**.
- The job summary shows only counts per action and the resource types touched. Resource addresses can contain values (e.g. `cost_alerts_email["<email>"]`).
- Each job starts with `::add-mask::` for the alert emails and the account ID, as a second layer of protection.
- On failure, Terraform's error text is printed (needed for debugging). Errors may include ARNs, but the account ID is masked.

## 3.4 Repo and environment hardening (via `gh api`, recorded in a script)

| Setting | Value |
|---|---|
| Allowed actions | GitHub-owned + `hashicorp/*`, `aws-actions/*` only |
| SHA pinning | Required |
| Fork PR workflows | Approval required for all external contributors |
| Default `GITHUB_TOKEN` | Read-only (already set) |
| Environment `dev` | Deploys from `main` only |
| Environment `prod` | Not created until step 11 (then: `main` only, required reviewer = you) |

## 3.5 PROD objects from step 2

`SNOWLAB_PROD` (31 resources) was already applied in step 2. To keep everything DEV-only, destroy it now (`terraform destroy -var-file=prod.tfvars` with the prod state key). It's empty, and step 11 re-creates it with one apply. `prod.tfvars` and the prod deploy key stay local.

## 3.6 Local vs CI

- After this step, CI owns `apply`. Locally: `plan` is fine; `apply` only as break-glass, written up in `gotcha.md`.
- The CI role already has permissions scoped to `snowflake-lab-*`, which covers the state bucket.

## Done when

- [ ] An empty-change push runs: `validate` ✓, `dev` applies *no changes* to all three stacks.
- [ ] A real change (e.g. a resource comment) is applied by CI to DEV. Local `plan` then shows *No changes*.
- [ ] `gh run view --log` contains no alert email, account ID or Snowflake org/account name.
- [ ] Settings checked with `gh api`: allowed actions, SHA pinning, fork approval, the `dev` environment with branch policy.
- [ ] A workflow using an unpinned or disallowed action fails (quick negative test, then reverted).
- [ ] Cheatsheet and gotcha.md updated. Committed and pushed.

## As built (2026-10-08)

- First run failed OIDC: the repo uses GitHub's immutable `sub` format; trust policy fixed (one local break-glass apply).
- Later hardening (review-01): `defaults.run.shell: bash` (pipefail), `TERRAFORM_SVC` key only on the Snowflake steps (YAML anchor), `bootstrap/**` in trigger paths.
- `dev` env also holds `SNOWFLAKE_DEPLOY_PRIVATE_KEY` (step 6); `scripts/sync-ci-secrets.sh` pushes it.
