#!/usr/bin/env bash

# Example:
#   ./tools/delete-merged-branches.sh

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit

for dir in $(my-repos) ; do
  cd "$dir" || exit
  echo
  blue "# $dir"

  set -e
  safe
  gdm
  gb
  set +e

  echo
  cd - > /dev/null || exit
done
