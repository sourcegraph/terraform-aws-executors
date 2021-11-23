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

  git tag |
    # drop `v` prefix
    grep "^v" |
    cut -c2- |

    # sort by semantic version
    sort -t "." -k1,1n -k2,2n -k3,3n |

    # last
    tail -n 1 |

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
