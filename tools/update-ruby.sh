#!/usr/bin/env bash

# Example:
#   ./tools/update-ruby.sh 4.0.7

# Tip: after running this and merging the PRs, then run
#   ./tools/delete-merged-branches.sh to delete the branches.

set -euo pipefail # don't allow undefined variables, pipes don't swallow errors

ruby_version_file=".ruby-version"
new_ruby_version="${1:-}"
branch_name="bump-ruby"
ignore_dirs=$(runger-config -d ~/code/dotfiles --show forks | paste -sd '|' -)

# Rewrite any `uses: ruby/setup-ruby@<sha> # <tag>` pin(s) under the current
# repo's .github/ dir to the latest release. No-op if none are found, if the
# lookup for the latest release failed, or if they're already current.
bump-setup-ruby-action() {
  [[ -n "$latest_setup_ruby_sha" ]] || return 0
  [[ -d .github ]] || return 0

  local workflow_file
  while IFS= read -r workflow_file; do
    [[ -n "$workflow_file" ]] || continue
    sd \
      "${setup_ruby_repo}@[0-9a-f]{40}( # v[0-9.]+)?" \
      "${setup_ruby_repo}@${latest_setup_ruby_sha} # ${latest_setup_ruby_tag}" \
      "$workflow_file"
  done < <(rg -l "${setup_ruby_repo}@" .github 2>/dev/null || true)
}

if [[ -z "$new_ruby_version" ]]; then
  echo "Usage: $0 <new_ruby_version>"
  exit 1
fi

old_global_ruby_version=$(mise config get --global tools.ruby)
if [[ "$old_global_ruby_version" == "$new_ruby_version" ]]; then
  echo "Global Ruby is already at $new_ruby_version; skipping global Ruby setup and config branch."
else
  set -x
  mise use --global "ruby@$new_ruby_version"
  mise exec "ruby@$new_ruby_version" -- gem update --system
  mise exec "ruby@$new_ruby_version" -- gem install bundler
  set +x

  # `mise use --global` just wrote to `$mise_config_file`, wherever dotfiles
  # happens to be checked out right now. Stash that change so we can carry it
  # onto a proper bump-ruby branch, same as every other repo below.
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

code_dir="$HOME/code"
declare -A ruby_version_files_by_repo=()

# Collect version files first so all Ruby packages in one repository share a
# branch and commit.
while IFS= read -r -d '' ruby_version_path; do
  package_dir=$(dirname "$ruby_version_path")
  if ! repo_dir=$(git -C "$package_dir" rev-parse --show-toplevel 2>/dev/null); then
    echo "No Git repository found for $ruby_version_path; skipping."
    continue
  fi

  ruby_version_files_by_repo["$repo_dir"]+="$ruby_version_path"$'\n'
done < <(
  rg --files --hidden --null \
    --glob "$ruby_version_file" \
    --glob '!**/.git/**' \
    "$code_dir" 2>/dev/null || true
)

while IFS= read -r repo_dir; do
  [[ -n "$repo_dir" ]] || continue

  relative_repo_dir="${repo_dir#"$code_dir/"}"
  cd "$repo_dir" || exit
  blue "# $relative_repo_dir"

  if [[ "$relative_repo_dir" =~ ^(${ignore_dirs})$ ]]; then
    echo "Directory is ignored for Ruby upgrades."
  else
    ruby_version_files=()
    while IFS= read -r ruby_version_path; do
      [[ -n "$ruby_version_path" ]] || continue
      ruby_version_files+=("$ruby_version_path")
    done <<< "${ruby_version_files_by_repo[$repo_dir]}"

    old_ruby_version=""
    ruby_version_needs_update=false
    for ruby_version_path in "${ruby_version_files[@]}"; do
      current_ruby_version=$(head -n1 "$ruby_version_path")
      if [[ "$current_ruby_version" != "$new_ruby_version" ]]; then
        ruby_version_needs_update=true
        [[ -n "$old_ruby_version" ]] || old_ruby_version="$current_ruby_version"
      fi
    done

    if [[ "$ruby_version_needs_update" == false ]]; then
      echo "Already at Ruby $new_ruby_version"
    elif git diff --quiet && ! branch-exists "$branch_name"; then
      set -x

      update-main-branch
      git checkout -b "$branch_name" "origin/$(main-branch)"
      for ruby_version_path in "${ruby_version_files[@]}"; do
        old_ruby_version_for_file=$(head -n1 "$ruby_version_path")
        if [[ "$old_ruby_version_for_file" != "$new_ruby_version" ]]; then
          sd -F "$old_ruby_version_for_file" "$new_ruby_version" "$ruby_version_path"

          package_dir=$(dirname "$ruby_version_path")
          if test -f "$package_dir/Gemfile.lock"; then
            (cd "$package_dir" && mise exec -- bundle update --ruby --bundler)
          else
            echo "No $package_dir/Gemfile.lock found; skipping bundle update."
          fi
        fi
      done
      bump-setup-ruby-action
      if ((${#ruby_version_files[@]} == 1)); then
        gacm "Bump Ruby from $old_ruby_version to $new_ruby_version"
      else
        gacm "Bump Ruby to $new_ruby_version"
      fi
      hpr

      { set +ex; } 2>/dev/null
    else
      echo "Worktree has changes or branch $branch_name already exists."
    fi
  fi

  echo

  cd - &>/dev/null || exit
done < <(printf '%s\n' "${!ruby_version_files_by_repo[@]}" | sort)
