output "cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.syslogs.name
  description = "The name of the CloudWatch log group that the executor hosts ship syslog to."
}
