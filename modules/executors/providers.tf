terraform {
  required_version = "~> 1.1.0"
  required_providers {
    aws = "~> 3.0"
  }
}

provider "aws_us_west_2" {
  region = "us-west-2"
}
