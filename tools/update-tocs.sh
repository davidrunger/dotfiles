#!/usr/bin/env bash

# Updates the tables of contents for all repositories using gh-md-toc.

# Tip: after running this and merging the PRs, then run
# ./tools/delete-merged-branches.sh to delete the branches.

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit 1

branch_name="update-table-of-contents"
update_command="gh-md-toc --insert README.md && rm README.md.*"
ignore_dirs=$(runger-config -d ~/code/dotfiles --show forks | paste -sd '|' -)

for dir in $(my-repos) ; do
  cd "$dir" || exit 1
  blue "# $dir"

  if [ -f README.md ] && rg --quiet '<!--ts-->' README.md && ! [[ "$dir" =~ ^(${ignore_dirs})$ ]] ; then
    set -ex
    main

    if git diff --quiet && ! branch-exists "$branch_name" ; then
      eval "$update_command"

      if [ "$(GIT_PAGER="cat" git diff --unified=0 | wc -l)" -eq 7 ] ; then
        # The TOC is up to date. The only diff is updating the updated-at timestamp.
        gco .
      else
        gfcob "$branch_name"
        git add .
        git commit --message "Update table of contents

\`$update_command\`"
        hpr
      fi
    fi

    { set +ex; } 2>/dev/null
  fi

  echo

  cd - &>/dev/null || exit 1
done
