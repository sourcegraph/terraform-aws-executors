#!/usr/bin/env bash

scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
function finish() {
  rm -rf "$scratch"
}
trap finish EXIT

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

get_latest() {
  git fetch --tags

  git describe --tags --abbrev=0 |
    # drop `v` prefix
    cut -c2- |

    # drop newline
    tr -d '\n'
}

latest="$(get_latest)"

git grep --line-number "# LATEST" examples >"$scratch/want.txt" || true
git grep --line-number "\"$latest\" # LATEST" examples >"$scratch/got.txt" || true

if ! git diff --no-index --exit-code "$scratch/want.txt" "$scratch/got.txt"; then
  echo ""
  echo "❌ Detected old versions! Make sure that all versions \`version = \"...\" # LATEST\` match the latest git tag: $latest"
  exit 1
fi
