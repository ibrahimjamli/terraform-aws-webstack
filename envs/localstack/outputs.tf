output "vpc_id" {
  description = "ID of the created VPC, asserted on by the CI job."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.network.private_subnet_ids
}

output "data_bucket_id" {
  description = "Name of the created S3 bucket."
  value       = module.storage.data_bucket_id
}

output "app_security_group_id" {
  description = "Application security group ID."
  value       = module.security.app_security_group_id
}
