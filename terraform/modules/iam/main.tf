# Task Execution Role — used by the ECS agent to pull images and write logs
resource "aws_iam_role" "task_execution" {
  name = "${var.name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ECSTasksAssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name}-task-execution-role"
  }
}

# Grants ECS agent permissions to pull images from ECR and write to CloudWatch Logs
resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role — assumed by the application container itself (app-level AWS calls)
resource "aws_iam_role" "task" {
  name = "${var.name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ECSTasksAssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name}-task-role"
  }
}

# Fluent Bit runs inside the task and uses the task role to ship logs to CloudWatch.
# The execution role covers the ECS agent; the task role covers in-container AWS calls.
resource "aws_iam_role_policy" "task_cloudwatch_logs" {
  name = "${var.name}-task-cloudwatch-logs"
  role = aws_iam_role.task.id

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
