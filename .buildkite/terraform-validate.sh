#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

MODULES=(
  modules/docker-mirror
  modules/executors
  modules/networking
)

for module in "${MODULES[@]}"; do
  pushd "${module}"
  terraform init
  terraform validate .
  popd
done
