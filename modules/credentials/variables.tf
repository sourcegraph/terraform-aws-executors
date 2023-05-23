variable "resource_prefix" {
  type        = string
  default     = ""
  description = "An optional prefix to add to all resources created."
}

variable "permissions_boundary_arn" {
  type        = string
  default     = ""
  description = "If not provided, there will be no permissions boundary on IAM roles and users created. The ARN of a policy to use for permissions boundaries with IAM roles and users."
}
