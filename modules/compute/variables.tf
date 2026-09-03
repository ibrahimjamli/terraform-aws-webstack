variable "name" {
  description = "Name prefix for the compute resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC to deploy into."
  type        = string
}

variable "public_subnet_ids" {
  description = "Subnets for the load balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the application instances."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group for the load balancer."
  type        = string
}

variable "app_security_group_id" {
  description = "Security group for the application instances."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the application tier."
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port the application listens on."
  type        = number
  default     = 8000
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Instance count to start with."
  type        = number
  default     = 2
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "health_check_path" {
  description = "Path the target group polls to decide an instance is healthy."
  type        = string
  default     = "/healthz"
}

variable "access_logs_bucket" {
  description = "Bucket for load balancer access logs. Logging is skipped when null."
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = <<-EOT
    ACM certificate for the HTTPS listener. When null, only the HTTP listener
    is created, which is acceptable for a development environment and not for
    anything else.
  EOT
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
