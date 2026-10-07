#!/usr/bin/env bash
# Repo + environment settings for a public repo. Idempotent; re-run any time.
# Usage: scripts/github-hardening.sh [repo]
set -euo pipefail
repo=${1:-ronozh/snowflake-lab}

echo "secret scanning + push protection"
gh api -X PATCH "repos/$repo" --silent \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

echo "actions: allowlist, SHA pinning, read-only token"
gh api -X PUT "repos/$repo/actions/permissions" --silent \
  -F enabled=true -f allowed_actions=selected -F sha_pinning_required=true
gh api -X PUT "repos/$repo/actions/permissions/selected-actions" --silent \
  -F github_owned_allowed=true -F verified_allowed=false \
  -f 'patterns_allowed[]=hashicorp/*' -f 'patterns_allowed[]=aws-actions/*'
gh api -X PUT "repos/$repo/actions/permissions/workflow" --silent \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false

echo "fork PRs: approval for all external contributors"
gh api -X PUT "repos/$repo/actions/permissions/fork-pr-contributor-approval" --silent \
  -f approval_policy=all_external_contributors

echo "environment dev: deploy from main only"
gh api -X PUT "repos/$repo/environments/dev" --silent --input - <<'JSON'
{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
JSON
if ! gh api "repos/$repo/environments/dev/deployment-branch-policies" --jq '.branch_policies[].name' | grep -qx main; then
  gh api -X POST "repos/$repo/environments/dev/deployment-branch-policies" --silent -f name=main -f type=branch
fi
