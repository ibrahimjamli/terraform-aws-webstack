output "alb_security_group_id" {
  description = "Security group attached to the load balancer."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group attached to the application instances."
  value       = aws_security_group.app.id
}
