#!/usr/bin/env bash

# Updates the NPM packages (per `yarn.lock` or `pnpm-lock.yaml`) for all
# repositories with updatable NPM packages.

# Tip: after running this and merging the PRs, then run
# ./tools/delete-merged-branches.sh to delete the branches.

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit 1

branch_name="update-npm-packages"
ignore_dirs=$(runger-config -d ~/code/dotfiles --show forks | paste -sd '|' -)

update_and_create_pr() {
  local update_command="$1"

  # Execute the update command.
  eval "$update_command"

  # If there are changes, commit them and open a PR.
  if ! git diff --quiet; then
    gfcob "$branch_name"
    git add .
    git commit --message "Update NPM packages

\`$update_command\`"
    hpr
  fi
}

for dir in $(my-repos) ; do
  cd "$dir" || exit 1
  blue "# $dir"

  if { [ -f yarn.lock ] || [ -f pnpm-lock.yaml ]; } && ! [[ "$dir" =~ ^(${ignore_dirs})$ ]] ; then
    set -ex
    main

    if git diff --quiet && ! branch-exists "$branch_name" ; then
      if [ -f pnpm-lock.yaml ]; then
        update_and_create_pr "pnpx npm-check-updates --upgrade && pnpm install && pnpm dedupe"
      elif [ -f yarn.lock ]; then
        update_and_create_pr "yarn upgrade --latest && pnpx yarn-deduplicate yarn.lock"
      fi
    fi

    { set +ex; } 2>/dev/null
  fi

  echo

  cd - &>/dev/null || exit 1
done
