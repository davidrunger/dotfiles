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
old_global_ruby_version=$(mise config get --global tools.ruby)
mise use --global "ruby@$new_ruby_version"
mise exec "ruby@$new_ruby_version" -- gem update --system
mise exec "ruby@$new_ruby_version" -- gem install bundler
set +x

# `mise use --global` just wrote to $mise_config_file, wherever dotfiles
# happens to be checked out right now. Stash that change so we can carry
# it onto a proper bump-ruby branch, same as every other repo below.
cd "$HOME/code/dotfiles" || exit
blue "# dotfiles (mise global config)"

mise_config_file="mise.global-config-symlink.toml"
mise_global_ruby_branch_name="mise/bump-global-ruby"

if git diff --quiet -- "$mise_config_file"; then
  echo "No mise global config changes to commit."
elif branch-exists "$mise_global_ruby_branch_name"; then
  echo "Branch $mise_global_ruby_branch_name already exists."
else
  set -x

  update-main-branch
  git checkout -b "$mise_global_ruby_branch_name" "origin/$(main-branch)"
  git add "$mise_config_file"
  verify-on-ok-branch
  git commit --message "[mise] Bump global Ruby from $old_global_ruby_version to $new_ruby_version"
  hwm

  { set +ex; } 2>/dev/null
fi

echo

cd "$HOME/code" || exit

for dir in $(my-repos) ; do
  cd "$dir" || exit
  blue "# $dir"

  if ! test -f $ruby_version_file ; then
    echo "No $ruby_version_file found."
  elif [[ "$dir" =~ ^(${ignore_dirs})$ ]] ; then
    echo "Directory is ignored for Ruby upgrades."
  else
    old_ruby_version=$(head -n1 "$ruby_version_file")
    if git diff --quiet && ! branch-exists "$branch_name" && [[ "$old_ruby_version" != "$new_ruby_version" ]]; then
      set -x

      update-main-branch
      git checkout -b "$branch_name" "origin/$(main-branch)"
      sd -F "$old_ruby_version" "$new_ruby_version" .ruby-version
      mise exec -- bundle update --ruby --bundler
      gacm "Bump Ruby from $old_ruby_version to $new_ruby_version"
      hpr

      { set +ex; } 2>/dev/null
    else
      echo "Already at Ruby $new_ruby_version"
    fi
  fi

  echo

  cd - &>/dev/null || exit
done
