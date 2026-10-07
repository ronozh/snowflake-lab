variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "project" {
  description = "Name prefix. IAM permissions for CI are scoped to resources starting with it."
  type        = string
  default     = "snowflake-lab"
}

variable "github_repo" {
  description = "owner/repo allowed to assume the CI role."
  type        = string
  default     = "ronozh/snowflake-lab"
}

variable "github_environments" {
  description = "GitHub environments whose jobs may assume the CI role."
  type        = list(string)
  default     = ["dev", "prod"]
}

variable "alert_emails" {
  description = "Budget alert recipients. Set in gitignored terraform.tfvars (public repo)."
  type        = list(string)
}

variable "monthly_budget_usd" {
  type    = number
  default = 30
}

variable "alert_thresholds_percent" {
  description = "ACTUAL-spend alert thresholds. A FORECASTED alert at 100% is always added."
  type        = list(number)
  default     = [60, 90]
}

variable "noncurrent_version_days" {
  description = "Days an overwritten/deleted landing file stays recoverable."
  type        = number
  default     = 90
}
