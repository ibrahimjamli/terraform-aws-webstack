variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-north-1"
}

variable "project" {
  description = "Project name, used as the prefix for every resource."
  type        = string
  default     = "webstack"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the application tier."
  type        = string
  default     = "t3.micro"
}

variable "certificate_arn" {
  description = "ACM certificate for the HTTPS listener. Null serves plain HTTP."
  type        = string
  default     = null
}
