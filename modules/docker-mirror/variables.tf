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
  default     = "ami-04010bfdd784ec00e"
  description = "AMI for the EC2 instance to use. Must be in the same availability zone."
}

variable "machine_type" {
  type        = string
  default     = "m5.large" // 2 vCPU, 8GB
  description = "Docker registry mirror node machine type."
}

variable "boot_disk_size" {
  type        = number
  default     = 64
  description = "Docker registry mirror node disk size in GB."
}

variable "static_ip" {
  type        = string
  description = "The IP to statically assign to the instance. Should be internal."
}

variable "ssh_access_cidr_range" {
  type        = string
  default     = "0.0.0.0/0"
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
  description = "CIDR range from where HTTP access to scrape metrics from the Docker registry is acceptable."
}

variable "instance_tag_prefix" {
  type        = string
  description = "A label tag to add to all the machines; can be used for filtering out the right instances in stackdriver monitoring and in Prometheus instance discovery."
}
