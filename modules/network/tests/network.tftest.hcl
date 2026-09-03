# Terraform's native test framework. Every run below is `command = plan`, so
# the suite needs no AWS account and no credentials, and finishes in seconds.

provider "aws" {
  region                      = "eu-north-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
}

variables {
  name                 = "unit"
  cidr_block           = "10.0.0.0/16"
  azs                  = ["eu-north-1a", "eu-north-1b"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

run "one_subnet_of_each_tier_per_availability_zone" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Expected one public subnet per availability zone."
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Expected one private subnet per availability zone."
  }
}

run "private_subnets_never_assign_public_addresses" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.map_public_ip_on_launch == false])
    error_message = "A private subnet was configured to assign public IPs on launch."
  }
}

run "dns_resolution_is_enabled_on_the_vpc" {
  command = plan

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "Both DNS settings are required for private endpoint names to resolve."
  }
}

run "one_nat_gateway_per_zone_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "The resilient default should place a NAT gateway in every zone."
  }
}

run "single_nat_gateway_collapses_to_one" {
  command = plan

  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway should produce exactly one gateway."
  }

  assert {
    condition     = length(aws_route.private_default) == 2
    error_message = "Every private subnet still needs a default route to the shared gateway."
  }
}

run "disabling_nat_removes_gateways_and_default_routes" {
  command = plan

  variables {
    enable_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "No NAT gateway should be planned when NAT is disabled."
  }

  assert {
    condition     = length(aws_route.private_default) == 0
    error_message = "A default route pointing at a nonexistent gateway would fail to apply."
  }
}

run "flow_logs_can_be_switched_off" {
  command = plan

  variables {
    enable_flow_logs = false
  }

  assert {
    condition     = length(aws_flow_log.this) == 0
    error_message = "Flow logs should not be planned when disabled."
  }

  assert {
    condition     = length(aws_iam_role.flow_logs) == 0
    error_message = "The flow-log role is pointless without the flow log itself."
  }
}

run "rejects_a_single_availability_zone" {
  command = plan

  variables {
    azs                  = ["eu-north-1a"]
    public_subnet_cidrs  = ["10.0.0.0/24"]
    private_subnet_cidrs = ["10.0.10.0/24"]
  }

  expect_failures = [var.azs]
}

run "rejects_a_malformed_cidr" {
  command = plan

  variables {
    cidr_block = "not-a-cidr"
  }

  expect_failures = [var.cidr_block]
}

run "rejects_a_subnet_list_that_does_not_match_the_zone_count" {
  command = plan

  variables {
    public_subnet_cidrs = ["10.0.0.0/24"]
  }

  expect_failures = [var.public_subnet_cidrs]
}
