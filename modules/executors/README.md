# Executors module

This module provides the resources to provision [Sourcegraph executor](https://docs.sourcegraph.com/admin/executors) compute resources on AWS. For a high-level overview of the resources deployed by this module, see the [root module](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.6.0). This module includes the following resources:

- AWS launch template
- AWS autoscaler and autoscaling policy
- CloudWatch log group
- CloudWatch metric alarms
- Security groups and IAM role policy attachments

This module does **not** automatically create networking or Docker mirror resources. The `vpc_id`, `subnet_id`, and `docker_registry_mirror` variables must be supplied explicitly with resources that have been previously created.

This module is often used with the sibling modules that create [networking](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.6.0/submodules/networking) and [Docker mirror](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.6.0/submodules/docker-mirror) resources which can be shared by multiple instances of the executor module (listening to different queues or being deployed in a different environment).
