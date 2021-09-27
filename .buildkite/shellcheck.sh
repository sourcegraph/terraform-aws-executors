#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

SHELL_SCRIPTS=()
while IFS='' read -r line; do SHELL_SCRIPTS+=("$line"); done < <(find . -type f -name '*.sh')
shellcheck --external-sources --source-path="SCRIPTDIR" --color=always "${SHELL_SCRIPTS[@]}"
