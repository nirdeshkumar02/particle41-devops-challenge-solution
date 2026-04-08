resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  # Enables CPU, memory, network, and task-level metrics in CloudWatch
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = var.cluster_name
  }
}

# Log group for both the app and Fluent Bit sidecar logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/ecs/${var.name}"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    # ── App container ──────────────────────────────────────────────────────────
    {
      name      = "simpletimeservice"
      image     = var.container_image
      essential = true

      portMappings = [{
        containerPort = 8080
        protocol      = "tcp"
      }]

      # Wait for Fluent Bit to start before the app container begins logging
      dependsOn = [{
        containerName = "log_router"
        condition     = "START"
      }]

      # Enforce non-root execution at the task level (mirrors Dockerfile USER)
      user = "1001"

      # Resource limits — prevent runaway memory/CPU from impacting other tasks
      # These match the task-level cpu/memory so the single container gets all resources
      # (adjust if adding more sidecars)

      healthCheck = {
        # wget (busybox) is always present in Alpine; curl is not
        command     = ["CMD-SHELL", "wget -qO /dev/null http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name              = "cloudwatch"
          region            = var.aws_region
          log_group_name    = aws_cloudwatch_log_group.app.name
          log_stream_prefix = "app/"
          auto_create_group = "false"
        }
      }

      environment = [
        {
          name  = "PORT"
          value = "8080"
        }
      ]
    },

    # ── Fluent Bit sidecar ─────────────────────────────────────────────────────
    # Collects stdout/stderr from the app container and ships to CloudWatch Logs
    {
      name      = "log_router"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
      essential = false

      firelensConfiguration = {
        type = "fluentbit"
      }

      # Verify the Fluent Bit process is alive; non-essential so a failure won't kill the task
      healthCheck = {
        command     = ["CMD-SHELL", "pgrep -x fluent-bit > /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      # Fluent Bit's own logs go to CloudWatch via the awslogs driver
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "fluent-bit"
        }
      }
    }
  ])

  tags = {
    Name = var.name
  }
}

resource "aws_ecs_service" "app" {
  name            = var.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Replace old tasks before terminating running ones during deployments
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false # Tasks stay private — egress via NAT Gateway
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "simpletimeservice"
    container_port   = 8080
  }

  # Ignore desired_count changes made by autoscaling outside of Terraform
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name = var.name
  }
}

# ── Auto Scaling ───────────────────────────────────────────────────────────────

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale out when average CPU > 70% for 2 consecutive minutes
resource "aws_appautoscaling_policy" "scale_out_cpu" {
  name               = "${var.name}-scale-out-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_scale_threshold
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Scale out when average memory > 80%
resource "aws_appautoscaling_policy" "scale_out_memory" {
  name               = "${var.name}-scale-out-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.memory_scale_threshold
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
