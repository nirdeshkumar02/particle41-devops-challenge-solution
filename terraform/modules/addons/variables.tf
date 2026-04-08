variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version — used to resolve latest compatible add-on versions"
  type        = string
}

variable "name" {
  description = "Name prefix for resource tags"
  type        = string
}

variable "vpc_cni_role_arn" {
  description = "IRSA role ARN for the VPC CNI add-on"
  type        = string
}

variable "lb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  type        = string
}

variable "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for the Cluster Autoscaler"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — passed to the AWS Load Balancer Controller Helm chart"
  type        = string
}

variable "addon_vpc_cni_version" {
  description = "VPC CNI add-on version. Leave empty for latest compatible."
  type        = string
  default     = ""
}

variable "addon_coredns_version" {
  description = "CoreDNS add-on version. Leave empty for latest compatible."
  type        = string
  default     = ""
}

variable "addon_kube_proxy_version" {
  description = "kube-proxy add-on version. Leave empty for latest compatible."
  type        = string
  default     = ""
}

variable "addon_metrics_server_version" {
  description = "Metrics Server add-on version. Leave empty for latest compatible."
  type        = string
  default     = ""
}

variable "helm_lb_controller_version" {
  description = "AWS Load Balancer Controller Helm chart version. Leave empty for latest."
  type        = string
  default     = ""
}
