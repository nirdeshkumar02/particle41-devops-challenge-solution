output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (both AZs)"
  value       = [aws_subnet.public.id, aws_subnet.public_secondary.id]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (both AZs) — used for EKS node placement"
  value       = [aws_subnet.private.id, aws_subnet.private_secondary.id]
}

output "all_subnet_ids" {
  description = "All subnet IDs — passed to EKS control plane for ENI placement"
  value = [
    aws_subnet.public.id,
    aws_subnet.public_secondary.id,
    aws_subnet.private.id,
    aws_subnet.private_secondary.id,
  ]
}

output "public_subnet_id" {
  description = "Primary public subnet ID"
  value       = aws_subnet.public.id
}

output "public_subnet_secondary_id" {
  description = "Secondary public subnet ID"
  value       = aws_subnet.public_secondary.id
}

output "private_subnet_id" {
  description = "Primary private subnet ID"
  value       = aws_subnet.private.id
}

output "private_subnet_secondary_id" {
  description = "Secondary private subnet ID"
  value       = aws_subnet.private_secondary.id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway EIP — add to allowlists in external services"
  value       = aws_eip.nat.public_ip
}
