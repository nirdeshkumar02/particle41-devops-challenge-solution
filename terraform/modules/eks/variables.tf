variable "name" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for worker nodes"
  type        = string
}

variable "all_subnet_ids" {
  description = "All subnet IDs (public + private) — EKS places control plane ENIs here"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — nodes are placed only in private subnets"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID for the EKS control plane"
  type        = string
}

variable "node_security_group_id" {
  description = "Security group ID for worker nodes"
  type        = string
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
}

variable "node_ami_type" {
  description = "AMI type — AL2023_x86_64_STANDARD required for K8s 1.33+"
  type        = string
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size in GiB"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
}

variable "node_desired_size" {
  description = "Desired number of nodes at launch"
  type        = number
}

variable "node_max_size" {
  description = "Maximum nodes the autoscaler can scale to"
  type        = number
}
