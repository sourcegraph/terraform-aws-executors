# Credentials module

This module can be optionally used to create the IAM user policies required to configure auto-scaling and observability of [Sourcegraph executor](https://docs.sourcegraph.com/admin/executors) in AWS.

Auto-scaling requires that the executor compute instances have permissions to emit CloudWatch metrics. As outlined in [how to configure auto scaling](https://docs.sourcegraph.com/admin/deploy_executors#aws), the Sourcegraph `worker` service must set the `EXECUTOR_METRIC_AWS_ACCESS_KEY_ID` and `EXECUTOR_METRIC_AWS_SECRET_ACCESS_KEY` environment variables to be the same as the `metric_writer_access_key_id` and `metric_writer_secret_key` values provided by running this module.

Observability of executor compute resources require that the target Sourcegraph instance's Prometheus have permissions to scrape the executor compute resources. As outlined in [how to configure observability](https://docs.sourcegraph.com/admin/deploy_executors#aws-1), the `instance_scraper_access_key_id` and `instance_scraper_access_secret_key` values provided by running this module must be supplied to the Sourcegraph Prometheus instance.
