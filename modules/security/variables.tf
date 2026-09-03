variable "name" {
  description = "Name prefix for the security groups."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security groups belong to."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR, used to scope internal egress."
  type        = string
}

variable "ingress_cidrs" {
  description = <<-EOT
    Who may reach the load balancer. Defaults to the whole internet because a
    public web tier is the point of this stack; narrow it for internal apps.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Port the application listens on behind the load balancer."
  type        = number
  default     = 8000
}

variable "tags" {
  description = "Tags merged into every resource."
  type        = map(string)
  default     = {}
}
