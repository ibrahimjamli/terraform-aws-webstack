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
  name           = "unit"
  vpc_id         = "vpc-0123456789abcdef0"
  vpc_cidr_block = "10.0.0.0/16"
}

run "the_app_tier_is_not_reachable_from_the_internet" {
  command = plan

  # The only ingress rule on the app group references the load balancer's
  # security group. If a CIDR rule ever appears here, something has gone wrong.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv4 == null
    error_message = "The application tier must only accept traffic from the load balancer."
  }

  # The referenced group id is not known until apply, so the assertion is
  # framed as the absence of any address-range rule instead.
  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv6 == null
    error_message = "The application tier must not accept traffic from an IPv6 range either."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.ip_protocol == "tcp"
    error_message = "App ingress should be limited to TCP."
  }
}

run "load_balancer_egress_is_scoped_to_the_vpc" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_egress_rule.alb_to_app.cidr_ipv4 == "10.0.0.0/16"
    error_message = "The load balancer should not be able to reach anything outside the VPC."
  }
}

run "the_app_port_is_honoured" {
  command = plan

  variables {
    app_port = 9090
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.from_port == 9090
    error_message = "The ingress rule must follow the configured application port."
  }
}

run "ingress_can_be_narrowed_from_the_public_default" {
  command = plan

  variables {
    ingress_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_https) == 2
    error_message = "One HTTPS rule should be created per permitted range."
  }
}
