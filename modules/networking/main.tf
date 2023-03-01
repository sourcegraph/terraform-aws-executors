locals {
  public_ip_cidr = "10.0.0.0/24"
  ip_cidr        = "10.0.1.0/24"

  resource_prefix = (var.resource_prefix == "" || substr(var.resource_prefix, -1, -2) == "-") ? var.resource_prefix : "${var.resource_prefix}-"

  vpc = {
    name = var.randomize_resource_names ? "${local.resource_prefix}executors-${random_id.vpc[0].hex}" : null
  }
  subnet = {
    public = {
      name = var.randomize_resource_names ? "${local.resource_prefix}executors-public-${random_id.subnet_public[0].hex}" : null
    }
    private = {
      name = var.randomize_resource_names ? "${local.resource_prefix}executors-private-${random_id.subnet_private[0].hex}" : null
    }
  }
  route_table = {
    public = {
      name = var.randomize_resource_names ? "${local.resource_prefix}executors-public-${random_id.route_table_public[0].hex}" : null
    }
    private = {
      name = var.randomize_resource_names ? "${local.resource_prefix}executors-public-${random_id.route_table_private[0].hex}" : null
    }
  }
  internet_gateway = {
    name = var.randomize_resource_names ? "${local.resource_prefix}executors-public-${random_id.internet_gateway[0].hex}" : null
  }
  eip = {
    name = var.randomize_resource_names ? "${local.resource_prefix}executors-${random_id.eip[0].hex}" : null
  }
  nat_gateway = {
    name = var.randomize_resource_names ? "${local.resource_prefix}executors-${random_id.eip[0].hex}" : null
  }
}

resource "random_id" "vpc" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

# Create a VPC to host the cache and the executors in.
resource "aws_vpc" "default" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = local.vpc.name
  }
}

resource "random_id" "subnet_public" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

# TODO: Rename later to "public". We don't do this now, so the docker mirror disks
# don't get deleted.
resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = var.nat == true ? local.public_ip_cidr : local.ip_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = local.subnet.public.name
  }
}

resource "random_id" "route_table_public" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = local.route_table.public.name
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.default.id
  route_table_id = aws_route_table.public.id
}

resource "random_id" "subnet_private" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

resource "aws_subnet" "private" {
  # Only create this resource when NAT is enabled.
  count = var.nat == true ? 1 : 0

  vpc_id                  = aws_vpc.default.id
  cidr_block              = local.ip_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
}

resource "random_id" "route_table_private" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

resource "aws_route_table" "private" {
  # Only create this resource when NAT is enabled.
  count = var.nat == true ? 1 : 0

  vpc_id = aws_vpc.default.id

  tags = {
    Name = local.route_table.private.name
  }
}

resource "aws_route_table_association" "private" {
  # Only create this resource when NAT is enabled.
  count = var.nat == true ? 1 : 0

  subnet_id      = aws_subnet.private.0.id
  route_table_id = aws_route_table.private.0.id
}

resource "random_id" "internet_gateway" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = local.internet_gateway.name
  }
}

# Allow all instances in the public VPC to reach the internet gateway.
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_route" "private" {
  # Only create this resource when NAT is enabled.
  count = var.nat == true ? 1 : 0

  route_table_id         = aws_route_table.private.0.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.default.0.id
}

resource "random_id" "eip" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

# If NAT mode is enabled, we want a static IP for it.
resource "aws_eip" "nat" {
  # Only create this resource when NAT is enabled.
  count = var.nat ? 1 : 0

  vpc        = true
  depends_on = [aws_internet_gateway.default]

  tags = {
    Name = local.eip.name
  }
}

resource "random_id" "nat_gateway" {
  count       = var.randomize_resource_names ? 1 : 0
  byte_length = 6
}

resource "aws_nat_gateway" "default" {
  # Only create this resource when NAT is enabled.
  count = var.nat ? 1 : 0

  allocation_id = aws_eip.nat.0.id
  subnet_id     = aws_subnet.default.id
  depends_on    = [aws_internet_gateway.default]

  tags = {
    Name = local.nat_gateway.name
  }
}
