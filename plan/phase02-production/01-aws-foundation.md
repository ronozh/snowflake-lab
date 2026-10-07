# 01 — AWS foundation (Terraform)

**Goal:** the AWS side every later step relies on, built and owned by Terraform.

**Achieves:**
- Cost alerts back in place (budget → SNS → email).
- GitHub Actions can authenticate to AWS with no stored keys (OIDC provider + `ci` role).
- A landing bucket for raw files (`dev/` and `prod/` prefixes), versioned for audit.

**Why before step 2:** cost guardrails must exist before anything costs money. The landing bucket is where data enters the platform. The CI role has to exist before CI can be built (step 3). The Snowflake-side IAM role is **not** in this step: it needs the storage integration's external ID, so it comes in step 4.

---

## 1.1 Layout

```
terraform/
├── backend.hcl.example        # shared by all stacks; real backend.hcl gitignored
└── aws/
    ├── versions.tf            # backend key = aws.tfstate, AWS provider ~> 6.0, default_tags
    ├── variables.tf
    ├── budget.tf              # SNS topic + policy + subscriptions, budget
    ├── github_oidc.tf         # OIDC provider, ci role + policy
    ├── landing.tf             # landing bucket
    ├── outputs.tf
    └── terraform.tfvars.example
```

Run: `terraform -chdir=terraform/aws init -backend-config=../backend.hcl`, then `plan` / `apply` with `AWS_PROFILE=dpivoted`.

## 1.2 Variables

| Variable | Default | Where the real value lives |
|---|---|---|
| `aws_region` | `ap-southeast-2` | — |
| `project` | `snowflake-lab` | — |
| `github_repo` | `ronozh/snowflake-lab` | — (public anyway) |
| `alert_emails` | none | Gitignored `terraform.tfvars`; a GitHub variable in step 3. Keeps emails out of the public repo |
| `monthly_budget_usd` | `30` | — |
| `alert_thresholds_percent` | `[60, 90]` | — |
| `noncurrent_version_days` | `90` | How long overwritten or deleted landing files stay recoverable |

## 1.3 Budget and alerts (ported from the foundation project)

- **SNS topic** `snowflake-lab-cost-alerts`. Deliberately *not* KMS-encrypted: AWS Budgets can't publish to a topic encrypted with an AWS-managed key, and it fails silently.
- **Topic policy:** account default access, plus `budgets.amazonaws.com` allowed to `Publish`, with `aws:SourceAccount` / `aws:SourceArn` conditions (confused-deputy protection). Without this policy the alerts never arrive, and nothing reports an error.
- **Email subscriptions:** one per address. Each needs a confirmation click.
- **Budget:** $30/month, cost type. Alerts on actual spend at 60% and 90%, and on forecasted spend at 100%. Sent to SNS and email. `depends_on` the topic policy.
- **Reminder:** an AWS budget only alerts; it can't cap spend. The real caps are architecture (nothing always-on) and Snowflake resource monitors (step 2).

## 1.4 GitHub OIDC and the `ci` role

- **OIDC provider:** `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
- **Role `snowflake-lab-ci`** trust policy (`AssumeRoleWithWebIdentity`):
  - `aud` = `sts.amazonaws.com`
  - `sub` must be one of (this repo uses GitHub's immutable format `repo:ronozh@<owner_id>/snowflake-lab@<repo_id>:...`; see gotcha.md):
    - `repo:ronozh/snowflake-lab:ref:refs/heads/main`: jobs on `main` with no environment
    - `repo:ronozh/snowflake-lab:environment:dev` and `...:environment:prod`: **gotcha**, a job that uses a GitHub environment gets an environment-based `sub`, not a ref-based one
  - Nothing else: other branches, forks and other repos are rejected.
  - Max session 1 hour.
- **Permissions:** what Terraform needs to manage *this* project, and nothing beyond it:

  | Service | Scope |
  |---|---|
  | S3 | `snowflake-lab-*` buckets, including the state bucket |
  | IAM | Roles/policies named `snowflake-lab-*`, plus the GitHub OIDC provider |
  | SNS | `snowflake-lab-*` topics |
  | Budgets | This account |

- **Known trade-off:** the role can create IAM roles under `snowflake-lab-*`, so in theory it could escalate its own privileges. Accepted for now, because only `main` of this repo can assume it. A permissions boundary is the next hardening step if needed.

## 1.5 Landing bucket

| Item | Value |
|---|---|
| Name | `snowflake-lab-landing-<account_id>` |
| Layout | `s3://…/<env>/ecommerce/<feed>/<yyyy-mm-dd>/<file>` where `env` is `dev` or `prod` |
| Versioning | On. This is the audit trail for overwritten files (decision: bronze mirrors landing) |
| Lifecycle | Noncurrent versions expire after 90 days; incomplete multipart uploads abort after 7 days |
| Security | SSE-S3; public access fully blocked; `BucketOwnerEnforced`; TLS-only bucket policy |
| Destroy | `force_destroy = false`. The `nuke` script (step 10) empties it deliberately |

The S3 → SQS event notification for Snowpipe is added in step 4.

## Done when

- [ ] `terraform plan` → *No changes* after apply. `fmt` and `validate` are clean.
- [ ] Both subscription emails confirmed: `aws sns list-subscriptions-by-topic` shows no `PendingConfirmation`.
- [ ] A test `aws sns publish` arrives in both inboxes.
- [ ] `aws budgets describe-budget` shows $30 with 3 notifications.
- [ ] `aws iam get-role --role-name snowflake-lab-ci` shows a trust policy with exactly the 3 allowed `sub` values. (The real CI login is tested in step 3.)
- [ ] Landing bucket: versioning `Enabled`, public access block all `true`. A test object can be put, listed and deleted under `dev/`. Plain HTTP is denied.
- [ ] No emails, account IDs or tfvars in git (`git ls-files` check). Changes committed.
- [ ] Cheatsheet updated (OIDC trust, budgets/SNS, S3 lifecycle/versioning).

## As built (2026-10-08)

- CI role trust uses GitHub's **immutable** `sub` (`repo:<owner>@<id>/<repo>@<id>:...`) and, after review-01 (R8), only `environment:dev`. `ref:refs/heads/main` was removed; `environment:prod` is added in step 11.
- Budget notifications go only via the SNS topic (direct `subscriber_email_addresses` removed, review-01 R13).
- No SQS permission was needed on the CI role (the queue belongs to Snowflake).
