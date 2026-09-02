#!/usr/bin/env bash

# Updates a gem for all repositories using that gem that can update it.

# Usage: GEM_NAME=runger_style ./tools/update-a-gem.sh

# Tip: after running this and merging the PRs, then run
# ./tools/delete-merged-branches.sh to delete the branches.

set -uo pipefail # don't allow undefined variables, pipes don't swallow errors

cd "$HOME/code" || exit 1

if [ -z "${GEM_NAME:-}" ] ; then
  echo "Usage: GEM_NAME=gem-name ./tools/update-a-gem.sh" >&2
  exit 1
fi

branch_name="bump-$GEM_NAME"
ignore_dirs=$(runger-config -d ~/code/dotfiles --show forks | paste -sd '|' -)

for dir in $(my-repos) ; do
  cd "$dir" || exit 1
  blue "# $dir"

  if [ -f Gemfile.lock ] && ! [[ "$dir" =~ ^(${ignore_dirs})$ ]] && ruby -rbundler -e "lockfile = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock')); exit lockfile.specs.any? { |spec| spec.name == ENV.fetch('GEM_NAME') }" ; then
    set -ex
    main

    if git diff --quiet && ! branch-exists "$branch_name" ; then
      old_gem_version="$(ruby -rbundler -e "puts Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock')).specs.find { |spec| spec.name == ENV.fetch('GEM_NAME') }&.version")"
      bundle update "$GEM_NAME" --cooldown=0
      new_gem_version="$(ruby -rbundler -e "puts Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock')).specs.find { |spec| spec.name == ENV.fetch('GEM_NAME') }&.version")"

      if ! git diff --quiet ; then
        gfcob "$branch_name"
        git add Gemfile Gemfile.lock
        git commit --message "Bump $GEM_NAME from $old_gem_version to $new_gem_version

\`bundle update $GEM_NAME --cooldown=0\`"
        hwm || true
      fi
    fi

    { set +ex; } 2>/dev/null
  fi

  echo

  cd - &>/dev/null || exit 1
done
