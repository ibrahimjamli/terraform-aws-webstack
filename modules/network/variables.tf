variable "name" {
  description = "Name prefix applied to every resource in this module."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,32}$", var.name))
    error_message = "name must be 2-32 characters of lowercase letters, digits or hyphens."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR, for example 10.0.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least two availability zones are required for a highly available subnet layout."
  }
}

variable "public_subnet_cidrs" {
  description = "One CIDR per availability zone for the public tier."
  type        = list(string)

  # Cross-variable validation (Terraform 1.9+). Checking this here fails with a
  # readable message before any resource is evaluated; the same check written
  # as a resource precondition surfaces as an index-out-of-range error instead.
  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "public_subnet_cidrs must have exactly one entry per availability zone."
  }

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in public_subnet_cidrs must be a valid IPv4 CIDR."
  }
}

variable "private_subnet_cidrs" {
  description = "One CIDR per availability zone for the private tier."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "private_subnet_cidrs must have exactly one entry per availability zone."
  }

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in private_subnet_cidrs must be a valid IPv4 CIDR."
  }
}

variable "enable_nat_gateway" {
  description = "Give private subnets outbound internet access through a NAT gateway."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = <<-EOT
    Route every private subnet through one NAT gateway instead of one per zone.
    Cheaper, but the gateway's zone becomes a single point of failure. Suitable
    for non-production only.
  EOT
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention for the flow log group."
  type        = number
  # A year by default, which is the usual baseline for anything an incident
  # investigation might need. Non-production environments override it down.
  default = 365
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
