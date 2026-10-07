variable "account_credit_quota" {
  description = "Hard monthly ceiling for ALL warehouses (not serverless: Snowpipe, Cortex)."
  type        = number
  default     = 50
}
