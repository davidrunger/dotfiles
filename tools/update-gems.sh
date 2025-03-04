#!/usr/bin/env bash

# Updates the gems (per Gemfile.lock) for all repositories with updateable gems.

# Tip: after running this and merging the PRs, then run
# ./tools/delete-merged-branches.sh to delete the branches.

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit 1

branch_name="bundle-update"
ignore_dirs=$(runger-config --show forks | paste -sd '|' -)

for dir in $(my-repos) ; do
  cd "$dir" || exit 1
  blue "# $dir"

  if [ -f Gemfile.lock ] && ! [[ "$dir" =~ ^(${ignore_dirs})$ ]] ; then
    set -ex
    main

    if git diff --quiet && ! branch-exists "$branch_name" ; then
      bundle update

      if ! git diff --quiet ; then
        git add .
        git commit --message "Update gems

\`bundle update\`"
        gfcob "$branch_name"
        gcp main
        git branch --force main origin/main
        hpr
      fi
    fi

    { set +ex; } 2>/dev/null
  fi

  echo

  cd - &>/dev/null || exit 1
done
