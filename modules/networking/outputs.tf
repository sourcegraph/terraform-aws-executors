output "vpc_id" {
  value = aws_vpc.default.id
}

output "subnet_id" {
  value = aws_subnet.default.id
}

output "ip_cidr" {
  value = local.ip_cidr
}
