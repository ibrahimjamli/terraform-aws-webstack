variable "region" {
  description = "Region to hold the state bucket and lock table."
  type        = string
  default     = "eu-north-1"
}

variable "name" {
  description = "Name prefix for the backend resources."
  type        = string
  default     = "webstack-tfstate"
}
