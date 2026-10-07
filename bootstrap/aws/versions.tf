terraform {
  required_version = ">= 1.10" # use_lockfile (S3-native state locking)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Enabled after the first apply, then: terraform init -backend-config=backend.hcl -migrate-state
  # backend "s3" {
  #   key          = "bootstrap/aws.tfstate"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project    = var.project
      managed_by = "terraform"
      stack      = "bootstrap"
    }
  }
}
