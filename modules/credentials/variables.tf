variable "resource_prefix" {
  type        = string
  default     = ""
  description = "An optional prefix to add to all resources created."
}

variable "permissions_boundary_arn" {
  type        = string
  default     = ""
  description = "ARN for permissions boundaries on IAM users and roles created by this module"
}
