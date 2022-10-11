output "vpc_id" {
  value       = aws_vpc.default.id
  description = "The ID of the VPC that hosts the cache and the executors in."
}

output "subnet_id" {
  value       = var.nat == true ? aws_subnet.private.0.id : aws_subnet.default.id
  description = "The subnet to run the VM in."
}

output "ip_cidr" {
  value       = local.ip_cidr
  description = "The internal address that is owned by the subnetwork."
}

output "nat_ip" {
  value       = var.nat == true ? [aws_eip.nat.0.public_ip] : []
  description = "The list of NAT router address when executors should not get public IPs."
}
