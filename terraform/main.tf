data "aws_caller_identity" "current" {}

module "vpc" {
  source = "./modules/vpc"

  name       = local.name
  aws_region = var.aws_region

  vpc_cidr                      = var.vpc_cidr
  availability_zone             = var.availability_zone
  availability_zone_secondary   = var.availability_zone_secondary
  public_subnet_cidr            = var.public_subnet_cidr
  private_subnet_cidr           = var.private_subnet_cidr
  public_subnet_secondary_cidr  = var.public_subnet_secondary_cidr
  private_subnet_secondary_cidr = var.private_subnet_secondary_cidr
}

module "security_groups" {
  source = "./modules/security_groups"

  name   = local.name
  vpc_id = module.vpc.vpc_id
}

module "iam" {
  source = "./modules/iam"

  name = local.name
}

module "alb" {
  source = "./modules/alb"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  health_check_path     = var.health_check_path
}

module "ecs" {
  source = "./modules/ecs"

  name         = local.name
  cluster_name = local.cluster_name
  aws_region   = var.aws_region

  container_image = var.container_image
  task_cpu        = var.task_cpu
  task_memory     = var.task_memory
  desired_count   = var.desired_count
  min_capacity    = var.min_capacity
  max_capacity    = var.max_capacity

  cpu_scale_threshold    = var.cpu_scale_threshold
  memory_scale_threshold = var.memory_scale_threshold

  log_retention_days = var.log_retention_days

  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id
  target_group_arn      = module.alb.target_group_arn

  task_execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn           = module.iam.task_role_arn
}
