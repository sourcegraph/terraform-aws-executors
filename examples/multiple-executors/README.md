# Multiple executor example

This example uses [networking](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.10.0/submodules/networking), [docker-mirror](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.10.0/submodules/docker-mirror), and [executors](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.10.0/submodules/executors) submodules that provision a network, a Docker registry mirror, and sets of resources running one or more types of executors.

The following variables must be supplied:

- `sourcegraph_external_url`, `sourcegraph_executor_proxy_password`, `queue_name`, `metrics_environment_label`, and `instance_tag`: Analogous to the `executor_*` variables in the `single-executor` example.
- `resource_prefix`: A prefix unique to each set of compute resources. This prevents collisions between two uses of the `executors` module. We recommend this value be constructed the same way `instance_tag` is constructed.
- `docker_registry_mirror`: This variable is given the value `"http://${module.docker-mirror.ip_address}:5000"`, which converts the raw external IP address to an address resolvable by the executor instances.

If your deployment environment already has a Docker registry that can be used, only the `executor` submodule must be used (and references to the `networking` and `docker-mirror` modules can be dropped). The Docker registry mirror address can be supplied along with its containing VPC and subnet as pre-existing identifier literals.

All of these module's variables are defined in [modules/networking/variables.tf](https://github.com/sourcegraph/terraform-aws-executors/blob/v5.10.0/modules/networking/variables.tf), [modules/docker-mirror/variables.tf](https://github.com/sourcegraph/terraform-aws-executors/blob/v5.10.0/modules/docker-mirror/variables.tf), and [modules/executors/variables.tf](https://github.com/sourcegraph/terraform-aws-executors/blob/v5.10.0/modules/executors/variables.tf).