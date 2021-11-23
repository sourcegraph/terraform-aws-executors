# Credentials module

This module can be optionally used to create the IAM user policies required to configure auto-scaling and observability of [Sourcegraph executor](https://docs.sourcegraph.com/admin/executors) in AWS.

TODO - finish
Auto-scaling requires that the executor compute instances have permissions to emit CloudWatch metrics. The sibling [executors module](https://registry.terraform.io/modules/sourcegraph/executors/aws/latest/submodules/executors)

TODO - finish
Observability of executor compute resources require that the target Sourcegraph instance's Prometheus have permissions to scrape the executor compute resources.

TODO - finish
This module produces a `instance_scraper_access_key_id` and `instance_scraper_access_secret_key` pair TODO and a `metric_writer_access_key_id` and `metric_writer_secret_key` pair TODO
