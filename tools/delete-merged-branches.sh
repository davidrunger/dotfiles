#!/usr/bin/env bash

# Example:
#   ./tools/delete-merged-branches.sh

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit

for dir in */ ; do
  cd "$dir" || exit
  echo
  blue "# $dir"

  if [[ "$dir" =~ ^dotfiles ]] ; then
    echo 'Skipping a dotfiles directory.'
  else
    git checkout safe || gfcob safe
    update-main-branches
    gdm
    gb
  fi

  cd - || exit
done
