#!/usr/bin/env bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

get_latest() {
  git fetch

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

NEW="$1"

if [ -z "$NEW" ]; then
  echo "Usage  : bash release.sh <version>"
  echo "Example: bash release.sh 1.2.3"
  echo ""
  echo "Fetching tags..."
  latest="$(get_latest)"
  echo -n "The current version is: $latest"

  exit 1
fi

if [[ "$NEW" == v* ]]; then
  echo "<version> must not start with \"v\""
  exit 1
fi

echo "Checking for clean working tree..."
if [[ "$(git diff --stat)" != "" ]]; then
  echo "❌ Dirty working tree (try git stash)"
  exit 1
fi

echo "Checking that we're on master..."
if [[ "$(git symbolic-ref HEAD | tr -d '\n')" != "refs/heads/master" ]]; then
  echo "❌ Not on master (try git checkout master)"
  exit 1
fi

echo "Checking that master is up to date..."
git fetch
if [[ "$(git rev-parse master)" != "$(git rev-parse origin/master)" ]]; then
  echo "❌ master is out of sync with origin/master (try git pull)"
  exit 1
fi

git ls-tree -r HEAD --name-only -z examples | xargs -0 sed -i.sedbak "s/\"[0-9]*\.[0-9]*\.[0-9]*\" # LATEST/\"$NEW\" # LATEST/g"
find . -name "*.sedbak" -print0 | xargs -0 rm

git commit --all --message "release $NEW"
git tag "v$NEW"
git push --tags
git push

echo ""
echo "✅ Released $NEW"
echo ""
echo "- Tags   : https://github.com/sourcegraph/terraform-aws-executors/tags"
echo "- Commits: https://github.com/sourcegraph/terraform-aws-executors/commits/master"
echo ""
echo "Make sure CI goes green 🟢:"
echo ""
echo "- https://buildkite.com/sourcegraph/terraform-aws-executors/builds?branch=master"
echo "- https://buildkite.com/sourcegraph/terraform-aws-executors/builds?branch=v$NEW"
