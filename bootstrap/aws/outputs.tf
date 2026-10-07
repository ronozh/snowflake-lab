output "tfstate_bucket" {
  description = "Put this in each stack's backend.hcl (bucket = ...)."
  value       = aws_s3_bucket.tfstate.bucket
}
