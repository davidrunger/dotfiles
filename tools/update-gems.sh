#!/usr/bin/env bash

# Updates the gems (per Gemfile.lock) for all repositories with updateable gems.

# Tip: after running this and merging the PRs, then run
# ./tools/delete-merged-branches.sh to delete the branches.

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit

for dir in $(my-repos) ; do
  cd "$dir" || exit
  blue "# $dir"

  if ls Gemfile.lock &>/dev/null ; then
    if ! [[ "$dir" =~ ^(byebug|cuprite|fixture_builder|pallets|ransack)$ ]] ; then
      set -ex

      safe

      if git diff --quiet && ! branch-exists 'bundle-update' ; then
        bundle update

        if ! git diff --quiet ; then
          gclean
          gfcob bundle-update
          bundle update
          gacm "Update gems

\`bundle update\`"
          hpr
        fi
      fi

      { set +ex; } 2>/dev/null
    fi
  fi

  echo

  cd - &>/dev/null || exit
done
