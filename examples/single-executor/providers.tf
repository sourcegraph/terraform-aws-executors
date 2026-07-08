terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

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
