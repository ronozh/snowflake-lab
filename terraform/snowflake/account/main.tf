# Account-level singletons. Kept out of the per-env stack so DEV and PROD
# states never fight over the same object.

resource "snowflake_resource_monitor" "account" {
  name            = "SNOWLAB_ACCOUNT_RM"
  credit_quota    = var.account_credit_quota
  frequency       = "MONTHLY"
  start_timestamp = "IMMEDIATELY"
  notify_triggers = [75]
  suspend_trigger = 100 # suspends every warehouse once running queries finish
}

# Attach as the account-level monitor. snowflake_current_account can do this but
# manages every account parameter and fails on deprecated ones, so use plain SQL.
resource "snowflake_execute" "account_monitor" {
  execute = "ALTER ACCOUNT SET RESOURCE_MONITOR = ${snowflake_resource_monitor.account.fully_qualified_name}"
  revert  = "ALTER ACCOUNT SET RESOURCE_MONITOR = NULL"
}

# Lets Cortex use models hosted outside ap-southeast-2.
resource "snowflake_account_parameter" "cortex_cross_region" {
  key   = "CORTEX_ENABLED_CROSS_REGION"
  value = "ANY_REGION"
}
