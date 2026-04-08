data "aws_caller_identity" "current" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-alb-sg"
  description = "Allow inbound HTTP from internet to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

module "ecs_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-ecs-sg"
  description = "Allow inbound from ALB to ECS tasks on container port only"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      description              = "App port from ALB"
      from_port                = var.container_port
      to_port                  = var.container_port
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  egress_rules = ["all-all"]

  tags = {
    Name = "${local.name}-ecs-sg"
  }
}

module "ecs_task_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role       = true
  role_name         = "${local.name}-task-execution-role"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]

  tags = {
    Name = "${local.name}-task-execution-role"
  }
}

module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role       = true
  role_name         = "${local.name}-task-role"
  role_requires_mfa = false

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  tags = {
    Name = "${local.name}-task-role"
  }
}

resource "aws_iam_role_policy" "task_cloudwatch_logs" {
  name = "${local.name}-task-cloudwatch-logs"
  role = module.ecs_task_role.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "FluentBitCloudWatchLogs"
      Effect = "Allow"
      Action = [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name    = "${local.name}-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  security_groups = [module.alb_sg.security_group_id]

  enable_deletion_protection = false

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "ecs-app"
      }
    }
  }

  target_groups = {
    "ecs-app" = {
      name              = "${local.name}-tg"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false

      health_check = {
        enabled             = true
        path                = var.health_check_path
        protocol            = "HTTP"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        interval            = 30
        timeout             = 5
        matcher             = "200"
      }
    }
  }

  tags = {
    Name = "${local.name}-alb"
  }
}

module "ecs" {
  source = "./modules/ecs"

  name         = local.name
  cluster_name = local.cluster_name
  aws_region   = var.aws_region

  container_image = var.container_image
  container_port  = var.container_port
  task_cpu        = var.task_cpu
  task_memory     = var.task_memory
  desired_count   = var.desired_count
  min_capacity    = var.min_capacity
  max_capacity    = var.max_capacity

  cpu_scale_threshold    = var.cpu_scale_threshold
  memory_scale_threshold = var.memory_scale_threshold

  log_retention_days = var.log_retention_days

  private_subnet_ids    = module.vpc.private_subnets
  ecs_security_group_id = module.ecs_sg.security_group_id
  target_group_arn      = module.alb.target_groups["ecs-app"].arn

  task_execution_role_arn = module.ecs_task_execution_role.iam_role_arn
  task_role_arn           = module.ecs_task_role.iam_role_arn
}
