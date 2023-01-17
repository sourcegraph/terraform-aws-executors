#!/usr/bin/env bash

set -e

function help() {
  echo "Usage: ./release.sh [-h] new_version"
  echo "Options:"
  echo " -h           Show this help message"
  echo "Arguments:"
  echo " new_version  The version to tag the repository to."
}

while getopts "h" opt; do
  case ${opt} in
  h)
    help
    exit 0
    ;;
  \?)
    echo "Invalid option: $OPTARG" 1>&2
    exit 1
    ;;
  esac
done

new_tag="$1"

if [[ -z "$new_tag" ]]; then
  echo "Missing new version argument"
  help
  exit 1
fi

if [[ "$new_tag" == v* ]]; then
  echo "<version> must not start with \"v\""
  exit 1
fi

echo "Checking out master and fetching latest changes..."
git checkout master && git pull

echo "Creating tag v$new_tag..."
git tag "v$new_tag"

echo "Pushing tags..."
git push --tags

echo ""
echo "Now, make sure CI goes green 🟢(rerun builds until green):"
echo ""
echo "- https://buildkite.com/sourcegraph/terraform-aws-executors/builds?branch=master"
echo "- https://buildkite.com/sourcegraph/terraform-aws-executors/builds?branch=v$new_tag"
