output "vpc_cni_role_arn" {
  description = "VPC CNI IRSA role ARN — pass to vpc-cni add-on"
  value       = aws_iam_role.vpc_cni.arn
}

output "lb_controller_role_arn" {
  description = "AWS Load Balancer Controller IRSA role ARN"
  value       = aws_iam_role.lb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IRSA role ARN"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "cloudwatch_agent_role_arn" {
  description = "CloudWatch Agent IRSA role ARN — annotate the app service account with this"
  value       = aws_iam_role.cloudwatch_agent.arn
}
