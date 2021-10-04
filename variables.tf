variable "region" {
  type = string
}

variable "availability_zone" {
  type        = string
  description = "The availability zone to create the instance in."
}

variable "docker_mirror_machine_ami" {
  type        = string
  default     = ""
  description = "AMI for the EC2 instance to use. Must be in the same availability zone."
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
  description = "CIDR range from where HTTP access to the Docker registry is acceptable."
}

variable "executor_resource_prefix" {
  type        = string
  default     = ""
  description = "An optional prefix to add to all resources created."
}

variable "executor_machine_image" {
  type        = string
  default     = "ami-0fcc3956b8e1bdcde"
  description = "Executor node machine disk image to use for creating the boot volume."
}

variable "executor_machine_type" {
  type        = string
  default     = "c5n.metal" // 4 vCPU, 15GB
  description = "Executor node machine type."
}

variable "executor_boot_disk_size" {
  type        = number
  default     = 100 // 100GB
  description = "Executor node disk size in GB"
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
  description = "CIDR range from where HTTP access to the metrics endpoint is acceptable."
}

variable "executor_sourcegraph_external_url" {
  type        = string
  description = "The externally accessible URL of the target Sourcegraph instance."
}

variable "executor_sourcegraph_executor_proxy_username" {
  type        = string
  description = "The shared username used to authenticate requests to the internal executor proxy."
}

variable "executor_sourcegraph_executor_proxy_password" {
  type        = string
  description = "The shared password used to authenticate requests to the internal executor proxy."
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

variable "executor_firecracker_memory" {
  type        = string
  default     = "12GB"
  description = "The amount of memory to give to each firecracker VM"
}

variable "executor_firecracker_disk_space" {
  type        = string
  default     = "20GB"
  description = "The amount of disk space to give to each firecracker VM"
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

variable "executor_docker_registry_mirror" {
  type        = string
  default     = ""
  description = "A URL to a docker registry mirror to use (falling back to docker.io)."
}
