# Connection from SNOWFLAKE_* env vars (../.env.example). One alias per system
# role so each resource is created with the least role that can do it.

provider "snowflake" {
  role = "SYSADMIN" # warehouses, databases, schemas, stage, bronze, pipes

  # Pipes and SQL procedures only exist as preview resources in provider 2.x.
  preview_features_enabled = ["snowflake_pipe_resource", "snowflake_procedure_sql_resource"]
}

provider "snowflake" {
  alias = "securityadmin" # roles, users, grants
  role  = "SECURITYADMIN"
}

provider "snowflake" {
  alias = "accountadmin" # resource monitors, SNOWFLAKE db roles
  role  = "ACCOUNTADMIN"
}

# AWS side of the storage integration (IAM role, S3 notification). Credentials from
# AWS_PROFILE locally, OIDC in CI.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = "snowflake-lab"
      managed_by = "terraform"
      stack      = "snowflake-env-${var.env}"
    }
  }
}
