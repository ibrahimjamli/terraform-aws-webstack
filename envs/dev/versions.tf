terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.62"
    }
  }

  # Partial configuration: bucket, key and region are supplied by
  # `terraform init -backend-config=...` so this file carries no account
  # detail and the same code initialises against any account.
  #
  # Run ../../bootstrap once per account to create the bucket and lock table.
  backend "s3" {}
}

provider "aws" {
  region = var.region

  # Applied to every taggable resource without threading a variable through
  # each module. Cost allocation and "who owns this?" both depend on it.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "github.com/ibrahimjamli/terraform-aws-webstack"
    }
  }
}
