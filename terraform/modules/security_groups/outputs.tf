output "alb_security_group_id" {
  description = "ALB security group ID — attached to the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS security group ID — attached to Fargate tasks"
  value       = aws_security_group.ecs.id
}
