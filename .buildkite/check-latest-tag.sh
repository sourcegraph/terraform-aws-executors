#!/usr/bin/env bash

set -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..

get_latest() {
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

git grep --line-number "# LATEST" examples >want.txt
git grep --line-number "\"$latest\" # LATEST" examples >got.txt

if ! git diff --no-index --exit-code want.txt got.txt; then
  echo ""
  echo "❌ Detected old versions! Make sure that all versions \`version = \"...\" # LATEST\` match the latest git tag: $latest"
  exit 1
fi
