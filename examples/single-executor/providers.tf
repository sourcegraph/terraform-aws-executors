provider "aws" {
  region = local.region

  default_tags {
    tags = {
      "Name"         = null
      "executor_tag" = null
      "deployment"   = "sourcegraph-executors"
    }
  }
}
