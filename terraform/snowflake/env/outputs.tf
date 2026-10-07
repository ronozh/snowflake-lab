output "database" {
  value = snowflake_database.this.name
}

output "warehouse" {
  value = snowflake_warehouse.this.name
}

output "transformer_role" {
  value = snowflake_account_role.transformer.name
}

output "analyst_role" {
  value = snowflake_account_role.analyst.name
}

output "deploy_user" {
  value = snowflake_service_user.deploy.name
}
