output "vpc_id" {
  description = "ID of the VPC."
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

output "alb_dns_name" {
  description = "Public address of the application."
  value       = module.compute.alb_dns_name
}

output "data_bucket" {
  description = "Application data bucket."
  value       = module.storage.data_bucket_id
}
