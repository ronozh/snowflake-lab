# CI identity. TYPE = SERVICE: key-pair only, no password/MFA/UI.
resource "snowflake_service_user" "deploy" {
  provider          = snowflake.securityadmin
  name              = "${local.prefix}_DEPLOY_SVC"
  default_role      = snowflake_account_role.transformer.name
  default_warehouse = snowflake_warehouse.this.name
  rsa_public_key    = var.deploy_public_key
  comment           = "CI deploys for snowflake-lab ${var.env}"
}

resource "snowflake_grant_account_role" "deploy_transformer" {
  provider  = snowflake.securityadmin
  role_name = snowflake_account_role.transformer.name
  user_name = snowflake_service_user.deploy.name
}

locals {
  env_roles = {
    ANALYST     = snowflake_account_role.analyst.name
    TRANSFORMER = snowflake_account_role.transformer.name
  }
}

resource "snowflake_grant_account_role" "human" {
  provider  = snowflake.securityadmin
  for_each  = toset(var.human_user_roles)
  role_name = local.env_roles[each.key]
  user_name = var.human_user
}
