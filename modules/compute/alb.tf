# ---------------------------------------------------------------------------
# Application load balancer. Deletion protection is deliberately left off so
# the example can be torn down; a production copy of this module should set it.
# ---------------------------------------------------------------------------

resource "aws_lb" "this" {
  name_prefix        = substr(var.name, 0, 6)
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]

  # Stops a request being interpreted differently by the load balancer and the
  # backend, which is the basis of request-smuggling attacks.
  drop_invalid_header_fields = true

  enable_deletion_protection = false
  idle_timeout               = 60

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [var.access_logs_bucket]

    content {
      bucket  = access_logs.value
      prefix  = "alb"
      enabled = true
    }
  }

  tags = merge(local.tags, { Name = "${var.name}-alb" })
}

resource "aws_lb_target_group" "this" {
  name_prefix = substr(var.name, 0, 6)
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # Give in-flight requests time to finish before a draining target is cut off.
  deregistration_delay = 30

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

# With a certificate, port 80 exists only to bounce clients to HTTPS. Without
# one, it serves traffic directly, which is why certificate_arn should be set
# outside development.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.certificate_arn == null ? [] : [1]

    content {
      type = "redirect"

      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == null ? [1] : []

    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.certificate_arn == null ? 0 : 1

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  # Excludes TLS 1.0 and 1.1, which are no longer acceptable.
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
