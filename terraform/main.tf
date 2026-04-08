data "aws_caller_identity" "current" {}

module "vpc" {
  source = "./modules/vpc"

  name         = local.name
  cluster_name = local.cluster_name
  aws_region   = var.aws_region

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

  name         = local.name
  cluster_name = local.cluster_name
  vpc_id       = module.vpc.vpc_id
}

module "iam" {
  source = "./modules/iam"

  name = local.name
}

module "eks" {
  source = "./modules/eks"

  name         = local.name
  cluster_name = local.cluster_name

  cluster_version                      = var.cluster_version
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_log_retention_days           = var.cluster_log_retention_days

  cluster_role_arn          = module.iam.cluster_role_arn
  node_role_arn             = module.iam.node_role_arn
  all_subnet_ids            = module.vpc.all_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  cluster_security_group_id = module.security_groups.cluster_security_group_id
  node_security_group_id    = module.security_groups.node_security_group_id

  node_instance_type = var.node_instance_type
  node_ami_type      = var.node_ami_type
  node_disk_size_gb  = var.node_disk_size_gb
  node_min_size      = var.node_min_size
  node_desired_size  = var.node_desired_size
  node_max_size      = var.node_max_size
}

module "irsa" {
  source = "./modules/irsa"

  name              = local.name
  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
}

module "addons" {
  source = "./modules/addons"

  name            = local.name
  cluster_name    = module.eks.cluster_name
  cluster_version = module.eks.cluster_version

  vpc_cni_role_arn            = module.irsa.vpc_cni_role_arn
  lb_controller_role_arn      = module.irsa.lb_controller_role_arn
  cluster_autoscaler_role_arn = module.irsa.cluster_autoscaler_role_arn
  vpc_id                      = module.vpc.vpc_id

  addon_vpc_cni_version        = var.addon_vpc_cni_version
  addon_coredns_version        = var.addon_coredns_version
  addon_kube_proxy_version     = var.addon_kube_proxy_version
  addon_metrics_server_version = var.addon_metrics_server_version
}
