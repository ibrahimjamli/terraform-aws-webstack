# ---------------------------------------------------------------------------
# Two security groups with a one-way relationship: the internet may reach the
# load balancer, the load balancer may reach the application, and nothing may
# reach the application directly.
#
# Rules are separate aws_vpc_security_group_*_rule resources rather than inline
# blocks. Inline rules are authoritative for the whole group, so two modules
# touching one group silently delete each other's rules.
# ---------------------------------------------------------------------------

locals {
  tags = merge(var.tags, { Module = "security" })
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public entry point for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from ${each.value}"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "HTTP from ${each.value}, redirected to HTTPS by the listener"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# The load balancer only ever talks to the app tier, so egress is scoped to the
# VPC rather than left as the default allow-all.
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id
  description       = "Forward to the application tier"
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = var.app_port
  to_port           = var.app_port
  ip_protocol       = "tcp"
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Application tier for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-app" })

  lifecycle {
    create_before_destroy = true
  }
}

# Referencing the load balancer's group rather than a CIDR means the rule stays
# correct however the load balancer's addresses change.
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application traffic from the load balancer only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# Outbound HTTPS is needed for package installs and the SSM agent. There is no
# inbound SSH rule anywhere in this module: shell access is via SSM Session
# Manager, which leaves an audit trail and needs no open port.
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound HTTPS for package installs and SSM"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound HTTP for package repositories"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}
