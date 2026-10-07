variable "env" {
  description = "dev or prod."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod."
  }
}

variable "warehouse_size" {
  type    = string
  default = "XSMALL"
}

variable "warehouse_credit_quota" {
  description = "Monthly credits for this env's warehouse before it is suspended."
  type        = number
}

variable "data_retention_days" {
  description = "Time travel on the database."
  type        = number
}

variable "deploy_public_key" {
  description = "RSA public key (base64 body) for the CI deploy user."
  type        = string
}

variable "human_user" {
  description = "Your Snowflake user name (exact case)."
  type        = string
}

variable "human_user_roles" {
  description = "Env roles granted to the human user: subset of [ANALYST, TRANSFORMER]."
  type        = list(string)
}
