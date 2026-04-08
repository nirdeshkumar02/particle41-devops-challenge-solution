variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs — ALB must be deployed in public subnets"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID to attach to the ALB"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path for ALB target group health checks"
  type        = string
  default     = "/health"
}
