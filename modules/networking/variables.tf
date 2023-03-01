variable "availability_zone" {
  type        = string
  description = "The availability zone to create the network in."
}

variable "nat" {
  type        = bool
  default     = false
  description = "When true, the network will contain a NAT router. Use when executors should not get public IPs."
}

variable "create_vpc" {
  type        = bool
  default     = true
  description = "When true, a dedicated VPC will be created for deploying all executors resources into"
}

variable "vpc_id" {
  type        = string
  description = "AWS identifier of existing VPC to deploy into when create_vpc is set to false"
}
