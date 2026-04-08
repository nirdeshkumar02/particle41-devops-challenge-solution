variable "name" {
  description = "Name prefix for IRSA roles"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used in Cluster Autoscaler trust policy condition"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from the EKS cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL (with https://) — stripped internally for trust policies"
  type        = string
}
