# Single executor example

This example uses the [root module](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.10.0) that provisions a network, a Docker registry mirror, and a set of resources to run _one_ type of executor. To provision more than one type of executor (multiple queues or multiple environments), see the following `multiple-executors` example.

The following variables must be supplied:

**Note**: these variables must be set in tandem with changes to the target [Sourcegraph deployment](https://docs.sourcegraph.com/admin/deploy_executors).

- `executor_sourcegraph_external_url`: The URL from which the target Sourcegraph instance is accessible from the executor instances.
- `executor_sourcegraph_executor_proxy_password`: The shared executor password defined in Sourcegraph. The value must be the same as the `executors.accessToken` site setting described in [Configuring executors and instance communication](https://docs.sourcegraph.com/admin/deploy_executors#configuring-executors-and-instance-communication).
- `executor_queue_name`: The name of the target queue to process (e.g., `codeintel`, `batches`).
- `executor_metrics_environment_label`: The name of the target environment (e.g., `staging`, `prod`). This value must be the same as the `EXECUTOR_METRIC_ENVIRONMENT_LABEL` environment variable as described in [Configuring auto scaling](https://docs.sourcegraph.com/admin/deploy_executors#aws).
- `executor_instance_tag`: Compute instances are tagged by this value by the key `executor_tag`. We recommend this value take the form `{executor_queue_name}-{executor_metrics_environment_label}`. This value must be the same as `INSTANCE_TAG` as described in [Configuring observability](https://docs.sourcegraph.com/admin/deploy_executors#aws-1).

All of this module's variables are defined in [variables.tf](https://github.com/sourcegraph/terraform-aws-executors/blob/v5.10.0/variables.tf).
