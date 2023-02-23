variable "availability_zone" {
  type        = string
  description = "The availability zone to create the instance in."
}

variable "docker_mirror_machine_ami" {
  type        = string
  default     = ""
  description = "AMI for the EC2 instance to use. Must be in the same availability zone. Leave empty to use latest compatible with the Sourcegraph version."
}

variable "docker_mirror_machine_type" {
  type        = string
  default     = "m5.large" // 2 vCPU, 8GB
  description = "Docker registry mirror node machine type."
}

variable "docker_mirror_boot_disk_size" {
  type        = number
  default     = 64
  description = "Docker registry mirror node disk size in GB."
}

variable "docker_mirror_disk_iops" {
  type        = number
  default     = 3000
  description = "Persistent Docker registry mirror additional IOPS."
}

variable "docker_mirror_static_ip" {
  type        = string
  default     = "10.0.1.4"
  description = "The IP to statically assign to the instance. Should be internal."
}

variable "docker_mirror_ssh_access_cidr_range" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR range from where SSH access to the EC2 instance is acceptable."
}

variable "docker_mirror_http_access_cidr_range" {
  type        = string
  default     = "10.0.0.0/16"
  description = "DEPRECATED. This is not used anymore."
}

variable "executor_resource_prefix" {
  type        = string
  default     = ""
  description = "An optional prefix to add to all resources created."
}

variable "executor_machine_image" {
  type        = string
  default     = ""
  description = "Executor node machine disk image to use for creating the boot volume. Leave empty to use latest compatible with the Sourcegraph version."
}

variable "executor_machine_type" {
  type        = string
  default     = "c5n.metal" // 72 vCPU, 192GB
  description = "Executor node machine type."
}

variable "executor_boot_disk_size" {
  type        = number
  default     = 100 // 100GB
  description = "Executor node disk size in GB"
}

variable "executor_boot_disk_iops" {
  type        = number
  default     = 3000
  description = "Executor node disk additional IOPS."
}

variable "executor_preemptible_machines" {
  type        = bool
  default     = false
  description = "Whether to use preemptible machines instead of standard machines; usually way cheaper but might be terminated at any time"
}
variable "executor_instance_tag" {
  type        = string
  description = "A label tag to add to all the executors. Can be used for filtering out the right instances in stackdriver monitoring."
}

variable "executor_ssh_access_cidr_range" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR range from where SSH access to the EC2 instances is acceptable."
}

variable "executor_http_access_cidr_range" {
  type        = string
  default     = "0.0.0.0/0"
  description = "DEPRECATED. This is not used anymore."
}

variable "executor_sourcegraph_external_url" {
  type        = string
  description = "The externally accessible URL of the target Sourcegraph instance."
}

variable "executor_sourcegraph_executor_proxy_password" {
  type        = string
  description = "The shared password used to authenticate requests to the internal executor proxy."
  sensitive   = true
}

variable "executor_queue_name" {
  type        = string
  description = "The queue from which the executor should dequeue jobs."
}

variable "executor_maximum_runtime_per_job" {
  type        = string
  default     = "30m"
  description = "The maximum wall time that can be spent on a single job"
}

variable "executor_maximum_num_jobs" {
  type        = number
  default     = 18
  description = "The number of jobs to run concurrently per executor instance"
}

variable "executor_num_total_jobs" {
  type        = number
  default     = 1800
  description = "The maximum number of jobs that will be dequeued by the worker"
}

variable "executor_max_active_time" {
  type        = string
  default     = "2h"
  description = "The maximum time that can be spent by the worker dequeueing records to be handled"
}

variable "executor_firecracker_num_cpus" {
  type        = number
  default     = 4
  description = "The number of CPUs to give to each firecracker VM"
}

variable "executor_job_num_cpus" {
  type        = number
  default     = 4
  description = "The number of CPUs to allocate to each virtual machine or container"
}

variable "executor_firecracker_memory" {
  type        = string
  default     = "12GB"
  description = "The amount of memory to give to each firecracker VM"
}

variable "executor_job_memory" {
  type        = string
  default     = "12GB"
  description = "The amount of memory to allocate to each virtual machine or container"
}

variable "executor_firecracker_disk_space" {
  type        = string
  default     = "20GB"
  description = "The amount of disk space to give to each firecracker VM"
}

variable "executor_use_firecracker" {
  type        = bool
  default     = true
  description = "Whether to isolate commands in virtual machines"
}

variable "executor_min_replicas" {
  type        = number
  default     = 1
  description = "The minimum number of executor instances to run in the autoscaling group."
}

variable "executor_max_replicas" {
  type        = number
  default     = 1
  description = "The maximum number of executor instances to run in the autoscaling group."
}

variable "executor_jobs_per_instance_scaling" {
  type        = number
  default     = 360
  description = "The amount of jobs a single instance should have in queue. Used for autoscaling."
}

variable "executor_metrics_environment_label" {
  type        = string
  description = "The value for environment by which to filter the custom metrics."
}

variable "private_networking" {
  type        = bool
  default     = false
  description = "If true, the executors and docker mirror will live in a private subnet and communicate with the internet through NAT."
}

variable "security_group_id" {
  type        = string
  default     = ""
  description = "If provided, the default security groups will not be created. The ID of the security group to associate the Docker Mirror network and the Launch Template network with."
}

variable "executor_docker_auth_config" {
  type        = string
  default     = ""
  description = "If provided, this docker auth config file will be used to authorize image pulls. See [Using private registries](https://docs.sourcegraph.com/admin/deploy_executors#using-private-registries) for how to configure."
  sensitive   = true
}
