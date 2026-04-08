output "app_url" {
  description = "Application URL — access the running service at this address"
  value       = "http://${module.alb.alb_dns_name}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway EIP — outbound IP for ECS tasks"
  value       = module.vpc.nat_gateway_public_ip
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "log_group_name" {
  description = "CloudWatch log group for application logs"
  value       = module.ecs.log_group_name
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}
