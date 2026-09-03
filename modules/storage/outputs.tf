output "data_bucket_id" {
  description = "Name of the application data bucket."
  value       = aws_s3_bucket.data.id
}

output "data_bucket_arn" {
  description = "ARN of the application data bucket."
  value       = aws_s3_bucket.data.arn
}

output "log_bucket_id" {
  description = "Name of the access-log bucket, null when logging is disabled."
  value       = var.enable_access_logging ? aws_s3_bucket.logs[0].id : null
}
