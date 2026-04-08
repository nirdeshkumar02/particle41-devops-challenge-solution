variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "aws_region" {
  description = "AWS region — used for S3 VPC endpoint service name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zone" {
  description = "Primary AZ — NAT Gateway lives here"
  type        = string
}

variable "availability_zone_secondary" {
  description = "Secondary AZ — ALB and ECS tasks span both AZs for high availability"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR for primary public subnet (ALB + NAT Gateway)"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR for primary private subnet (ECS Fargate tasks)"
  type        = string
}

variable "public_subnet_secondary_cidr" {
  description = "CIDR for secondary public subnet"
  type        = string
}

variable "private_subnet_secondary_cidr" {
  description = "CIDR for secondary private subnet (ECS Fargate tasks)"
  type        = string
}
