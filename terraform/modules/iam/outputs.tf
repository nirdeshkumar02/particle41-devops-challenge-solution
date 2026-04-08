output "cluster_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "Node group IAM role ARN"
  value       = aws_iam_role.node_group.arn
}

output "node_role_name" {
  description = "Node group IAM role name — used for policy attachments in other modules"
  value       = aws_iam_role.node_group.name
}
