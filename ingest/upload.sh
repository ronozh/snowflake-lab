#!/usr/bin/env bash
# Upload sample files (data + .ctrl) for a date range to the landing bucket.
#   s3://<bucket>/<env>/ecommerce/<feed>/<yyyy-mm-dd>/<file>
# Snowpipe picks them up from the S3 event. Landing keeps both; pipes load *.csv only.
#
# Usage: AWS_PROFILE=<profile> ingest/upload.sh <env> <from yyyy-mm-dd> [to yyyy-mm-dd]
set -euo pipefail
env=$1; from=$2; to=${3:-$2}
root=$(cd "$(dirname "$0")/.." && pwd)
src="$root/data/sample/ecommerce"
bucket="snowflake-lab-landing-$(aws sts get-caller-identity --query Account --output text)"

d=$from
while [[ ! "$d" > "$to" ]]; do
  for feed in transaction customer product campaign; do
    dir="$src/$feed/$d"
    [ -d "$dir" ] || { echo "skip $feed/$d (no sample data)"; continue; }
    aws s3 cp "$dir" "s3://$bucket/$env/ecommerce/$feed/$d/" --recursive --only-show-errors
    echo "uploaded $feed/$d"
  done
  d=$(date -j -v+1d -f %Y-%m-%d "$d" +%Y-%m-%d 2>/dev/null || date -d "$d + 1 day" +%Y-%m-%d)
done
