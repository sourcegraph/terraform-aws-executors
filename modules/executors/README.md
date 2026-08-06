# Executors module

This module provides the resources to provision [Sourcegraph executor](https://docs.sourcegraph.com/admin/executors) compute resources on AWS. For a high-level overview of the resources deployed by this module, see the [root module](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0). This module includes the following resources:

- AWS launch template
- AWS autoscaler and autoscaling policy
- CloudWatch log group
- CloudWatch metric alarms
- Security groups and IAM role policy attachments

This module does **not** automatically create networking or Docker mirror resources. The `vpc_id`, `subnet_id`, and `docker_registry_mirror` variables must be supplied explicitly with resources that have been previously created.

This module is often used with the sibling modules that create [networking](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0/submodules/networking) and [Docker mirror](https://registry.terraform.io/modules/sourcegraph/executors/aws/7.6.0/submodules/docker-mirror) resources which can be shared by multiple instances of the executor module (listening to different queues or being deployed in a different environment).

## Sizing executor instances

`machine_type` selects the EC2 instance type and defaults to `c5n.metal` (72 vCPUs and 192 GiB of memory). `c5n.metal` is not required: you can use any instance that meets the isolation requirements below. Choose its size based on per-job resources, concurrency, and measured workload, as described in Sourcegraph's [executor capacity guidance](https://sourcegraph.com/docs/self-hosted/executors/resource-sizing).

Sourcegraph's [binary deployment requirements](https://sourcegraph.com/docs/self-hosted/executors/deploy-executors-binary#dependencies) specify that, when Firecracker isolation is enabled, the instance must be amd64 and expose KVM at `/dev/kvm`. You can use a bare-metal instance or a non-metal instance with AWS nested virtualization enabled. As of August 2026, [AWS supports nested virtualization](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html#nested-virtualization-considerations) on the following Intel-based families: `C8i`, `M8i`, `R8i`, `C8id`, `M8id`, `R8id`, `C8i-flex`, `M8i-flex`, `R8i-flex`, `X8i`, `C7i`, `M7i`, `R7i`, `C7i-flex`, `M7i-flex`, and `I7i`. Nitro-based instances outside this list are not necessarily supported.

[AWS requires nested virtualization to be enabled](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nested-virtualization.html#nested-virtualization-launch-new-instance) as an EC2 CPU option when launching a supported non-metal instance; selecting the instance type alone does not enable it. If Firecracker isolation is disabled, KVM is not required.

Each instance can run up to `maximum_num_jobs` jobs concurrently (18 by default), with per-job limits set by `job_num_cpus` (4 by default) and `job_memory` (`12GB` by default).

Following Sourcegraph's [capacity calculation](https://sourcegraph.com/docs/self-hosted/executors/resource-sizing#calculate-capacity-for-concurrent-jobs), estimate the maximum concurrent demand as:

- vCPUs: `maximum_num_jobs * job_num_cpus`
- memory: `maximum_num_jobs * job_memory`
- Firecracker disk: `maximum_num_jobs * firecracker_disk_space`

These products represent worst-case demand rather than reserved capacity. The defaults allow overcommit because jobs are not expected to reach every limit simultaneously. Choose a larger instance, or reduce concurrency and per-job limits, if that assumption does not fit your workload. Also leave capacity for the operating system, executor process, VM images, job workspaces, and other overhead. `boot_disk_size` defaults to 500 GB when this submodule is used directly.

When `use_firecracker` is enabled (the default), `job_num_cpus` must be either `1` or an even number. `firecracker_disk_space` must be a valid data size such as `20GB` (the default). Before deploying, verify that the selected instance exposes `/dev/kvm`.
