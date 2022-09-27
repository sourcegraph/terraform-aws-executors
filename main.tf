module "aws-networking" {
  source = "./modules/networking"

  availability_zone = var.availability_zone
  nat               = var.private_networking
}

module "aws-docker-mirror" {
  source = "./modules/docker-mirror"

  vpc_id                 = module.aws-networking.vpc_id
  subnet_id              = module.aws-networking.subnet_id
  http_access_cidr_range = module.aws-networking.ip_cidr
  machine_ami            = var.docker_mirror_machine_ami
  machine_type           = var.docker_mirror_machine_type
  boot_disk_size         = var.docker_mirror_boot_disk_size
  boot_disk_kms_key_id   = var.docker_mirror_boot_disk_kms_key_id
  disk_kms_key_id        = var.docker_mirror_disk_kms_key_id
  static_ip              = var.docker_mirror_static_ip
  ssh_access_cidr_range  = var.docker_mirror_ssh_access_cidr_range
  instance_tag_prefix    = var.executor_instance_tag
  assign_public_ip       = var.private_networking ? false : true
}

module "aws-executor" {
  source = "./modules/executors"

  vpc_id                                   = module.aws-networking.vpc_id
  subnet_id                                = module.aws-networking.subnet_id
  resource_prefix                          = var.executor_resource_prefix
  machine_image                            = var.executor_machine_image
  machine_type                             = var.executor_machine_type
  boot_disk_size                           = var.executor_boot_disk_size
  boot_disk_kms_key_id                     = var.executor_boot_disk_kms_key_id
  preemptible_machines                     = var.executor_preemptible_machines
  instance_tag                             = var.executor_instance_tag
  ssh_access_cidr_range                    = var.executor_ssh_access_cidr_range
  sourcegraph_external_url                 = var.executor_sourcegraph_external_url
  sourcegraph_executor_proxy_password      = var.executor_sourcegraph_executor_proxy_password
  queue_name                               = var.executor_queue_name
  use_firecracker                          = var.executor_use_firecracker
  maximum_runtime_per_job                  = var.executor_maximum_runtime_per_job
  maximum_num_jobs                         = var.executor_maximum_num_jobs
  num_total_jobs                           = var.executor_num_total_jobs
  max_active_time                          = var.executor_max_active_time
  job_num_cpus                             = var.executor_job_num_cpus != "" ? var.executor_job_num_cpus : var.executor_firecracker_num_cpus
  job_memory                               = var.executor_job_memory != "" ? var.executor_job_memory : var.executor_firecracker_memory
  firecracker_disk_space                   = var.executor_firecracker_disk_space
  min_replicas                             = var.executor_min_replicas
  max_replicas                             = var.executor_max_replicas
  jobs_per_instance_scaling                = var.executor_jobs_per_instance_scaling
  metrics_environment_label                = var.executor_metrics_environment_label
  docker_registry_mirror                   = "http://${var.docker_mirror_static_ip}:5000"
  docker_registry_mirror_node_exporter_url = "http://${var.docker_mirror_static_ip}:9999"
  assign_public_ip                         = var.private_networking ? false : true
}
