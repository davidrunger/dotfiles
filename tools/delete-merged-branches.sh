#!/usr/bin/env bash

# Example:
#   ./tools/delete-merged-branches.sh

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit

for dir in */ ; do
  cd "$dir" || exit
  echo
  blue "# $dir"

  if branch-exists 'safe' ; then
    set -e

    safe
    gdm
    gb

    set +e
  else
    echo 'Skipping because no "safe" branch is present.'
  fi

  echo

  cd - || exit
done
