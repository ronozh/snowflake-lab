variable "aws_region" {
  description = "Region for the state bucket."
  type        = string
  default     = "ap-southeast-2"
}

variable "project" {
  description = "Prefix for resource names and the project tag."
  type        = string
  default     = "snowflake-lab"
}
