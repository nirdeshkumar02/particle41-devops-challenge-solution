output "task_execution_role_arn" {
  description = "ECS task execution role ARN — used by the ECS agent to pull images and write logs"
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ECS task role ARN — assumed by the application container"
  value       = aws_iam_role.task.arn
}
