locals {
  prefix  = "SNOWLAB_${upper(var.env)}"
  schemas = ["LANDING", "BRONZE", "SILVER", "GOLD", "APP"]
}

# --- Compute -------------------------------------------------------------------

resource "snowflake_warehouse" "this" {
  name                = "${local.prefix}_WH"
  warehouse_size      = var.warehouse_size
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
  comment             = "snowflake-lab ${var.env}"

  lifecycle {
    ignore_changes = [resource_monitor] # assigned below as ACCOUNTADMIN
  }
}

resource "snowflake_resource_monitor" "this" {
  provider        = snowflake.accountadmin
  name            = "${local.prefix}_RM"
  credit_quota    = var.warehouse_credit_quota
  frequency       = "MONTHLY"
  start_timestamp = "IMMEDIATELY"
  notify_triggers = [80]
  suspend_trigger = 100
}

# Only ACCOUNTADMIN can assign a monitor; keeping the warehouse owned by SYSADMIN.
resource "snowflake_execute" "warehouse_monitor" {
  provider = snowflake.accountadmin
  execute  = "ALTER WAREHOUSE ${snowflake_warehouse.this.fully_qualified_name} SET RESOURCE_MONITOR = ${snowflake_resource_monitor.this.fully_qualified_name}"
  revert   = "ALTER WAREHOUSE ${snowflake_warehouse.this.fully_qualified_name} UNSET RESOURCE_MONITOR"
}

# --- Storage -------------------------------------------------------------------

resource "snowflake_database" "this" {
  name                        = local.prefix
  data_retention_time_in_days = var.data_retention_days
  comment                     = "snowflake-lab ${var.env}"
}

# LANDING: external stage + file formats (step 4). BRONZE: Terraform-owned
# tables mirroring landing. SILVER/GOLD: dbt. APP: Streamlit.
resource "snowflake_schema" "this" {
  for_each = toset(local.schemas)
  database = snowflake_database.this.name
  name     = each.key
}
