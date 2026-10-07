#!/usr/bin/env bash
# Push local, gitignored config to GitHub secrets. Local files are the source of truth.
# Re-run whenever a tfvars/backend/key file changes.
#
# Usage: AWS_PROFILE=<admin> scripts/sync-ci-secrets.sh [repo]
set -euo pipefail
repo=${1:-ronozh/snowflake-lab}
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

# Snowflake org/account from the local provider env file.
# shellcheck disable=SC1091
set -a; source terraform/snowflake/.env; set +a

echo "repo secrets"
gh secret set AWS_CI_ROLE_ARN   -R "$repo" --body "$(terraform -chdir=terraform/aws output -raw ci_role_arn)"
gh secret set TF_BACKEND_HCL    -R "$repo" < terraform/backend.hcl
gh secret set SNOWFLAKE_ORGANIZATION_NAME -R "$repo" --body "$SNOWFLAKE_ORGANIZATION_NAME"
gh secret set SNOWFLAKE_ACCOUNT_NAME      -R "$repo" --body "$SNOWFLAKE_ACCOUNT_NAME"

echo "env dev secrets"
gh secret set SNOWFLAKE_PRIVATE_KEY -R "$repo" --env dev < ~/.snowflake/keys/terraform_svc.p8
gh secret set TFVARS_AWS            -R "$repo" --env dev < terraform/aws/terraform.tfvars
gh secret set TFVARS_SNOWFLAKE_ENV  -R "$repo" --env dev < terraform/snowflake/env/dev.tfvars
gh secret set SNOWFLAKE_DEPLOY_PRIVATE_KEY -R "$repo" --env dev < ~/.snowflake/keys/snowlab_dev_deploy_svc.p8
