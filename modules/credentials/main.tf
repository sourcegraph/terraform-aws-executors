locals {
  prefix = var.resource_prefix != "" ? "${var.resource_prefix}-sg-" : "sg-"
}

resource "aws_iam_user" "metric_writer" {
  name = "${substr(local.prefix, 0, 14)}-metric-writer"
}

resource "aws_iam_user_policy" "metric_writer" {
  name = "${substr(var.resource_prefix, 0, 16)}MetricWriter"
  user = aws_iam_user.metric_writer.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_access_key" "metric_writer" {
  user = aws_iam_user.metric_writer.name
}

resource "aws_iam_user" "instance_scraper" {
  name = "${substr(local.prefix, 0, 11)}-instance-scraper"
}

resource "aws_iam_policy_attachment" "instance_scraper" {
  name       = "${substr(var.resource_prefix, 0, 11)}InstanceScraper"
  users      = [aws_iam_user.instance_scraper.name]
  groups     = ["readonly"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_access_key" "instance_scraper" {
  user = aws_iam_user.instance_scraper.name
}
