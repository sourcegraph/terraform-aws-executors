locals {
  availability_zone       = "us-west-2a"
  docker_mirror_static_ip = "10.0.1.4"
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

module "aws-networking" {
  source            = "./modules/networking"
  availability_zone = local.availability_zone
}

module "aws-docker-mirror" {
  source = "./modules/docker-mirror"

  availability_zone = local.availability_zone
  vpc_id            = module.aws-networking.vpc_id
  subnet_id         = module.aws-networking.subnet_id
  machine_ami       = data.aws_ami.ubuntu.id
  static_ip         = local.docker_mirror_static_ip
}

module "aws-executor" {
  source = "./modules/executors"

  vpc_id    = module.aws-networking.vpc_id
  subnet_id = module.aws-networking.subnet_id
}
