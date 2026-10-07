# ANALYST: read gold, use the app and Cortex.
# TRANSFORMER: inherits ANALYST; reads bronze, builds silver/gold, deploys app + semantic view.
# Both roll up to SYSADMIN so admins see everything.

resource "snowflake_account_role" "analyst" {
  provider = snowflake.securityadmin
  name     = "${local.prefix}_ANALYST"
  comment  = "Read gold, Streamlit, Cortex (${var.env})"
}

resource "snowflake_account_role" "transformer" {
  provider = snowflake.securityadmin
  name     = "${local.prefix}_TRANSFORMER"
  comment  = "dbt, semantic view, Streamlit deploys (${var.env})"
}

resource "snowflake_grant_account_role" "analyst_to_transformer" {
  provider         = snowflake.securityadmin
  role_name        = snowflake_account_role.analyst.name
  parent_role_name = snowflake_account_role.transformer.name
}

resource "snowflake_grant_account_role" "transformer_to_sysadmin" {
  provider         = snowflake.securityadmin
  role_name        = snowflake_account_role.transformer.name
  parent_role_name = "SYSADMIN"
}

# --- ANALYST -------------------------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "analyst_warehouse" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.this.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_database" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.this.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_schemas" {
  provider          = snowflake.securityadmin
  for_each          = toset(["GOLD", "APP"])
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = snowflake_schema.this[each.key].fully_qualified_name
  }
}

# Future grants: anything dbt creates in GOLD is readable immediately.
resource "snowflake_grant_privileges_to_account_role" "analyst_gold_future" {
  provider          = snowflake.securityadmin
  for_each          = toset(["TABLES", "VIEWS", "DYNAMIC TABLES"])
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = each.key
      in_schema          = snowflake_schema.this["GOLD"].fully_qualified_name
    }
  }
}

resource "snowflake_grant_database_role" "analyst_cortex" {
  provider           = snowflake.accountadmin # SNOWFLAKE db roles
  database_role_name = "\"SNOWFLAKE\".\"CORTEX_USER\""
  parent_role_name   = snowflake_account_role.analyst.name
}

# --- TRANSFORMER ---------------------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "transformer_schemas" {
  provider          = snowflake.securityadmin
  for_each          = toset(["BRONZE", "SILVER"])
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["USAGE"]
  on_schema {
    schema_name = snowflake_schema.this[each.key].fully_qualified_name
  }
}

# Read-only on bronze: Terraform owns it; transformer can never alter it.
resource "snowflake_grant_privileges_to_account_role" "transformer_bronze_future" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = snowflake_schema.this["BRONZE"].fully_qualified_name
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_build" {
  provider          = snowflake.securityadmin
  for_each          = toset(["SILVER", "GOLD"])
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["CREATE VIEW", "CREATE TABLE", "CREATE DYNAMIC TABLE"]
  on_schema {
    schema_name = snowflake_schema.this[each.key].fully_qualified_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_semantic_view" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["CREATE SEMANTIC VIEW"]
  on_schema {
    schema_name = snowflake_schema.this["GOLD"].fully_qualified_name
  }
}

resource "snowflake_grant_privileges_to_account_role" "transformer_streamlit" {
  provider          = snowflake.securityadmin
  account_role_name = snowflake_account_role.transformer.name
  privileges        = ["CREATE STREAMLIT"]
  on_schema {
    schema_name = snowflake_schema.this["APP"].fully_qualified_name
  }
}
