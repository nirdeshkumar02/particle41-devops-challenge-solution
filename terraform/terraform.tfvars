aws_region  = "us-east-1"
project     = "particle41"
environment = "production"
owner       = "nirdesh"
cost_center = "engineering"

# Networking
vpc_cidr                      = "10.0.0.0/16"
availability_zone             = "us-east-1a"
availability_zone_secondary   = "us-east-1b"
public_subnet_cidr            = "10.0.0.0/20"
private_subnet_cidr           = "10.0.128.0/20"
public_subnet_secondary_cidr  = "10.0.16.0/20"
private_subnet_secondary_cidr = "10.0.144.0/20"

# Application — pin to a specific version, never use latest in production
container_image   = "nirdeshkumar02/simpletimeservice:latest"
health_check_path = "/health"

# ECS Fargate
task_cpu      = 256
task_memory   = 512
desired_count = 2
min_capacity  = 2
max_capacity  = 10

# Autoscaling thresholds
cpu_scale_threshold    = 70  # scale-out when average CPU  > 70%
memory_scale_threshold = 80  # scale-out when average mem  > 80%

# Observability
log_retention_days = 7
