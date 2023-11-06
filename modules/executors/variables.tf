variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to run the instance in."
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet within the given VPC to run the instance in."
}

variable "resource_prefix" {
  type        = string
  default     = ""
  description = "An optional prefix to add to all resources created."
}

variable "machine_image" {
  type        = string
  default     = ""
  description = "Executor node machine disk image to use for creating the boot volume. Leave empty to use latest compatible with the Sourcegraph version."
}

variable "machine_type" {
  type        = string
  default     = "c5n.metal" // 72 vCPU, 192GB
  description = "Executor node machine type."
}

variable "ami_version" {
  type        = string
  default     = ""
  description = "Specify a Sourcegraph executor ami version to use rather than pulling latest"

  validation {
    condition     = can(regex("^v?(\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-.]+)?(\\+[0-9A-Za-z-.]+)?)?$", var.ami_version))
    error_message = "The Soucegraph ami version must be valid semver"
  }
}

variable "boot_disk_size" {
  type        = number
  default     = 500
  description = "Executor node disk size in GB."
}

variable "boot_disk_iops" {
  type        = number
  default     = 3000
  description = "Executor node disk additional IOPS."
}

variable "boot_disk_throughput" {
  type        = number
  default     = 125
  description = "Executor node disk throughput in MiB/s."
}

variable "preemptible_machines" {
  type        = bool
  default     = false
  description = "Whether to use preemptible machines instead of standard machines; usually way cheaper but might be terminated at any time"
}

variable "instance_tag" {
  type        = string
  description = "A label tag to add to all the executors. Can be used for filtering out the right instances in stackdriver monitoring."
}

variable "ssh_access_cidr_range" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR range from where SSH access to the EC2 instances is acceptable."
}

variable "http_access_cidr_range" {
  type        = string
  default     = "0.0.0.0/0"
  description = "DEPRECATED. This is not used anymore."
}

variable "sourcegraph_external_url" {
  type        = string
  description = "The externally accessible URL of the target Sourcegraph instance."
}

variable "sourcegraph_executor_proxy_password" {
  type        = string
  description = "The shared password used to authenticate requests to the internal executor proxy."
  sensitive   = true
}

variable "queue_name" {
  type        = string
  default     = ""
  description = "The single queue from which the executor should dequeue jobs. Either this or `queue_names` is required"
}

variable "queue_names" {
  type        = list(string)
  default     = null
  description = "The multiple queues from which the executor should dequeue jobs. Either this or `queue_name` is required"
}

variable "maximum_runtime_per_job" {
  type        = string
  default     = "30m"
  description = "The maximum wall time that can be spent on a single job"
}

variable "maximum_num_jobs" {
  type        = number
  default     = 18
  description = "The number of jobs to run concurrently per executor instance"
}

variable "num_total_jobs" {
  type        = number
  default     = 1800
  description = "The maximum number of jobs that will be dequeued by the worker"
}

variable "max_active_time" {
  type        = string
  default     = "2h"
  description = "The maximum time that can be spent by the worker dequeueing records to be handled"
}

variable "firecracker_num_cpus" {
  type        = number
  default     = 4
  description = "The number of CPUs to give to each firecracker VM"
}

variable "job_num_cpus" {
  type        = number
  default     = 4
  description = "The number of CPUs to allocate to each virtual machine or container"
}

variable "firecracker_memory" {
  type        = string
  default     = "12GB"
  description = "The amount of memory to give to each firecracker VM"
}

variable "job_memory" {
  type        = string
  default     = "12GB"
  description = "The amount of memory to allocate to each virtual machine or container"
}

variable "firecracker_disk_space" {
  type        = string
  default     = "20GB"
  description = "The amount of disk space to give to each firecracker VM"
}

variable "use_firecracker" {
  type        = bool
  default     = true
  description = "Whether to isolate commands in virtual machines"
}

variable "min_replicas" {
  type        = number
  default     = 1
  description = "The minimum number of executor instances to run in the autoscaling group."
}

variable "max_replicas" {
  type        = number
  default     = 1
  description = "The maximum number of executor instances to run in the autoscaling group."
}

variable "jobs_per_instance_scaling" {
  type        = number
  default     = 360
  description = "The amount of jobs a single instance should have in queue. Used for autoscaling."
}

variable "metrics_environment_label" {
  type        = string
  description = "The value for environment by which to filter the custom metrics."
}

variable "docker_registry_mirror" {
  type        = string
  default     = ""
  description = "A URL to a docker registry mirror to use (falling back to docker.io)."
}

variable "docker_registry_mirror_node_exporter_url" {
  type        = string
  default     = ""
  description = "A URL to a docker registry mirror node exporter to scrape (optional)"
}

variable "assign_public_ip" {
  type        = bool
  default     = true
  description = "If false, no public IP will be associated with the executors."
}

variable "metrics_access_security_group_id" {
  type        = string
  default     = ""
  description = "If provided, the default security groups will not be created. The ID of the security group to associate the Launch Template network with."
}

variable "docker_auth_config" {
  type        = string
  default     = ""
  description = "If provided, this docker auth config file will be used to authorize image pulls. See [Using private registries](https://docs.sourcegraph.com/admin/deploy_executors#using-private-registries) for how to configure."
  sensitive   = true
}

variable "randomize_resource_names" {
  type        = bool
  description = "Use randomized names for resources. Deployments using the legacy naming convention will be updated in-place with randomized names when enabled."
}

variable "permissions_boundary_arn" {
  type        = string
  default     = ""
  description = "If not provided, there will be no permissions boundary on IAM roles and users created. The ARN of a policy to use for permissions boundaries with IAM roles and users."
}
