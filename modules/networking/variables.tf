variable "availability_zone" {
  type        = string
  description = "The availability zone to create the network in."
}

variable "nat" {
  type        = bool
  default     = false
  description = "When true, the network will contain a NAT router. Use when executors should not get public IPs."
}

variable "resource_prefix" {
  type        = string
  default     = ""
  description = "An optional prefix to add to all resources created."
}

variable "randomize_resource_names" {
  type        = bool
  description = "TODO"
}
