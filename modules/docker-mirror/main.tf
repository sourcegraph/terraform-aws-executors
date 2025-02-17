locals {
  resource_prefix = (var.resource_prefix == "" || substr(var.resource_prefix, -1, -2) == "-") ? var.resource_prefix : "${var.resource_prefix}-"

  cloudwatch_log_group = {
    name = var.randomize_resource_names ? "${local.resource_prefix}sourcegraph-executors-docker-registry-mirror-${random_id.cloudwatch_log_group[0].hex}" : null
  }
  instance = {
    name = var.randomize_resource_names ? "${local.resource_prefix}sourcegraph-executors-docker-registry-mirror-${random_id.instance[0].hex}" : "sourcegraph-executors-docker-registry-mirror"
  }
  eip = {
    name = var.randomize_resource_names ? "${local.resource_prefix}sourcegraph-executors-docker-registry-mirror-${random_id.eip[0].hex}" : null
  }
  network_interface = {
    name = var.randomize_resource_names ? "${local.resource_prefix}sourcegraph-executors-docker-registry-mirror-${random_id.network_interface[0].hex}" : null
  }
  security_group = {
    name = var.randomize_resource_names ? "${local.resource_prefix}SourcegraphExecutorsDockerMirrorAccess-${random_id.security_group[0].hex}" : "SourcegraphExecutorsDockerMirrorAccess"
  }

  specified_version = join("-", split(".", replace(var.ami_version, "v", "")))
}

resource "random_id" "cloudwatch_log_group" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

# Create a log group in CloudWatch. This is where the docker mirror will ingest
# its logs to.
resource "aws_cloudwatch_log_group" "syslogs" {
  # TODO: This is hardcoded in the executor docker mirror image.
  name              = "executors_docker_mirror"
  retention_in_days = 7

  tags = {
    Name = local.cloudwatch_log_group.name
  }
}

data "aws_subnet" "main" {
  id = var.subnet_id
}

data "aws_ami" "latest_ami" {
  count       = var.machine_ami != "" ? 0 : 1
  most_recent = true
  owners      = ["185007729374"]

  filter {
    name   = "name"
    values = ["sourcegraph-executors-docker-mirror-6-1-*"]
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

data "aws_ami" "ami" {
  count       = var.ami_version == "" ? 0 : 1
  most_recent = true
  owners      = ["185007729374"]

  filter {
    name   = "name"
    values = ["sourcegraph-executors-docker-mirror-${local.specified_version}"]
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

resource "random_id" "instance" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

# The docker registry mirror EC2 instance.
resource "aws_instance" "default" {
  # Order of precedence: machine_ami > sourcegraph_version > latest_ami
  ami           = var.machine_ami != "" ? var.machine_ami : var.ami_version != "" ? data.aws_ami.ami.0.image_id : data.aws_ami.latest_ami.0.image_id
  instance_type = var.machine_type

  root_block_device {
    volume_size = var.boot_disk_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    "executor_tag" = "${var.instance_tag_prefix}-docker-mirror"
    "Name"         = local.instance.name
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

resource "random_id" "eip" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

resource "aws_eip" "static" {
  count = var.assign_public_ip ? 1 : 0

  vpc                       = true
  associate_with_private_ip = var.static_ip
  network_interface         = aws_network_interface.static.id

  tags = {
    Name = local.eip.name
  }
}

resource "random_id" "network_interface" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

# Always bind the static IP address to a network interface so it's never claimed
# by another instance.
resource "aws_network_interface" "static" {
  private_ips = [var.static_ip]
  # The subnet also defines the AZ of the instance, so no need to specify it again on the instance.
  subnet_id       = var.subnet_id
  security_groups = [var.docker_mirror_access_security_group_id != "" ? var.docker_mirror_access_security_group_id : aws_security_group.default[0].id]

  tags = {
    Name = local.network_interface.name
  }
}

resource "random_id" "security_group" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

resource "aws_security_group" "default" {
  name        = local.security_group.name
  description = "Security group used by Sourcegraph executors to define access to the docker registry mirror."
  vpc_id      = var.vpc_id
  # If a security group has already been provided, no need to create this security group
  count = var.docker_mirror_access_security_group_id == "" ? 1 : 0

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

  tags = {
    Name = local.security_group.name
  }
}

resource "aws_iam_role" "ec2-role" {
  name = "sourcegraph_executors_docker_mirror"
  path = "/"

  permissions_boundary = var.permissions_boundary_arn != "" ? var.permissions_boundary_arn : ""

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
