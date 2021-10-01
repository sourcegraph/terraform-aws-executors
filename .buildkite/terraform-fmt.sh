#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

terraform fmt -check -recursive .
