terraform {
  required_version = ">= 1.10"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.21"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # key is per environment, passed at init:
  #   terraform init -reconfigure -backend-config=../../backend.hcl -backend-config="key=snowflake/<env>.tfstate"
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
