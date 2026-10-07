# S3 landing -> storage integration -> external stage -> Snowpipe -> BRONZE.
# Bronze mirrors landing 1:1 per file; corrections go through RELOAD_FILES.

data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "landing" {
  bucket = "snowflake-lab-landing-${data.aws_caller_identity.current.account_id}"
}

locals {
  env_prefix   = "${var.env}/"
  iam_role     = "snowflake-lab-${var.env}-snowflake-s3"
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.iam_role}"
  external_id  = "snowflake-lab-${var.env}"
  stage_fqn    = snowflake_stage_external_s3.ecommerce.fully_qualified_name
  ff_fqn       = "${snowflake_database.this.name}.LANDING.${snowflake_file_format_csv.ecommerce.name}"

  # One definition per feed drives table DDL, pipe COPY and RELOAD_FILES.
  feeds = {
    transaction = [
      ["transaction_id", "VARCHAR"], ["event_ts", "TIMESTAMP_NTZ"],
      ["customer_id", "NUMBER"], ["product_id", "NUMBER"], ["campaign_id", "NUMBER"],
      ["quantity", "NUMBER"], ["unit_price", "NUMBER(12,2)"], ["unit_cost", "NUMBER(12,2)"],
      ["discount_pct", "NUMBER(5,4)"], ["gross_amount", "NUMBER(12,2)"],
      ["net_amount", "NUMBER(12,2)"], ["margin_amount", "NUMBER(12,2)"],
      ["currency", "VARCHAR"], ["payment_method", "VARCHAR"], ["channel", "VARCHAR"], ["status", "VARCHAR"],
    ]
    customer = [
      ["customer_id", "NUMBER"], ["first_name", "VARCHAR"], ["last_name", "VARCHAR"],
      ["email", "VARCHAR"], ["tier", "VARCHAR"], ["credit_limit", "NUMBER(12,2)"],
      ["state", "VARCHAR"], ["city", "VARCHAR"], ["postal_code", "VARCHAR"],
      ["signup_date", "DATE"], ["marketing_opt_in", "BOOLEAN"], ["is_active", "BOOLEAN"],
      ["snapshot_date", "DATE"],
    ]
    product = [
      ["product_id", "NUMBER"], ["sku", "VARCHAR"], ["brand", "VARCHAR"], ["category", "VARCHAR"],
      ["subcategory", "VARCHAR"], ["product_name", "VARCHAR"], ["unit_price", "NUMBER(12,2)"],
      ["unit_cost", "NUMBER(12,2)"], ["weight_kg", "NUMBER(10,3)"], ["launch_date", "DATE"],
      ["is_available", "BOOLEAN"], ["snapshot_date", "DATE"],
    ]
    campaign = [
      ["campaign_id", "NUMBER"], ["campaign_code", "VARCHAR"], ["campaign_name", "VARCHAR"],
      ["channel", "VARCHAR"], ["budget_aud", "NUMBER(14,2)"], ["discount_pct", "NUMBER(5,4)"],
      ["start_date", "DATE"], ["is_running", "BOOLEAN"], ["snapshot_date", "DATE"],
    ]
  }

  provenance = [
    ["_src_file", "VARCHAR", "METADATA$FILENAME"],
    ["_src_row_number", "NUMBER", "METADATA$FILE_ROW_NUMBER"],
    ["_src_file_checksum", "VARCHAR", "METADATA$FILE_CONTENT_KEY"],
    ["_src_file_modified", "TIMESTAMP_NTZ", "METADATA$FILE_LAST_MODIFIED"],
    ["_loaded_at", "TIMESTAMP_LTZ", "CURRENT_TIMESTAMP()"],
  ]

  bronze_table = { for f, _ in local.feeds : f => "${snowflake_database.this.name}.BRONZE.${upper(f)}" }

  table_ddl = { for f, cols in local.feeds : f => join(", ", concat(
    [for c in cols : "${c[0]} ${c[1]}"],
    [for p in local.provenance : "${p[0]} ${p[1]}"],
  )) }

  # COPY body shared by the pipe and RELOAD_FILES; only PATTERN/options differ.
  copy_body = { for f, cols in local.feeds : f => join("", [
    "COPY INTO ${local.bronze_table[f]} (",
    join(", ", concat([for c in cols : c[0]], [for p in local.provenance : p[0]])),
    ") FROM (SELECT ",
    join(", ", concat([for i, _ in cols : format("$%d", i + 1)], [for p in local.provenance : p[2]])),
    " FROM @${local.stage_fqn}/${f}/) FILE_FORMAT = (FORMAT_NAME = '${local.ff_fqn}')",
  ]) }
}

# --- AWS: role Snowflake assumes to read this env's prefix ---------------------

data "aws_iam_policy_document" "snowflake_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [snowflake_storage_integration_aws.landing.describe_output[0].iam_user_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [local.external_id]
    }
  }
}

resource "aws_iam_role" "snowflake_s3" {
  name               = local.iam_role
  description        = "Snowflake storage integration (${var.env}): read ${local.env_prefix} in landing."
  assume_role_policy = data.aws_iam_policy_document.snowflake_trust.json
}

data "aws_iam_policy_document" "snowflake_s3" {
  statement {
    sid       = "ReadEnvPrefix"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${data.aws_s3_bucket.landing.arn}/${local.env_prefix}*"]
  }
  statement {
    sid       = "ListEnvPrefix"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [data.aws_s3_bucket.landing.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.env_prefix}*"]
    }
  }
}

resource "aws_iam_role_policy" "snowflake_s3" {
  name   = local.iam_role
  role   = aws_iam_role.snowflake_s3.id
  policy = data.aws_iam_policy_document.snowflake_s3.json
}

