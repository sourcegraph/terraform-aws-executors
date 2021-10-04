provider "aws" {
  region = local.region

  default_tags {
    tags = {
      "deployment" = "sourcegraph-executors"
    }
  }
}
