#!/usr/bin/env bash
# Tear down EVERYTHING this repo created (DEV), in reverse dependency order:
#   snowflake/env (dev) -> snowflake/account -> landing bucket contents -> aws
#   -> Snowflake bootstrap (TERRAFORM_SVC, TERRAFORM_WH) -> state bucket (all versions)
#
# Usage:
#   AWS_PROFILE=<admin> scripts/nuke.sh --dry-run   # show what would be destroyed
#   AWS_PROFILE=<admin> scripts/nuke.sh             # do it (asks to type 'nuke')
# Env: SNOW_ADMIN_CONN (default snowlab) = your personal snow connection with ACCOUNTADMIN.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"
dry=false; [ "${1:-}" = "--dry-run" ] && dry=true
admin_conn=${SNOW_ADMIN_CONN:-snowlab}
# shellcheck disable=SC1091
set -a; source terraform/snowflake/.env; set +a
account_id=$(aws sts get-caller-identity --query Account --output text)
landing="snowflake-lab-landing-$account_id"
state="snowflake-lab-tfstate-$account_id"
be="$root/terraform/backend.hcl"

tf_destroy() { # dir, [state key], [var-file]
  local dir=$1 key=${2:-} vf=${3:-}
  local init=(-backend-config="$be") args=()
  [ -n "$key" ] && init+=(-backend-config="key=$key")
  [ -n "$vf" ] && args+=(-var-file="$vf")
  terraform -chdir="$dir" init -reconfigure -input=false "${init[@]}" >/dev/null
  if $dry; then
    terraform -chdir="$dir" plan -destroy -input=false -no-color ${args[@]+"${args[@]}"} | grep -E '^Plan:|No changes'
  else
    terraform -chdir="$dir" destroy -auto-approve -input=false ${args[@]+"${args[@]}"}
  fi
}

empty_versioned_bucket() { # Versions AND delete markers; `aws s3 rb --force` misses them.
  local b=$1 payload; payload=$(mktemp)
  while :; do
    aws s3api list-object-versions --bucket "$b" --max-items 1000 --output json \
      --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}}' \
      | jq '{Objects: (.Objects // []), Quiet: true}' >"$payload"
    [ "$(jq '.Objects | length' "$payload")" -eq 0 ] && break
    aws s3api delete-objects --bucket "$b" --delete "file://$payload" >/dev/null
  done
  rm -f "$payload"
}

echo "Account $account_id: landing=$landing state=$state"
if ! $dry; then
  read -r -p "Type 'nuke' to destroy everything: " c; [ "$c" = nuke ] || { echo aborted; exit 1; }
fi

echo "== snowflake/env (dev)";  tf_destroy terraform/snowflake/env snowflake/dev.tfstate dev.tfvars
echo "== snowflake/account";    tf_destroy terraform/snowflake/account
echo "== landing bucket objects"
if $dry; then aws s3 ls "s3://$landing" --recursive --summarize | tail -2; else empty_versioned_bucket "$landing"; fi
echo "== aws";                  tf_destroy terraform/aws
echo "== snowflake bootstrap (TERRAFORM_SVC, TERRAFORM_WH)"
if $dry; then echo "would DROP USER TERRAFORM_SVC; DROP WAREHOUSE TERRAFORM_WH"
else snow sql -c "$admin_conn" --role ACCOUNTADMIN -q "DROP USER IF EXISTS TERRAFORM_SVC; DROP WAREHOUSE IF EXISTS TERRAFORM_WH"; fi
echo "== state bucket (last: it holds the record of everything above)"
if $dry; then aws s3 ls "s3://$state" --recursive | wc -l | xargs echo "state objects:"
else empty_versioned_bucket "$state"; aws s3api delete-bucket --bucket "$state"; find terraform bootstrap -name .terraform -type d -prune -exec rm -rf {} +; fi
if $dry; then echo "done (dry run)"; else echo "done"; fi