# --- Snowflake: integration, stage, file format ---------------------------------

resource "snowflake_storage_integration_aws" "landing" {
  provider                  = snowflake.accountadmin # only ACCOUNTADMIN can create integrations
  name                      = "${local.prefix}_S3_LANDING"
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = local.iam_role_arn # role is created after; Snowflake only checks on use
  storage_aws_external_id   = local.external_id  # our own ID => single apply, no two-pass
  storage_allowed_locations = ["s3://${data.aws_s3_bucket.landing.bucket}/${local.env_prefix}"]
  comment                   = "snowflake-lab ${var.env} landing (read-only)"
}

resource "snowflake_grant_privileges_to_account_role" "sysadmin_integration" {
  provider          = snowflake.accountadmin
  account_role_name = "SYSADMIN"
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "INTEGRATION"
    object_name = snowflake_storage_integration_aws.landing.name
  }
}

resource "snowflake_file_format_csv" "ecommerce" {
  database                     = snowflake_database.this.name
  schema                       = snowflake_schema.this["LANDING"].name
  name                         = "CSV_ECOMMERCE"
  skip_header                  = 1
  field_optionally_enclosed_by = "\""
  empty_field_as_null          = true
  null_if                      = ["", "NULL", "null", "N/A"]
  trim_space                   = true
}

resource "snowflake_stage_external_s3" "ecommerce" {
  database            = snowflake_database.this.name
  schema              = snowflake_schema.this["LANDING"].name
  name                = "ECOMMERCE"
  url                 = "s3://${data.aws_s3_bucket.landing.bucket}/${local.env_prefix}ecommerce/"
  storage_integration = snowflake_storage_integration_aws.landing.name
  comment             = "Landing: <feed>/<yyyy-mm-dd>/<file>"

  depends_on = [snowflake_grant_privileges_to_account_role.sysadmin_integration]
}

# --- Bronze tables ----------------------------------------------------------------
# CREATE OR ALTER: schema changes apply in place. Revert is a no-op so a destroy or
# replacement never drops bronze (the database drop handles full teardown).
resource "snowflake_execute" "bronze_table" {
  for_each = local.feeds
  execute  = "CREATE OR ALTER TABLE ${local.bronze_table[each.key]} (${local.table_ddl[each.key]}) COMMENT = 'Bronze: mirrors landing ${each.key} files 1:1'"
  revert   = "SELECT 1"

  depends_on = [snowflake_schema.this]
}

# --- Snowpipes ----------------------------------------------------------------------

resource "snowflake_pipe" "bronze" {
  for_each       = local.feeds
  database       = snowflake_database.this.name
  schema         = snowflake_schema.this["BRONZE"].name
  name           = "${upper(each.key)}_PIPE"
  auto_ingest    = true
  copy_statement = "${local.copy_body[each.key]} PATTERN = '.*[.]csv' ON_ERROR = SKIP_FILE"
  comment        = "Auto-ingest ${each.key} files into bronze"

  depends_on = [snowflake_execute.bronze_table, aws_iam_role_policy.snowflake_s3]
}

# All pipes in an account share one SQS queue. Bucket notifications are a singleton
# per bucket: move this to a shared stack when PROD is added (step 11).
resource "aws_s3_bucket_notification" "landing" {
  bucket = data.aws_s3_bucket.landing.id
  queue {
    queue_arn     = snowflake_pipe.bronze["transaction"].notification_channel
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "${local.env_prefix}ecommerce/"
  }
}

# --- Corrections ----------------------------------------------------------------------
# CALL BRONZE.RELOAD_FILES('transaction', '.*transaction/2026-01-01/.*');
# Pattern must match the whole _src_file path (start with .*).
resource "snowflake_procedure_sql" "reload_files" {
  database    = snowflake_database.this.name
  schema      = snowflake_schema.this["BRONZE"].name
  name        = "RELOAD_FILES"
  return_type = "VARCHAR"
  execute_as  = "OWNER"
  comment     = "Replace bronze rows for files matching a pattern with a fresh load (one transaction)."

  arguments {
    arg_name      = "FEED"
    arg_data_type = "VARCHAR"
  }
  arguments {
    arg_name      = "FILE_PATTERN"
    arg_data_type = "VARCHAR"
  }

  procedure_definition = <<-SQL
    DECLARE
      tbl VARCHAR;
      copy_sql VARCHAR;
      deleted INTEGER;
    BEGIN
      CASE (LOWER(:FEED))
    %{for f, _ in local.feeds~}
        WHEN '${f}' THEN
          tbl := '${local.bronze_table[f]}';
          copy_sql := '${replace(local.copy_body[f], "'", "''")}';
    %{endfor~}
        ELSE
          RETURN 'unknown feed: ' || :FEED;
      END CASE;
      BEGIN TRANSACTION;
      EXECUTE IMMEDIATE 'DELETE FROM ' || tbl || ' WHERE REGEXP_LIKE(_src_file, ''' || REPLACE(:FILE_PATTERN, '''', '''''') || ''')';
      deleted := SQLROWCOUNT;
      EXECUTE IMMEDIATE copy_sql || ' PATTERN = ''' || REPLACE(:FILE_PATTERN, '''', '''''') || ''' FORCE = TRUE ON_ERROR = ABORT_STATEMENT';
      COMMIT;
      RETURN 'deleted ' || deleted || ' rows; reloaded files matching ' || :FILE_PATTERN;
    EXCEPTION
      WHEN OTHER THEN
        ROLLBACK;
        RAISE;
    END;
  SQL

  depends_on = [snowflake_execute.bronze_table]
}
