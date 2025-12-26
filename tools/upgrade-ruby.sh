#!/usr/bin/env bash

# Example:
#   ./tools/upgrade-ruby.sh 3.4.2

# Tip: after running this and merging the PRs, then run
#   ./tools/delete-merged-branches.sh to delete the branches.

set -euo pipefail # don't allow undefined variables, pipes don't swallow errors

ruby_version_file=".ruby-version"
new_ruby_version="$1"
branch_name="bump-ruby"
ignore_dirs=$(runger-config -d ~/code/dotfiles --show forks | paste -sd '|' -)

if [[ -z "$new_ruby_version" ]]; then
  echo "Usage: $0 <new_ruby_version>"
  exit 1
fi

set -x
rbenv global "$new_ruby_version"
RBENV_VERSION="$new_ruby_version" gem update --system
RBENV_VERSION="$new_ruby_version" gem install bundler

cd "$HOME/code" || exit
set +x

for dir in $(my-repos) ; do
  cd "$dir" || exit
  blue "# $dir"

  if test -f $ruby_version_file && ! [[ "$dir" =~ ^(${ignore_dirs})$ ]] ; then
    old_ruby_version=$(head -n1 "$ruby_version_file")
    if git diff --quiet && ! branch-exists "$branch_name" && [[ "$old_ruby_version" != "$new_ruby_version" ]]; then
      set -x

      update-main-branch
      git checkout -b "$branch_name" "origin/$(main-branch)"
      sd -F "$old_ruby_version" "$new_ruby_version" .ruby-version
      bundle update --ruby --bundler
      gacm "Bump Ruby from $old_ruby_version to $new_ruby_version"
      hpr

      { set +ex; } 2>/dev/null
    else
      echo "Already at Ruby $new_ruby_version"
    fi
  else
    echo "No $ruby_version_file found"
  fi

  echo

  cd - &>/dev/null || exit
done
