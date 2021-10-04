terraform {
  required_version = "0.13.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3"
    }
  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      "deployment" = "sourcegraph-executors"
    }
  }
}
