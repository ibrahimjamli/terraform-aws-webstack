output "backend_config" {
  description = "Values to pass to `terraform init -backend-config` in envs/."
  value = {
    bucket         = aws_s3_bucket.state.id
    dynamodb_table = aws_dynamodb_table.locks.name
    region         = var.region
    encrypt        = true
  }
}

output "init_command" {
  description = "Copy-paste command to initialise an environment against this backend."
  value       = <<-EOT
    terraform init \
      -backend-config="bucket=${aws_s3_bucket.state.id}" \
      -backend-config="key=webstack/dev/terraform.tfstate" \
      -backend-config="region=${var.region}" \
      -backend-config="dynamodb_table=${aws_dynamodb_table.locks.name}" \
      -backend-config="encrypt=true"
  EOT
}
