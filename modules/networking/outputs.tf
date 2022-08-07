output "vpc_id" {
  value = aws_vpc.default.id
}

output "subnet_id" {
  value = var.nat == true ? aws_subnet.private.0.id : aws_subnet.default.id
}

output "ip_cidr" {
  value = local.ip_cidr
}

output "nat_ip" {
  value = var.nat == true ? [aws_eip.nat.0.public_ip] : []
}
