# Terraform module for Sourcegraph executors (AWS)

This repository provides a [Terraform module](https://learn.hashicorp.com/tutorials/terraform/module-use?in=terraform/modules) to provision [Sourcegraph executor](https://sourcegraph.com/docs/admin/executors) compute resources on AWS. If you are installing executors for the first time, [follow our complete setup guide](https://sourcegraph.com/docs/admin/executors/deploy_executors).

![Infrastructure overview](https://raw.githubusercontent.com/sourcegraph/terraform-aws-executors/master/images/infrastructure.png)

This repository provides four submodules:

1. The [executors module](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0/submodules/executors) provisions compute resources for executors.
2. The [docker-mirror module](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0/submodules/docker-mirror) provisions a Docker registry pull-through cache.
3. The [networking module](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0/submodules/networking) provisions a network to be shared by the executor and Docker registry resources.
4. The [credentials module](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0/submodules/credentials) provisions credentials required by the Sourcegraph instance to enable observability and auto-scaling of executors.

The [multiple-executors example](https://github.com/sourcegraph/terraform-aws-executors/blob/v7.6.0/examples/multiple-executors) uses the submodule directly to provision multiple executor resource groups performing different types of work. Follow this example if you are:


1. Provisioning executors for use with multiple features (e.g., both [auto-indexing](https://sourcegraph.com/docs/code_intelligence/explanations/auto_indexing) and [server-side batch changes](https://sourcegraph.com/docs/batch_changes/explanations/server_side)), or
2. Provisioning resources for multiple Sourcegraph instances (e.g., test, prod)

This repository also provides a [root module](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0) combining the executors, network, and docker-mirror resources into an easier to use package.

The [single-executor example](https://github.com/sourcegraph/terraform-aws-executors/blob/v7.6.0/examples/single-executor) uses the root module to provision a single executor type. Follow this example if you are deploying to a single Sourcegraph instance and using a single executors-backed feature.

## Requirements

- [Terraform](https://www.terraform.io/) 
  - 4.1.0 and below: `~> 1.1.0`
  - 4.2.0 and above: `>= 1.1.0, < 2.0.0`
- [hashicorp/aws](https://registry.terraform.io/providers/hashicorp/aws): `>= 5.0, < 7.0`

## Setup

Please follow our [setup guide](https://sourcegraph.com/docs/admin/executors/deploy_executors_terraform) on how to deploy
executors using Terraform.

### Sizing executor instances

The root module uses `executor_machine_type` to select the EC2 instance type and defaults to `c5n.metal` (72 vCPUs and 192 GiB of memory). `c5n.metal` is not required: you can use any instance that meets the isolation requirements below. Choose its size based on per-job resources, concurrency, and measured workload, as described in Sourcegraph's [executor capacity guidance](https://sourcegraph.com/docs/self-hosted/executors/resource-sizing).

Sourcegraph's [binary deployment requirements](https://sourcegraph.com/docs/self-hosted/executors/deploy-executors-binary#dependencies) specify that, when Firecracker isolation is enabled, the instance must be amd64 and expose KVM at `/dev/kvm`. You can use a bare-metal instance or a non-metal instance with AWS nested virtualization enabled. As of August 2026, [AWS supports nested virtualization](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html#nested-virtualization-considerations) on the following Intel-based families: `C8i`, `M8i`, `R8i`, `C8id`, `M8id`, `R8id`, `C8i-flex`, `M8i-flex`, `R8i-flex`, `X8i`, `C7i`, `M7i`, `R7i`, `C7i-flex`, `M7i-flex`, and `I7i`. Nitro-based instances outside this list are not necessarily supported.

[AWS requires nested virtualization to be enabled](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html#nested-virtualization-launch-new-instance) as an EC2 CPU option when launching a supported non-metal instance; selecting the instance type alone does not enable it. If Firecracker isolation is disabled, KVM is not required.

Each executor instance can run up to `executor_maximum_num_jobs` jobs concurrently (18 by default), and each job can use the resources configured by `executor_job_num_cpus` (4 by default) and `executor_job_memory` (`12GB` by default).

Following Sourcegraph's [capacity calculation](https://sourcegraph.com/docs/self-hosted/executors/resource-sizing#calculate-capacity-for-concurrent-jobs), estimate the maximum concurrent demand as:

- vCPUs: `executor_maximum_num_jobs * executor_job_num_cpus`
- memory: `executor_maximum_num_jobs * executor_job_memory`
- Firecracker disk: `executor_maximum_num_jobs * executor_firecracker_disk_space`

These products are worst-case capacity-planning values, not reservations. The defaults allow overcommit on the assumption that jobs do not all reach every limit simultaneously. If that assumption does not fit your workload, select a larger instance or reduce `executor_maximum_num_jobs` and the per-job limits. Leave capacity for the operating system, the executor process, VM images, job workspaces, and other overhead. The root module's `executor_boot_disk_size` defaults to 100 GB.

When `executor_use_firecracker` is enabled (the default), `executor_job_num_cpus` must be either `1` or an even number. `executor_firecracker_disk_space` must also be set to a valid data size such as `20GB` (the default). Before deploying, verify that the selected instance exposes `/dev/kvm`.

If you use the `executors` submodule directly, use the corresponding unprefixed variables: `machine_type`, `maximum_num_jobs`, `job_num_cpus`, `job_memory`, `firecracker_disk_space`, and `boot_disk_size`.

### Custom Security Group

By default, the Terraform module will create two security groups. One for the Docker Mirror and the other for 
the Launch Template. To provide a custom security group instead, set the variable `security_group_id` with 
the ID of the security group.

If a custom security group is provided, the following rules need to be set

* Allows ingress access on the specified SSH CIDR range (defaults to `10.0.0.0/16`)
* Allows ingress access to the Docker Registry on the specified HTTP CIDR range (defaults to `10.0.0.0/16`)
* Allows all outgoing network traffic

### Minumum IAM Permissions

An example `iam-policy.json` is provided to demonstrate the minimal permissions required to deploy and destroy an executor Terraform module. Replace all instances of `AWS_ACCOUNT_ID` in the JSON file with the account ID you wish to deploy your executors into.

## Compatibility with Sourcegraph

The **major** and **minor** versions both need to match the Sourcegraph version the executors are talking to. Patch version **don't** need to match and it's generally advised to use the latest available.
For example:

| **Sourcegraph version** | **Terraform module version** |
| ----------------------- | ---------------------------- |
| 3.37.0                  | 3.37.\*                      |
| 3.37.3                  | 3.37.\*                      |
| 3.38.0                  | 3.38.\*                      |
