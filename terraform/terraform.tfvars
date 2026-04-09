aws_region  = "us-east-1"
project     = "particle41"
environment = "production"
owner       = "nirdesh"
cost_center = "engineering"

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]

container_image   = "nirdeshkumar02/simpletimeservice:0.0.1"
container_port    = 8080
health_check_path = "/health"

task_cpu      = 256
task_memory   = 512
desired_count = 2
min_capacity  = 1
max_capacity  = 5

cpu_scale_threshold    = 60
memory_scale_threshold = 60

log_retention_days = 7
