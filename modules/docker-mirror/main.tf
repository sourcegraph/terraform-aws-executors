# Create a log group in CloudWatch. This is where the docker mirror will ingest
# its logs to.
resource "aws_cloudwatch_log_group" "syslogs" {
  name              = "sourcegraph_executors_docker_mirror"
  retention_in_days = 7
}

# Datasource to fetch the latest AMI of Ubuntu 20.04 for use in the docker mirror.
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  # Canonical
  owners = ["099720109477"]
}

# The docker registry mirror EC2 instance.
resource "aws_instance" "default" {
  ami           = coalesce(var.machine_ami, data.aws_ami.ubuntu.id)
  instance_type = var.machine_type

  root_block_device {
    volume_size = var.boot_disk_size
    volume_type = "gp2"
  }

  monitoring = true

  # We attach the static network device to the mirror instance.
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.static.id
  }

  iam_instance_profile = aws_iam_instance_profile.instance.name

  user_data = file("${path.module}/startup-script.sh")
}

resource "aws_eip" "static" {
  # TODO - make this unreachable from public internet (but without this there is no egress).
  # Therefor, we need to have two subnets, and a NAT gateway. Not sure if it's worth the
  # additional cost.
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

  # Allow all outgoing network traffic.
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_iam_role" "cloudwatch-assignment" {
  name = "sourcegraph_executors_docker_mirror_cloudwatch"
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
  name = "sourcegraph_executors_docker_mirror_cloudwatch"
  role = aws_iam_role.cloudwatch-assignment.name
}

data "aws_iam_policy" "cloudwatch" {
  name = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy_attachment" "cloudwatch" {
  policy_arn = data.aws_iam_policy.cloudwatch.arn
  # TODO: this keeps overwriting each other.
  roles = [aws_iam_role.cloudwatch-assignment.name, "codeintel_cloud_sourcegraph_executors_cloudwatch"]
  name  = "SourcegraphExecutorsDockerMirrorCloudWatch"
}
