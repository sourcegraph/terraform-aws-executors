locals {
  autoscaling        = var.min_replicas != var.max_replicas
  prefix             = var.resource_prefix != "" ? "${var.resource_prefix}_sourcegraph_" : "sourcegraph_"
  scaling_expression = "CEIL(queueSize / ${var.jobs_per_instance_scaling}) - instanceCount"
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

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.cloudwatch-assignment.name
  policy_arn = data.aws_iam_policy.cloudwatch.arn
}

# Allow access to running instances over SSH and on port 9999 to scrape metrics.
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
    from_port   = 9999
    protocol    = "TCP"
    to_port     = 9999
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
      volume_type = "gp3"
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
      "EXECUTOR_DOCKER_REGISTRY_MIRROR"     = var.docker_registry_mirror
      "SOURCEGRAPH_EXTERNAL_URL"            = var.sourcegraph_external_url
      "SOURCEGRAPH_EXECUTOR_PROXY_PASSWORD" = var.sourcegraph_executor_proxy_password
      "EXECUTOR_MAXIMUM_NUM_JOBS"           = var.maximum_num_jobs
      "EXECUTOR_FIRECRACKER_NUM_CPUS"       = var.firecracker_num_cpus
      "EXECUTOR_FIRECRACKER_MEMORY"         = var.firecracker_memory
      "EXECUTOR_FIRECRACKER_DISK_SPACE"     = var.firecracker_disk_space
      "EXECUTOR_QUEUE_NAME"                 = var.queue_name
      "EXECUTOR_MAXIMUM_RUNTIME_PER_JOB"    = var.maximum_runtime_per_job
      "EXECUTOR_NUM_TOTAL_JOBS"             = var.num_total_jobs
      "EXECUTOR_MAX_ACTIVE_TIME"            = var.max_active_time
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
    value               = var.instance_tag
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.executor.id
    version = "$Latest"
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  # Don't create this resource when autoscaling is disabled.
  count = local.autoscaling ? 1 : 0

  alarm_name                = "${local.prefix}executor_queue_scale_out_trigger"
  comparison_operator       = "GreaterThanThreshold"
  threshold                 = "0"
  evaluation_periods        = "1"
  alarm_description         = "Alarms when the executor instances are deployed with insufficient capacity."
  alarm_actions             = [aws_autoscaling_policy.scale_out[0].arn]
  datapoints_to_alarm       = 1
  insufficient_data_actions = []

  metric_query {
    id = "queueSize"

    metric {
      metric_name = "src_executors_queue_size"
      namespace   = "sourcegraph-executor"
      period      = "60"
      stat        = "Maximum"

      dimensions = {
        "environment" = var.metrics_environment_label
        "queueName"   = var.queue_name
      }
    }
  }

  metric_query {
    id = "instanceCount"

    metric {
      metric_name = "GroupTotalInstances"
      namespace   = "AWS/AutoScaling"
      period      = "60"
      stat        = "Maximum"

      dimensions = {
        "AutoScalingGroupName" = "${local.prefix}executors"
      }
    }
  }

  metric_query {
    id = "utilizationMetric"

    expression  = local.scaling_expression
    label       = "The target number of instances to add to efficiently process the queue at its current size."
    return_data = "true"
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  # Don't create this resource when autoscaling is disabled.
  count = local.autoscaling ? 1 : 0

  name                   = "${local.prefix}executor_queue_scale_out"
  autoscaling_group_name = aws_autoscaling_group.autoscaler.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
}

resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  # Don't create this resource when autoscaling is disabled.
  count = local.autoscaling ? 1 : 0

  alarm_name                = "${local.prefix}executor_queue_scale_in_trigger"
  comparison_operator       = "LessThanThreshold"
  threshold                 = "0"
  evaluation_periods        = "1"
  alarm_description         = "Alarms when the executor instances are deployed with excess capacity."
  alarm_actions             = [aws_autoscaling_policy.scale_in[0].arn]
  datapoints_to_alarm       = 1
  insufficient_data_actions = []

  metric_query {
    id = "queueSize"

    metric {
      metric_name = "src_executors_queue_size"
      namespace   = "sourcegraph-executor"
      period      = "60"
      stat        = "Maximum"

      dimensions = {
        "environment" = var.metrics_environment_label
        "queueName"   = var.queue_name
      }
    }
  }

  metric_query {
    id = "instanceCount"

    metric {
      metric_name = "GroupTotalInstances"
      namespace   = "AWS/AutoScaling"
      period      = "60"
      stat        = "Maximum"

      dimensions = {
        "AutoScalingGroupName" = "${local.prefix}executors"
      }
    }
  }

  metric_query {
    id = "utilizationMetric"

    expression  = local.scaling_expression
    label       = "The target number of instances that can be removed and continue to efficiently process the queue at its current size."
    return_data = "true"
  }
}

resource "aws_autoscaling_policy" "scale_in" {
  # Don't create this resource when autoscaling is disabled.
  count = local.autoscaling ? 1 : 0

  name                   = "${local.prefix}executor_queue_scale_in"
  autoscaling_group_name = aws_autoscaling_group.autoscaler.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
}
