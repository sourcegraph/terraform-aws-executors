locals {
  region            = "us-west-2"
  availability_zone = "us-west-2a"
}

module "executors" {
  source  = "sourcegraph/executors/aws"
  version = "5.1.1" # LATEST

  availability_zone                            = local.availability_zone
  executor_instance_tag                        = "codeintel-prod"
  executor_sourcegraph_external_url            = "https://sourcegraph.acme.com"
  executor_sourcegraph_executor_proxy_password = "hunter2"
  executor_queue_name                          = "codeintel"
  executor_metrics_environment_label           = "prod"
  executor_use_firecracker                     = true
  randomize_resource_names                     = true
}
