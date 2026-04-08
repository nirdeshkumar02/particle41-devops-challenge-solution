output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (both AZs) — used for ALB placement"
  value       = [aws_subnet.public.id, aws_subnet.public_secondary.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (both AZs) — used for ECS task placement"
  value       = [aws_subnet.private.id, aws_subnet.private_secondary.id]
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway EIP — outbound IP for ECS tasks"
  value       = aws_eip.nat.public_ip
}
