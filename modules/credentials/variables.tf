variable "availability_zone" {
  type        = string
  description = "The availability zone to create the instance in."
}

variable "resource_prefix" {
  type        = string
  default     = ""
  description = "An optional prefix to add to all resources created."
}
