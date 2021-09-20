locals {
  autoscaling = var.min_replicas != var.max_replicas
  prefix      = var.resource_prefix != "" ? "${var.resource_prefix}_sourcegraph_" : "sourcegraph_"
}

data "aws_iam_policy" "cloudwatch" {
  name = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_role" "cloudwatch-assignment" {
  name = "${local.prefix}executors_cloudwatch"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.prefix}executors_cloudwatch"
  role = aws_iam_role.cloudwatch-assignment.name
}

resource "aws_iam_policy_attachment" "cloudwatch" {
  policy_arn = data.aws_iam_policy.cloudwatch.arn
  # TODO: this keeps overwriting each other.
  roles = [aws_iam_role.cloudwatch-assignment.name, "sourcegraph_executors_docker_mirror_cloudwatch"]
  name  = "${var.resource_prefix}SourcegraphExecutorsCloudWatch"
}

# Allow access to running instances over SSH and on port 6060 to scrape metrics.
resource "aws_security_group" "metrics_access" {
  name   = "${var.resource_prefix}SourcegraphExecutorsMetricsAccess"
  vpc_id = var.vpc_id

  ingress {
    cidr_blocks = [var.ssh_access_cidr_range]
    description = "Allow SSH access"
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
  }

  # Only allow access from other instances to scrape metrics.
  # TODO: Restrict this to not be 0.0.0.0/0.
  ingress {
    cidr_blocks = [var.http_access_cidr_range]
    description = "Allow access to scrape metrics"
    from_port   = 6060
    protocol    = "TCP"
    to_port     = 6060
  }

  # Allow all outgoing network traffic.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_cloudwatch_log_group" "syslogs" {
  # TODO: This is hardcoded in the executor image.
  name              = "executors"
  retention_in_days = 7
}

# Template for the instances launched by the autoscaling group.
# We always organize instances in an auto scaling group, even when autoscaling
# is not enabled. This doesn't actually auto-scale until you attach an autoscaling
# policy.
resource "aws_launch_template" "executor" {
  instance_type = var.machine_type
  image_id      = var.machine_image

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.boot_disk_size
      volume_type = "gp2"
    }
  }

  instance_initiated_shutdown_behavior = "terminate"

  name_prefix = "${local.prefix}executor-template-"

  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = var.subnet_id
    # Attach security group.
    security_groups = [aws_security_group.metrics_access.id]
  }

  monitoring {
    enabled = true
  }

  instance_market_options {
    market_type = var.preemptible_machines ? "spot" : null
    spot_options {
      spot_instance_type = "one-time"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  # Render the startup script using all variables defined.
  user_data = base64encode(templatefile("${path.module}/startup-script.sh.tpl", {
    environment_variables = {
      "EXECUTOR_DOCKER_REGISTRY_MIRROR"     = var.executor_docker_registry_mirror
      "SOURCEGRAPH_EXTERNAL_URL"            = var.sourcegraph_external_url
      "SOURCEGRAPH_EXECUTOR_PROXY_USERNAME" = var.sourcegraph_executor_proxy_username
      "SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD" = var.sourcegraph_executor_proxy_password
      "EXECUTOR_MAXIMUM_NUM_JOBS"           = var.executor_maximum_num_jobs
      "EXECUTOR_FIRECRACKER_NUM_CPUS"       = var.executor_firecracker_num_cpus
      "EXECUTOR_FIRECRACKER_MEMORY"         = var.executor_firecracker_memory
      "EXECUTOR_FIRECRACKER_DISK_SPACE"     = var.executor_firecracker_disk_space
      "EXECUTOR_QUEUE_NAME"                 = var.executor_queue_name
      "EXECUTOR_MAXIMUM_RUNTIME_PER_JOB"    = var.executor_maximum_runtime_per_job
      "EXECUTOR_NUM_TOTAL_JOBS"             = var.executor_num_total_jobs
      "EXECUTOR_MAX_ACTIVE_TIME"            = var.executor_max_active_time
    }
  }))

  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "autoscaler" {
  name                      = "${local.prefix}executors"
  min_size                  = var.min_replicas
  max_size                  = var.max_replicas
  vpc_zone_identifier       = [var.subnet_id]
  health_check_grace_period = 300
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupPendingCapacity",
    "GroupMinSize",
    "GroupMaxSize",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupStandbyCapacity",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances"
  ]

  # Used for metrics scraping discovery.
  tag {
    key                 = "executor_tag"
    value               = var.executor_tag
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.executor.id
    version = "$Latest"
  }
}

# TODO(efritz) - replace with a sensible alarm
resource "aws_cloudwatch_metric_alarm" "alarm" {
  # Don't create this resource when autoscaling is disabled.
  count = local.autoscaling ? 1 : 0

  alarm_name          = "${local.prefix}executor_queue_scaling_trigger"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "src_executors_queue_size"
  namespace           = "sourcegraph-executor"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "-1"
  dimensions = {
    "environment" = var.metrics_environment_label
    "queueName"   = var.executor_queue_name
  }
  datapoints_to_alarm       = 1
  alarm_actions             = [aws_autoscaling_policy.always_on[0].arn]
  insufficient_data_actions = []
}

resource "aws_autoscaling_policy" "always_on" {
  # Don't create this resource when autoscaling is disabled.
  count = local.autoscaling ? 1 : 0

  name = "${local.prefix}executor_queue_scaling"

  # Generate step adjustments. This is a workaround for not needing a utilization metric for now.
  step_adjustment {
    scaling_adjustment          = var.min_replicas
    metric_interval_upper_bound = var.min_replicas + 1
  }
  dynamic "step_adjustment" {
    for_each = range(var.min_replicas, var.max_replicas - 1)
    content {
      scaling_adjustment          = step_adjustment.value + 1
      metric_interval_lower_bound = var.jobs_per_instance_scaling * step_adjustment.value + 1
      metric_interval_upper_bound = var.jobs_per_instance_scaling * (step_adjustment.value + 1) + 1
    }
  }
  step_adjustment {
    scaling_adjustment          = var.max_replicas
    metric_interval_lower_bound = var.jobs_per_instance_scaling * (var.max_replicas - 1) + 1
  }

  policy_type               = "StepScaling"
  adjustment_type           = "ExactCapacity"
  estimated_instance_warmup = 60
  metric_aggregation_type   = "Maximum"
  autoscaling_group_name    = aws_autoscaling_group.autoscaler.name
}
