module "executors" {
  source  = "sourcegraph/executors/aws"
  version = "0.0.6"

  region                                       = local.region # REMOVE ME
  availability_zone                            = local.availability_zone
  docker_mirror_static_ip                      = local.docker_mirror_static_ip
  executor_instance_tag                        = "codeintel-prod"
  executor_sourcegraph_external_url            = "https://sourcegraph.acme.com"
  executor_sourcegraph_executor_proxy_username = "executor"
  executor_sourcegraph_executor_proxy_password = "hunter2"
  executor_queue_name                          = "codeintel"
  executor_metrics_environment_label           = "prod"
}
