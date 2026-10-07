output "ci_role_arn" {
  description = "GitHub variable AWS_CI_ROLE_ARN (step 3)."
  value       = aws_iam_role.ci.arn
}

output "landing_bucket" {
  value = aws_s3_bucket.landing.bucket
}

output "cost_alerts_topic_arn" {
  value = aws_sns_topic.cost_alerts.arn
}
