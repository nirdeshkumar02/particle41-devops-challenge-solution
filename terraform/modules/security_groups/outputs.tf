output "cluster_security_group_id" {
  description = "Cluster SG ID — attached to the EKS control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Node SG ID — needed for Karpenter EC2NodeClass and node group"
  value       = aws_security_group.nodes.id
}
