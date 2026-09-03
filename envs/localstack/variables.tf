variable "localstack_endpoint" {
  description = "Address of the LocalStack container."
  type        = string
  default     = "http://localhost:4566"
}

variable "name" {
  description = "Name prefix for the resources under test."
  type        = string
  default     = "webstack-ls"
}
