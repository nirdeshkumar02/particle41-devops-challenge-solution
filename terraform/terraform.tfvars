aws_region  = "us-east-1"
project     = "particle41"
environment = "production"
owner       = "nirdesh"
cost_center = "engineering"

vpc_cidr                      = "10.0.0.0/16"
availability_zone             = "us-east-1a"
availability_zone_secondary   = "us-east-1b"
public_subnet_cidr            = "10.0.0.0/20"
private_subnet_cidr           = "10.0.128.0/20"
public_subnet_secondary_cidr  = "10.0.16.0/20"
private_subnet_secondary_cidr = "10.0.144.0/20"

cluster_version                      = "1.34"
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
cluster_log_retention_days           = 7

node_instance_type = "m7i-flex.large"
node_ami_type      = "AL2023_x86_64_STANDARD"
node_disk_size_gb  = 50
node_min_size      = 2
node_desired_size  = 2
node_max_size      = 5

addon_vpc_cni_version        = ""
addon_coredns_version        = ""
addon_kube_proxy_version     = ""
addon_metrics_server_version = ""
