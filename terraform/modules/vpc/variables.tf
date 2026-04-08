variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used for subnet discovery tags"
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
  description = "Secondary AZ — EKS requires subnets in 2+ AZs"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR for primary public subnet (NAT Gateway + ALB)"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR for primary private subnet (EKS nodes)"
  type        = string
}

variable "public_subnet_secondary_cidr" {
  description = "CIDR for secondary public subnet"
  type        = string
}

variable "private_subnet_secondary_cidr" {
  description = "CIDR for secondary private subnet (EKS nodes)"
  type        = string
}
