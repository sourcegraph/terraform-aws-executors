terraform {
  required_version = "~> 1.1.0"
  required_providers {
    aws = "~> 3.0"
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}
