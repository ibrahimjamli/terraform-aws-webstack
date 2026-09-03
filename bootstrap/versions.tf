terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
  # Local state on purpose: this configuration creates the remote backend, so
  # it cannot use it. Commit the resulting terraform.tfstate, or re-import.
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "webstack"
      Purpose   = "terraform-state"
      ManagedBy = "terraform"
    }
  }
}
