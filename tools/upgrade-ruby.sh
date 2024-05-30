#!/usr/bin/env bash

# Example:
# ./tools/upgrade-ruby.sh 3.3.0 3.3.2

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

ruby_version_file=".ruby-version"
old_ruby_version="$1"
new_ruby_version="$2"

cd "$HOME/code" || exit

for dir in */ ; do
  cd "$dir" || exit
  echo
  blue "# $dir"

  if test -e $ruby_version_file && rg -F "$old_ruby_version" $ruby_version_file ; then
    set -x

    gfcob bump-ruby && \
      sd -F "$old_ruby_version" "$new_ruby_version" .ruby-version && \
      bundle update --ruby && \
      gacm "Bump Ruby from $old_ruby_version to $new_ruby_version" && \
      hpr

    set +x
  else
    echo "Not at Ruby $old_ruby_version"
  fi

  cd - || exit
done
