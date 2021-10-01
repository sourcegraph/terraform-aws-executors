#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

shfmt -i 2 -ci -d .
