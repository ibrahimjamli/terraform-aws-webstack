# ---------------------------------------------------------------------------
# The subset of the stack that LocalStack's free tier emulates: VPC, subnets,
# routing, security groups and S3.
#
# Not included, because the free tier does not implement them: the application
# load balancer, the auto scaling group and the NAT gateway. Those are covered
# by `terraform validate` and by the plan job instead. Pretending otherwise
# would make this a green tick that proves nothing.
# ---------------------------------------------------------------------------

locals {
  azs = ["eu-north-1a", "eu-north-1b"]
}

module "network" {
  source = "../../modules/network"

  name       = var.name
  cidr_block = "10.99.0.0/16"
  azs        = local.azs

  public_subnet_cidrs  = ["10.99.0.0/24", "10.99.1.0/24"]
  private_subnet_cidrs = ["10.99.10.0/24", "10.99.11.0/24"]

  enable_nat_gateway = false
  enable_flow_logs   = false
}

module "security" {
  source = "../../modules/security"

  name           = var.name
  vpc_id         = module.network.vpc_id
  vpc_cidr_block = module.network.vpc_cidr_block
  app_port       = 8000
}

module "storage" {
  source = "../../modules/storage"

  name          = var.name
  bucket_suffix = "000000000000" # LocalStack's fixed account id

  # Access logging needs a bucket-to-bucket grant LocalStack does not enforce,
  # and force_destroy keeps the CI teardown clean.
  enable_access_logging = false
  force_destroy         = true

  # LocalStack accepts a lifecycle configuration and then does not return it,
  # so the provider's read-back poll never converges and the apply times out.
  # Lifecycle rules are covered by validate and the policy scan instead.
  enable_lifecycle_rules = false
}
