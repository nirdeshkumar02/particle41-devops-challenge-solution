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

# ── Networking ─────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone" {
  description = "Primary AZ — NAT Gateway and first set of subnets live here"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_secondary" {
  description = "Secondary AZ — ALB and ECS tasks span both AZs for high availability"
  type        = string
  default     = "us-east-1b"
}

variable "public_subnet_cidr" {
  description = "CIDR for primary public subnet (ALB + NAT Gateway)"
  type        = string
  default     = "10.0.0.0/20"
}

variable "private_subnet_cidr" {
  description = "CIDR for primary private subnet (ECS Fargate tasks)"
  type        = string
  default     = "10.0.128.0/20"
}

variable "public_subnet_secondary_cidr" {
  description = "CIDR for secondary public subnet"
  type        = string
  default     = "10.0.16.0/20"
}

variable "private_subnet_secondary_cidr" {
  description = "CIDR for secondary private subnet (ECS Fargate tasks)"
  type        = string
  default     = "10.0.144.0/20"
}

# ── Application ────────────────────────────────────────────────────────────────

variable "container_image" {
  description = "Full container image reference including tag (e.g. nirdeshkumar02/simpletimeservice:0.0.1)"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path used by the ALB target group health check"
  type        = string
  default     = "/health"
}

# ── ECS Fargate ────────────────────────────────────────────────────────────────

variable "task_cpu" {
  description = "CPU units for the Fargate task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory in MiB for the Fargate task"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Initial number of ECS task replicas"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}
