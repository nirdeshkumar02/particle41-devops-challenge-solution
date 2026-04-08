variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name — used as prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev / staging / production)"
  type        = string
}

variable "owner" {
  description = "Team or person responsible — used in default tags"
  type        = string
}

variable "cost_center" {
  description = "Cost center code for billing visibility"
  type        = string
  default     = "engineering"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "Primary AZ"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_secondary" {
  description = "Secondary AZ — EKS requires subnets in 2+ AZs"
  type        = string
  default     = "us-east-1b"
}

variable "public_subnet_cidr" {
  description = "CIDR for primary public subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "private_subnet_cidr" {
  description = "CIDR for primary private subnet"
  type        = string
  default     = "10.0.128.0/20"
}

variable "public_subnet_secondary_cidr" {
  description = "CIDR for secondary public subnet"
  type        = string
  default     = "10.0.16.0/20"
}

variable "private_subnet_secondary_cidr" {
  description = "CIDR for secondary private subnet"
  type        = string
  default     = "10.0.144.0/20"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to the EKS API endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_retention_days" {
  description = "CloudWatch log retention in days for EKS control plane logs"
  type        = number
  default     = 7
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "m7i-flex.large"
}

variable "node_ami_type" {
  description = "AMI type for worker nodes"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_disk_size_gb" {
  description = "Root EBS volume size in GiB per node"
  type        = number
  default     = 50
}

variable "node_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired number of nodes at launch"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 5
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
