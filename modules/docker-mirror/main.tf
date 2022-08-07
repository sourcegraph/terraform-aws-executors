# Create a log group in CloudWatch. This is where the docker mirror will ingest
# its logs to.
resource "aws_cloudwatch_log_group" "syslogs" {
  # TODO: This is hardcoded in the executor docker mirror image.
  name              = "executors_docker_mirror"
  retention_in_days = 7
}

data "aws_subnet" "main" {
  id = var.subnet_id
}

data "aws_ami" "latest_ami" {
  most_recent = true
  owners      = ["sourcegraph-ci"]

  filter {
    name   = "name"
    values = ["sourcegraph-executors-docker-mirror-3-42-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# The docker registry mirror EC2 instance.
resource "aws_instance" "default" {
  ami           = var.machine_ami != "" ? var.machine_ami : data.aws_ami.latest_ami.image_id
  instance_type = var.machine_type

  root_block_device {
    volume_size = var.boot_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    "executor_tag" = "${var.instance_tag_prefix}-docker-mirror"
    "Name"         = "sourcegraph-executors-docker-registry-mirror"
  }

  monitoring = true

  # We attach the static network device to the mirror instance.
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.static.id
  }

  iam_instance_profile = aws_iam_instance_profile.instance.name

  user_data_base64 = base64encode(file("${path.module}/startup-script.sh"))
}

# Reserve a fixed disk to retain docker mirror data across rollouts.
resource "aws_ebs_volume" "docker-storage" {
  availability_zone = data.aws_subnet.main.availability_zone
  size              = var.disk_size
  encrypted         = true
  type              = "gp3"
  iops              = var.disk_iops
  throughput        = var.disk_throughput
}

resource "aws_volume_attachment" "docker-storage" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.docker-storage.id
  instance_id = aws_instance.default.id
}

resource "aws_eip" "static" {
  count = var.assign_public_ip ? 1 : 0

  vpc                       = true
  associate_with_private_ip = var.static_ip
  network_interface         = aws_network_interface.static.id
}

# Always bind the static IP address to a network interface so it's never claimed
# by another instance.
resource "aws_network_interface" "static" {
  private_ips = [var.static_ip]
  # The subnet also defines the AZ of the instance, so no need to specify it again on the instance.
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.default.id]
}

resource "aws_security_group" "default" {
  name        = "SourcegraphExecutorsDockerMirrorAccess"
  description = "Security group used by Sourcegraph executors to define access to the docker registry mirror."
  vpc_id      = var.vpc_id

  ingress {
    cidr_blocks = [var.ssh_access_cidr_range]
    description = "Allow SSH access"
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
  }

  ingress {
    cidr_blocks = [var.http_access_cidr_range]
    description = "Allow access to Docker registry"
    from_port   = 5000
    protocol    = "TCP"
    to_port     = 5000
  }

  ingress {
    cidr_blocks = [var.http_access_cidr_range]
    description = "Allow access to Docker registry metrics via exporter_exporter"
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

resource "aws_iam_role" "ec2-role" {
  name = "sourcegraph_executors_docker_mirror"
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
  name = "sourcegraph_executors_docker_mirror"
  role = aws_iam_role.ec2-role.name
}

data "aws_iam_policy" "cloudwatch" {
  name = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = data.aws_iam_policy.cloudwatch.arn
}

data "aws_iam_policy" "ssm" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2-role.name
  policy_arn = data.aws_iam_policy.ssm.arn
}
