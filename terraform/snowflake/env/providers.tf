# Connection from SNOWFLAKE_* env vars (../.env.example). One alias per system
# role so each resource is created with the least role that can do it.

provider "snowflake" {
  role = "SYSADMIN" # warehouses, databases, schemas
}

provider "snowflake" {
  alias = "securityadmin" # roles, users, grants
  role  = "SECURITYADMIN"
}

provider "snowflake" {
  alias = "accountadmin" # resource monitors, SNOWFLAKE db roles
  role  = "ACCOUNTADMIN"
}
