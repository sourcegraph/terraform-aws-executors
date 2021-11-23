#!/usr/bin/env bash

scratch=$(mktemp -d -t tmp.XXXXXXXXXX)
function finish() {
  rm -rf "$scratch"
}
trap finish EXIT

set -e -o pipefail

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

check_versions() {
  file_pattern="$1"
  all_regex="$2"
  correct_regex="$3"
  find . -name "$file_pattern" -print0 | xargs -0 grep -n "$all_regex" >"$scratch/all.txt" || true
  find . -name "$file_pattern" -print0 | xargs -0 grep -n "$correct_regex" >"$scratch/correct.txt" || true
  if ! (git diff --color -U0 --no-index --exit-code "$scratch/all.txt" "$scratch/correct.txt" | tail -n +6); then
    echo ""
    echo "❌ Detected out of sync versions in the lines above (should be version $latest)"
    exit 1
  fi
}

check_versions \
  "*.tf" \
  "# LATEST" \
  "\"$latest\" # LATEST"

check_versions \
  "*.md" \
  "https://registry.terraform.io/modules/sourcegraph/executors/aws/[0-9]\+\.[0-9]\+\.[0-9]\+" \
  "https://registry.terraform.io/modules/sourcegraph/executors/aws/$latest"

check_versions \
  "*.md" \
  "https://github.com/sourcegraph/terraform-aws-executors/blob/v[0-9]\+\.[0-9]\+\.[0-9]\+" \
  "https://github.com/sourcegraph/terraform-aws-executors/blob/v$latest"
