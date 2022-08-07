locals {
  public_ip_cidr = "10.0.0.0/24"
  ip_cidr        = "10.0.1.0/24"
}

# Create a VPC to host the cache and the executors in.
resource "aws_vpc" "default" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
}

# TODO: Rename later to "public". We don't do this now, so the docker mirror disks
# don't get deleted.
resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = var.nat == true ? local.public_ip_cidr : local.ip_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.default.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  # Only create this resource when NAT is enabled.
  count = var.nat == true ? 1 : 0

  vpc_id                  = aws_vpc.default.id
  cidr_block              = local.ip_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false
}

resource "aws_route_table" "private" {
  # Only create this resource when NAT is enabled.
  count = var.nat == true ? 1 : 0

  vpc_id = aws_vpc.default.id
}

resource "aws_route_table_association" "private" {
  # Only create this resource when NAT is enabled.
  count = var.nat == true ? 1 : 0

  subnet_id      = aws_subnet.private.0.id
  route_table_id = aws_route_table.private.0.id
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
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

# If NAT mode is enabled, we want a static IP for it.
resource "aws_eip" "nat" {
  # Only create this resource when NAT is enabled.
  count = var.nat ? 1 : 0

  vpc        = true
  depends_on = [aws_internet_gateway.default]
}

resource "aws_nat_gateway" "default" {
  # Only create this resource when NAT is enabled.
  count = var.nat ? 1 : 0

  allocation_id = aws_eip.nat.0.id
  subnet_id     = aws_subnet.default.id
  depends_on    = [aws_internet_gateway.default]
}
