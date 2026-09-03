# ---------------------------------------------------------------------------
# A two-tier VPC: public subnets that reach the internet directly, private
# subnets that reach it only outbound through NAT.
#
# Subnet counts are driven by the length of var.azs, so adding a third zone is
# a one-line change rather than a copy-paste of every resource.
# ---------------------------------------------------------------------------

locals {
  az_count = length(var.azs)

  tags = merge(var.tags, {
    Module = "network"
  })

  # One NAT gateway per zone is the resilient default; single_nat_gateway
  # collapses that to one for environments where cost matters more.
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block

  # Both are required for private DNS names on interface endpoints to resolve.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = var.name })
}

# The default security group allows all traffic between its members. Leaving it
# in place is a common finding in security reviews, so it is emptied here
# rather than deleted (AWS does not permit deleting it).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-default-do-not-use" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-igw" })
}

# --- subnets ---------------------------------------------------------------

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Instances here are reachable from the internet by design; anything that
  # should not be goes in the private tier.
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                     = "${var.name}-public-${var.azs[count.index]}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name                              = "${var.name}-private-${var.azs[count.index]}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# --- NAT -------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.name}-nat-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, { Name = "${var.name}-nat-${count.index}" })

  # Without this the gateway can be created before the VPC has a route out.
  depends_on = [aws_internet_gateway.this]
}

# --- routing ---------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One route table per private subnet, so each can point at the NAT gateway in
# its own zone and cross-zone data charges are avoided.
resource "aws_route_table" "private" {
  count = local.az_count

  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-private-${var.azs[count.index]}" })
}

resource "aws_route" "private_default" {
  count = var.enable_nat_gateway ? local.az_count : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
