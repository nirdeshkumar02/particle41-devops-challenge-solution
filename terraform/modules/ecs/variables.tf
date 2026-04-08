variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "aws_region" {
  description = "AWS region — used in log configuration"
  type        = string
}

variable "container_image" {
  description = "Full container image reference including tag (e.g. nirdeshkumar02/simpletimeservice:0.0.1)"
  type        = string
}

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

variable "cpu_scale_threshold" {
  description = "Target CPU utilisation percentage that triggers scale-out (e.g. 70 = scale when avg CPU > 70%)"
  type        = number
  default     = 70
}

variable "memory_scale_threshold" {
  description = "Target memory utilisation percentage that triggers scale-out (e.g. 80 = scale when avg memory > 80%)"
  type        = number
  default     = 80
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — ECS tasks run here with no public IP"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN for load balancer registration"
  type        = string
}

variable "task_execution_role_arn" {
  description = "IAM role ARN for the ECS task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "IAM role ARN assumed by the application container"
  type        = string
}
