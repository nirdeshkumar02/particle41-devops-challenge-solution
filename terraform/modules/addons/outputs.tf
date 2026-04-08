output "vpc_cni_version" {
  description = "Installed VPC CNI add-on version"
  value       = aws_eks_addon.vpc_cni.addon_version
}

output "coredns_version" {
  description = "Installed CoreDNS add-on version"
  value       = aws_eks_addon.coredns.addon_version
}

output "kube_proxy_version" {
  description = "Installed kube-proxy add-on version"
  value       = aws_eks_addon.kube_proxy.addon_version
}

output "metrics_server_version" {
  description = "Installed Metrics Server add-on version"
  value       = aws_eks_addon.metrics_server.addon_version
}
