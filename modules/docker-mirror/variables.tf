variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to run the instance in."
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet within the given VPC to run the instance in."
}

variable "machine_ami" {
  type        = string
  default     = ""
  description = "AMI for the EC2 instance to use. Must be in the same availability zone. Leave empty to use latest compatible with the Sourcegraph version."
}

variable "machine_type" {
  type        = string
  default     = "m5n.large" // 2 vCPU, 8GB
  description = "Docker registry mirror node machine type."
}

variable "boot_disk_size" {
  type        = number
  default     = 32
  description = "Docker registry mirror node disk size in GB."
}

variable "boot_disk_kms_key_id" {
  type        = string
  default     = null
  description = "[Optional] The KMS Key ID for EBS volume encryption."
}

variable "disk_size" {
  type        = number
  default     = 64
  description = "Persistent Docker registry mirror disk size in GB."
}

variable "disk_iops" {
  type        = number
  default     = 500
  description = "Persistent Docker registry mirror additional IOPS."
}

variable "disk_throughput" {
  type        = number
  default     = 125
  description = "Persistent Docker registry mirror disk throughput in MiB/s."
}

variable "disk_kms_key_id" {
  type        = string
  default     = null
  description = "[Optional] The KMS Key ID for mirror disk EBS volume encryption."
}

variable "static_ip" {
  type        = string
  description = "The IP to statically assign to the instance. Should be internal."
}

variable "ssh_access_cidr_range" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR range from where SSH access to the EC2 instance is acceptable."
}

variable "http_access_cidr_range" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR range from where HTTP access to the Docker registry is acceptable."
}

variable "http_metrics_access_cidr_range" {
  type        = string
  default     = "0.0.0.0/0"
  description = "DEPRECATED: This is not used anymore."
}

variable "instance_tag_prefix" {
  type        = string
  description = "A label tag to add to all the machines; can be used for filtering out the right instances in stackdriver monitoring and in Prometheus instance discovery."
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "If false, no public IP will be associated with the executors."
}
