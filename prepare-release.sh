#!/usr/bin/env bash

set -e

function help() {
  echo "Usage: ./prepare-release.sh [-h] new_version"
  echo "Options:"
  echo " -h           Show this help message"
  echo "Arguments:"
  echo " new_version  The version to update the Terraform Module to"
}

function get_modified_tag() {
  local version="$1"
  modified_tag=${version//./-}
  modified_tag=${modified_tag::-2}
  echo "$modified_tag"
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

echo "Retrieving latest tag..."
git fetch
latest_tag=$(git describe --tags --abbrev=0 | tr -d '\n' | cut -c2-)

branch="release/prepare-$new_tag"
echo "Creating branch $branch..."
git checkout -b "$branch"

os=$(uname -s)
case $os in
  'Linux')
    echo "Updating links in READMEs..."
    find . -type f -iname "*.md" -exec sed -i -e "s/$latest_tag/$new_tag/g" {} +
    echo "Updating version in './examples..."
    find . -type f -iname "*.tf" ! -name "providers.tf" -exec sed -i -e "s/$latest_tag/$new_tag/g" {} +
    echo "Updating version in modules..."
    find . -type f -iname "*.tf" ! -name "providers.tf" -exec sed -i -e "s/$(get_modified_tag "$latest_tag")/$(get_modified_tag "$new_tag")/g" {} +
    ;;
  'Darwin')
    echo "Updating links in READMEs..."
    find . -type f -iname "*.md" -exec sed -i '' "s/$latest_tag/$new_tag/g" {} +
    echo "Updating version in './examples..."
    find . -type f -iname "*.tf" ! -name "providers.tf" -exec sed -i '' "s/$latest_tag/$new_tag/g" {} +
    echo "Updating version in modules..."
    find . -type f -iname "*.tf" ! -name "providers.tf" -exec sed -i '' "s/$(get_modified_tag "$latest_tag")/$(get_modified_tag "$new_tag")/g" {} +
    ;;
  *)
    echo "Only Mac and Linux are supported"
    exit 1
    ;;
esac

echo "Committing changes to $branch..."
git commit -a -m "Update files for $new_tag release"

echo "Pushing changes..."
git push -u origin "$branch" --force

echo ""
echo "Go to https://github.com/sourcegraph/terraform-aws-executors and open a Pull Request for this branch"
echo "Unfortunately at this time, the build will fail. A force merge is required."
echo "Once merged, run the 'release.sh' script."
