# Terraform module for Sourcegraph executors (AWS)

This repository provides a [Terraform module](https://learn.hashicorp.com/tutorials/terraform/module-use?in=terraform/modules) to provision [Sourcegraph executor](https://docs.sourcegraph.com/admin/executors) compute resources on AWS. If you are installing executors for the first time, [follow our complete setup guide](https://docs.sourcegraph.com/admin/deploy_executors).

![Infrastructure overview](https://raw.githubusercontent.com/sourcegraph/terraform-aws-executors/master/images/infrastructure.png)

This repository provides four submodules:

1. The [executors module](https://registry.terraform.io/modules/sourcegraph/executors/aws/3.39.0/submodules/executors) provisions compute resources for executors.
1. The [docker-mirror module](https://registry.terraform.io/modules/sourcegraph/executors/aws/3.39.0/submodules/docker-mirror) provisions a Docker registry pull-through cache.
1. The [networking module](https://registry.terraform.io/modules/sourcegraph/executors/aws/3.39.0/submodules/networking) provisions a network to be shared by the executor and Docker registry resources.
1. The [credentials module](https://registry.terraform.io/modules/sourcegraph/executors/aws/3.39.0/submodules/credentials) provisions credentials required by the Sourcegraph instance to enable observability and auto-scaling of executors.

The [multiple-executors example](https://github.com/sourcegraph/terraform-aws-executors/blob/v3.39.0/examples/multiple-executors) uses the submodule directly to provision multiple executor resource groups performing different types of work. Follow this example if you are:

1. Provisioning executors for use with multiple features (e.g., both [auto-indexing](https://docs.sourcegraph.com/code_intelligence/explanations/auto_indexing) and [server-side batch changes](https://docs.sourcegraph.com/batch_changes/explanations/server_side)), or
1. Provisioning resources for multiple Sourcegraph instances (e.g., test, prod)

This repository also provides a [root module](https://registry.terraform.io/modules/sourcegraph/executors/aws/3.39.0) combining the executors, network, and docker-mirror resources into an easier to use package.

The [single-executor example](https://github.com/sourcegraph/terraform-aws-executors/blob/v3.39.0/examples/single-executor) uses the root module to provision a single executor type. Follow this example if you are deploying to a single Sourcegraph instance and using a single executors-backed feature.

## Requirements

- [Terraform](https://www.terraform.io/) ~> 1.1.0
- [hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws/3.0.0) ~> 3.0.0

## Compatibility with Sourcegraph

The **major** and **minor** versions both need to match the Sourcegraph version the executors are talking to. Patch version **don't** need to match and it's generally advised to use the latest available.
For example:

| **Sourcegraph version** | **Terraform module version** |
| ----------------------- | ---------------------------- |
| 3.37.0                  | 3.37.\*                      |
| 3.37.3                  | 3.37.\*                      |
| 3.38.0                  | 3.38.\*                      |
