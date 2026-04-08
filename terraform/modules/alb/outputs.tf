output "alb_dns_name" {
  description = "ALB DNS name — use this to access the application"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Target group ARN — passed to the ECS service for load balancer registration"
  value       = aws_lb_target_group.app.arn
}
