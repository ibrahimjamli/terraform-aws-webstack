variable "name" {
  description = "Name prefix for the buckets."
  type        = string
}

variable "bucket_suffix" {
  description = <<-EOT
    Suffix appended to bucket names. S3 bucket names are globally unique, so
    this is normally the AWS account id to keep the same configuration
    deployable in more than one account.
  EOT
  type        = string
}

variable "enable_access_logging" {
  description = "Write S3 server access logs to a dedicated log bucket."
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Delete superseded object versions after this many days."
  type        = number
  default     = 90
}

variable "enable_lifecycle_rules" {
  description = <<-EOT
    Manage lifecycle configuration on the buckets. Should stay true anywhere
    real. It exists because LocalStack's S3 accepts a lifecycle configuration
    and then does not return it, so the AWS provider's read-back poll never
    converges and the apply times out after three minutes.
  EOT
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = <<-EOT
    Allow `terraform destroy` to delete a bucket that still holds objects.
    Only ever true for throwaway environments; leaving it on in production
    turns a careless destroy into permanent data loss.
  EOT
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
