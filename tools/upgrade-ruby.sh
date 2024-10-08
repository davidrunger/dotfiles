#!/usr/bin/env bash

# Example:
#   ./tools/upgrade-ruby.sh 3.3.0 3.3.2

# Tip: after running this and merging the PRs, then run
#   ./tools/delete-merged-branches.sh to delete the branches.

set -euo pipefail # don't allow undefined variables, pipes don't swallow errors

ruby_version_file=".ruby-version"
old_ruby_version="$1"
new_ruby_version="$2"

set -x
rbenv global "$new_ruby_version"
RBENV_VERSION="$new_ruby_version" gem update --system
RBENV_VERSION="$new_ruby_version" gem install bundler

cd "$HOME/code" || exit
set +x

for dir in $(my-repos) ; do
  cd "$dir" || exit
  blue "# $dir"

  if test -f $ruby_version_file && rg --quiet -F "$old_ruby_version" $ruby_version_file ; then
    set -x

    gfcob bump-ruby
    sd -F "$old_ruby_version" "$new_ruby_version" .ruby-version
    bundle update --ruby --bundler
    gacm "Bump Ruby from $old_ruby_version to $new_ruby_version"
    hpr

    { set +ex; } 2>/dev/null
  else
    echo "Not at Ruby $old_ruby_version"
  fi

  echo

  cd - &>/dev/null || exit
done
