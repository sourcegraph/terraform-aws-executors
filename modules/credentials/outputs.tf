output "metric_writer_access_key_id" {
  value       = aws_iam_access_key.metric_writer.id
  description = "The ID of the Metrics Writer Service Account."
}

output "metric_writer_secret_key" {
  value       = aws_iam_access_key.metric_writer.secret
  description = "The secret key of the Metrics Writer Service Account."
}
