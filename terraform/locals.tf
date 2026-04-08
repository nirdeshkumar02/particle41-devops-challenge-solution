locals {
  name         = "${var.project}-${var.environment}"
  cluster_name = "${local.name}-cluster"
}
