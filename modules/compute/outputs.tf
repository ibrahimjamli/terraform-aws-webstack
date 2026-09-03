output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone of the load balancer, for a Route 53 alias record."
  value       = aws_lb.this.zone_id
}

output "alb_arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "ARN of the target group."
  value       = aws_lb_target_group.this.arn
}

output "autoscaling_group_name" {
  description = "Name of the auto scaling group."
  value       = aws_autoscaling_group.this.name
}

output "instance_role_arn" {
  description = "ARN of the IAM role attached to the instances."
  value       = aws_iam_role.instance.arn
}

output "instance_role_name" {
  description = "Name of the IAM role attached to the instances."
  value       = aws_iam_role.instance.name
}
