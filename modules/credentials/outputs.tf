output "metric_writer_access_key_id" {
  value = aws_iam_access_key.metric_writer.id
}

output "metric_writer_secret_key" {
  value = aws_iam_access_key.metric_writer.secret
}

output "instance_scraper_access_key_id" {
  value = aws_iam_access_key.instance_scraper.id
}

output "instance_scraper_access_secret_key" {
  value = aws_iam_access_key.instance_scraper.secret
}
