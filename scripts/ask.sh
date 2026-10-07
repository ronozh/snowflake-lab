#!/usr/bin/env bash
# Ask Cortex Analyst a question against the semantic view (REST API, key-pair JWT).
# Usage: scripts/ask.sh "What was net revenue by channel?" [snow-connection] [semantic-view]
set -euo pipefail
q=$1; conn=${2:-snowlab_dev_deploy}; sv=${3:-SNOWLAB_DEV.GOLD.SALES_SV}
host=$(snow connection list --format JSON 2>/dev/null | jq -r --arg c "$conn" '.[] | select(.connection_name==$c) | .parameters.account')
jwt=$(snow connection generate-jwt -c "$conn" 2>/dev/null | tail -1)
[ -n "$host" ] && [ -n "$jwt" ] || { echo "connection '$conn' not found or JWT failed" >&2; exit 1; }
body=$(jq -n --arg q "$q" --arg sv "$sv" '{messages:[{role:"user",content:[{type:"text",text:$q}]}], semantic_view:$sv}')
curl -sS --fail-with-body -X POST "https://$host.snowflakecomputing.com/api/v2/cortex/analyst/message" \
  -H "Authorization: Bearer $jwt" -H "X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT" \
  -H "Content-Type: application/json" -d "$body" |
  jq -r 'if (.message | type) == "object" then .message.content[] | (if .type == "sql" then "SQL:\n" + .statement
         elif .type == "text" then .text else "\(.type): \(.suggestions // "")" end) else . end'
