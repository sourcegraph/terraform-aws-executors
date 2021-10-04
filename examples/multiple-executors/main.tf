module "networking" {
  source  = "sourcegraph/executors/aws//modules/networking"
  version = "0.0.6"

  availability_zone = local.availability_zone
}

module "docker-mirror" {
  source  = "sourcegraph/executors/aws//modules/docker-mirror"
  version = "0.0.6"

  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.subnet_id
  static_ip = local.docker_mirror_static_ip
}

module "executors-codeintel" {
  source  = "sourcegraph/executors/aws//modules/executors"
  version = "0.0.6"

  vpc_id                              = module.networking.vpc_id
  subnet_id                           = module.networking.subnet_id
  resource_prefix                     = "codeintel-prod"
  instance_tag                        = "codeintel-prod"
  sourcegraph_external_url            = "https://sourcegraph.acme.com"
  sourcegraph_executor_proxy_username = "executor"
  sourcegraph_executor_proxy_password = "hunter2"
  queue_name                          = "codeintel"
  metrics_environment_label           = "prod"
  docker_registry_mirror              = "http://${local.docker_mirror_static_ip}:5000"
}

module "executors-batches" {
  source  = "sourcegraph/executors/aws//modules/executors"
  version = "0.0.6"

  vpc_id                              = module.networking.vpc_id
  subnet_id                           = module.networking.subnet_id
  resource_prefix                     = "batches-prod"
  instance_tag                        = "batches-prod"
  sourcegraph_external_url            = "https://sourcegraph.acme.com"
  sourcegraph_executor_proxy_username = "executor"
  sourcegraph_executor_proxy_password = "hunter2"
  queue_name                          = "batches"
  metrics_environment_label           = "prod"
  docker_registry_mirror              = "http://${local.docker_mirror_static_ip}:5000"
}
