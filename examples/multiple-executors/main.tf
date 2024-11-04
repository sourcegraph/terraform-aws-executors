locals {
  region                  = "us-west-2"
  availability_zone       = "us-west-2a"
  docker_mirror_static_ip = "10.0.1.4"
}

module "networking" {
  source  = "sourcegraph/executors/aws//modules/networking"
  version = "5.9.0" # LATEST

  availability_zone        = local.availability_zone
  randomize_resource_names = true
}

module "docker-mirror" {
  source  = "sourcegraph/executors/aws//modules/docker-mirror"
  version = "5.9.0" # LATEST

  vpc_id                   = module.networking.vpc_id
  subnet_id                = module.networking.subnet_id
  static_ip                = local.docker_mirror_static_ip
  instance_tag_prefix      = "prod"
  randomize_resource_names = true
}

module "executors-codeintel" {
  source  = "sourcegraph/executors/aws//modules/executors"
  version = "5.9.0" # LATEST

  vpc_id                              = module.networking.vpc_id
  subnet_id                           = module.networking.subnet_id
  resource_prefix                     = "codeintel-prod"
  instance_tag                        = "codeintel-prod"
  sourcegraph_external_url            = "https://sourcegraph.acme.com"
  sourcegraph_executor_proxy_password = "hunter2"
  queue_name                          = "codeintel"
  metrics_environment_label           = "prod"
  docker_registry_mirror              = "http://${local.docker_mirror_static_ip}:5000"
  #   docker_registry_mirror_node_exporter_url = "http://${local.docker_mirror_static_ip}:9999"
  use_firecracker          = true
  randomize_resource_names = true
}

module "executors-batches" {
  source  = "sourcegraph/executors/aws//modules/executors"
  version = "5.9.0" # LATEST

  vpc_id                              = module.networking.vpc_id
  subnet_id                           = module.networking.subnet_id
  resource_prefix                     = "batches-prod"
  instance_tag                        = "batches-prod"
  sourcegraph_external_url            = "https://sourcegraph.acme.com"
  sourcegraph_executor_proxy_password = "hunter2"
  queue_name                          = "batches"
  metrics_environment_label           = "prod"
  docker_registry_mirror              = "http://${local.docker_mirror_static_ip}:5000"
  #   docker_registry_mirror_node_exporter_url = "http://${local.docker_mirror_static_ip}:9999"
  use_firecracker          = true
  randomize_resource_names = true
}
