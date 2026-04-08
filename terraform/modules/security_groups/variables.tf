variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to create security groups in"
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on — ECS SG allows inbound from ALB on this port"
  type        = number
  default     = 8080
}
