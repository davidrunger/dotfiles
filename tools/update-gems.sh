#!/usr/bin/env bash

# Updates the gems (per Gemfile.lock) for all repositories with updateable gems.

# Tip: after running this and merging the PRs, then run
# ./tools/delete-merged-branches.sh to delete the branches.

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit

for dir in $(my-repos) ; do
  cd "$dir" || exit
  blue "# $dir"

  if fd --has-results --glob Gemfile.lock ; then
    set -ex

    if ! branch-exists 'bundle-update' ; then
      bundle update

      if ! git diff --quiet ; then
        gstash
        gfcob bundle-update
        gunstash
        gacm 'Update gems

`bundle update`'
        hpr
      fi
    fi

    { set +ex; } 2>/dev/null
  fi

  echo

  cd - > /dev/null 2>&1 || exit
done
