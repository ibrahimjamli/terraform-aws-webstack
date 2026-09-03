terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.62"
    }
  }
  # Local state on purpose: this environment is created and destroyed inside a
  # single CI job, so there is nothing worth keeping.
}

# ---------------------------------------------------------------------------
# Points the AWS provider at LocalStack instead of Amazon.
#
# The value of this environment is that `terraform apply` genuinely runs: the
# API calls are made, dependency ordering is exercised, and the resources are
# read back and asserted on. `terraform validate` alone would catch none of
# that, and a real AWS account for CI costs money and leaks credentials into
# a public repository.
# ---------------------------------------------------------------------------
provider "aws" {
  region = "eu-north-1"

  # LocalStack ignores these, but the provider refuses to start without them.
  access_key = "test"
  secret_key = "test"

  # Every one of these would otherwise make a live call to Amazon.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  # LocalStack serves buckets on a path rather than a virtual host.
  s3_use_path_style = true

  endpoints {
    ec2 = var.localstack_endpoint
    iam = var.localstack_endpoint
    s3  = var.localstack_endpoint
    sts = var.localstack_endpoint
  }

  default_tags {
    tags = {
      Project     = "webstack"
      Environment = "localstack"
      ManagedBy   = "terraform"
    }
  }
}
