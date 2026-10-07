terraform {
  required_version = ">= 1.10"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.21"
    }
  }

  backend "s3" {
    key          = "snowflake/account.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

# Connection comes from SNOWFLAKE_* env vars (see ../.env.example).
# Account-level objects need ACCOUNTADMIN.
provider "snowflake" {
  role = "ACCOUNTADMIN"
}
