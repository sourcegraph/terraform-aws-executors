#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

python3 -m unittest discover -s scripts/tests
python3 scripts/render_release.py --check
