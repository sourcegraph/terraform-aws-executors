locals {
  ip_cidr = "10.0.1.0/24"
}

# Create a VPC to host the cache and the executors in.
# We will have a subnet in there, that has an all-destination route to an egress-only
# internet gateway. That way, we protect from incoming traffic.
resource "aws_vpc" "default" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
}

resource "aws_subnet" "default" {
  vpc_id            = aws_vpc.default.id
  cidr_block        = local.ip_cidr
  availability_zone = var.availability_zone
}

resource "aws_internet_gateway" "default" {
  # TODO: Make this an egress-only internet gateway. This will break our current metrics
  # collection, though.
  vpc_id = aws_vpc.default.id
}

# Allow all instances in the VPC to reach the internet gateway.
resource "aws_route" "egress" {
  route_table_id         = aws_vpc.default.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}
