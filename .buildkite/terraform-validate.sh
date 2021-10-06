#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

MODULES=(
  ./modules/networking
  ./modules/docker-mirror
  ./modules/executors
  ./modules/credentials
  .
  ./examples/single-executor
  ./examples/multiple-executors
)

# Ensure terraform validate has a valid region
# https://github.com/hashicorp/terraform/issues/21408#issuecomment-495746582
export AWS_DEFAULT_REGION=us-east-2

for module in "${MODULES[@]}"; do
  pushd "${module}"
  terraform init
  terraform validate .
  popd
done
