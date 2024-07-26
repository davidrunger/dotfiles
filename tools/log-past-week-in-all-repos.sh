#!/usr/bin/env bash

set -euo pipefail # exit on any error, don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit

for dir in $(my-repos) ; do
  cd "$dir" || exit
  blue "# $dir"

  sha_to_diff_against=$(git rev-list "$(main-branch)" --after="7 days ago" --reverse HEAD | sed -n '1p')


  if [ "$sha_to_diff_against" = "" ] ; then
    red 'No recent commits.'
  else
    git --no-pager log --oneline "$sha_to_diff_against^.." --color=always | rg -v '^.{0,12}[0-9a-f]{5,40}.{0,12} Bump '
  fi

  echo

  cd - &>/dev/null || exit
done
