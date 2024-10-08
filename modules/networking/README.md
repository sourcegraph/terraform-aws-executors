# Networking module

This module provides the networking glue between the sibling [executors](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.8.1/submodules/executors) and [docker-mirror](https://registry.terraform.io/modules/sourcegraph/executors/aws/5.8.1/submodules/docker-mirror) modules.

This module is very simple, creating only a network and a subnet by default.

Using the `nat` flag, an optional NAT will be provisioned in the network, too. This can be useful in conjunction with the `assign_public_ip` option of the executors and docker-mirror modules to create a private network without public IPs.
