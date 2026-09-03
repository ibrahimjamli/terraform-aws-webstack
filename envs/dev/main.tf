# ---------------------------------------------------------------------------
# Development environment.
#
# Everything here is composition: the modules hold the logic, this file only
# decides how big, how many and how expensive.
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.project}-${var.environment}"

  # Two zones is the minimum for a load balancer; taking them from the API
  # rather than hardcoding keeps the config portable between regions.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # /20 per subnet leaves room to grow without renumbering: 10.20.0.0/20,
  # 10.20.16.0/20 public, then 10.20.32.0/20, 10.20.48.0/20 private.
  public_subnet_cidrs  = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i + 2)]
}

module "network" {
  source = "../../modules/network"

  name       = local.name
  cidr_block = var.vpc_cidr
  azs        = local.azs

  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs

  enable_nat_gateway = true
  # One gateway rather than one per zone: this is dev, and a NAT gateway is
  # roughly 35 EUR a month before any data charges.
  single_nat_gateway = true

  enable_flow_logs        = true
  flow_log_retention_days = 30
}

module "storage" {
  source = "../../modules/storage"

  name = local.name
  # Bucket names are globally unique; the account id keeps this deployable
  # into a second account without a collision.
  bucket_suffix = data.aws_caller_identity.current.account_id

  enable_access_logging = true
  # Dev only. This lets `terraform destroy` remove buckets that still hold
  # objects, which would be data loss anywhere else.
  force_destroy = true
}

module "security" {
  source = "../../modules/security"

  name           = local.name
  vpc_id         = module.network.vpc_id
  vpc_cidr_block = module.network.vpc_cidr_block
  app_port       = 8000
}

module "compute" {
  source = "../../modules/compute"

  name               = local.name
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  alb_security_group_id = module.security.alb_security_group_id
  app_security_group_id = module.security.app_security_group_id

  instance_type    = var.instance_type
  app_port         = 8000
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  certificate_arn = var.certificate_arn
}
