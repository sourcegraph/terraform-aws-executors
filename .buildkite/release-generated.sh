#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

version=$(cat release/version)
sg release run test --workdir=. --version "v${version}" --type minor --inputs="server=v${version}"
