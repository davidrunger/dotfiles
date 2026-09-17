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

# Rewrite any `uses: ruby/setup-ruby@<sha> # <tag>` pin(s) under the current
# repo's .github/ dir to the latest release. No-op if none are found, if the
# lookup above failed, or if they're already current.
bump-setup-ruby-action() {
  [[ -n "$latest_setup_ruby_sha" ]] || return 0
  [[ -d .github ]] || return 0

  local workflow_file
  rg -l "${setup_ruby_repo}@" .github 2>/dev/null | while IFS= read -r workflow_file; do
    sd \
      "${setup_ruby_repo}@[0-9a-f]{40}( # v[0-9.]+)?" \
      "${setup_ruby_repo}@${latest_setup_ruby_sha} # ${latest_setup_ruby_tag}" \
      "$workflow_file"
  done
}

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

# `ruby/setup-ruby` usually adds support for a new Ruby version quickly, but
# Dependabot's cooldown means the workflow files don't pick that update up
# right away. Look up the latest release once, up front, so every repo below
# gets bumped to the same tag/commit.
setup_ruby_repo="ruby/setup-ruby"
latest_setup_ruby_tag=""
latest_setup_ruby_sha=""
if latest_setup_ruby_tag=$(gh api "repos/${setup_ruby_repo}/releases/latest" --jq '.tag_name' 2>/dev/null) \
  && latest_setup_ruby_sha=$(gh api "repos/${setup_ruby_repo}/commits/${latest_setup_ruby_tag}" --jq '.sha' 2>/dev/null); then
  echo "Latest $setup_ruby_repo: $latest_setup_ruby_tag ($latest_setup_ruby_sha)"
else
  echo "Warning: couldn't look up latest $setup_ruby_repo release; skipping Action pin bumps." >&2
  latest_setup_ruby_tag=""
  latest_setup_ruby_sha=""
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
      bump-setup-ruby-action
      if test -f Gemfile.lock ; then
        mise exec -- bundle update --ruby --bundler
      else
        echo "No Gemfile.lock found; skipping bundle update."
      fi
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
