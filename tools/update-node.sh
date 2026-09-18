#!/usr/bin/env bash

# Example:
#   ./tools/update-node.sh 24.0.0

# Tip: after running this and merging the PRs, then run
#   ./tools/delete-merged-branches.sh to delete the branches.

set -euo pipefail # don't allow undefined variables, pipes don't swallow errors

node_version_file=".node-version"
new_node_version="${1:-}"
branch_name="bump-node"
ignore_dirs=$(runger-config -d ~/code/dotfiles --show forks | paste -sd '|' -)

# Check the Node executable selected for a package directory against its
# `.node-version` file. A mismatch can have several causes, such as a
# conflicting version constraint in `package.json`, so leave the committed
# change in place for manual resolution.
check-node-version() {
  local package_dir="$1"
  local expected_node_version="$2"
  local actual_node_version

  if ! actual_node_version=$(mise -C "$package_dir" exec --no-deps -- node --version 2>/dev/null); then
    echo "Warning: couldn't determine the Node version in $package_dir." >&2
    return 1
  fi
  actual_node_version="${actual_node_version#v}"

  if [[ "$actual_node_version" != "$expected_node_version" ]]; then
    echo "Warning: node uses ${actual_node_version:-none} in $package_dir, but $node_version_file specifies Node $expected_node_version." >&2
    return 1
  fi
}

# Run this after committing so a mismatch leaves the branch and commit in
# place for manual resolution instead of discarding the requested update.
check-node-version-files() {
  local node_version_path
  local package_dir
  local expected_node_version
  local all_versions_match=true

  for node_version_path in "${node_version_files[@]}"; do
    package_dir=$(dirname "$node_version_path")
    expected_node_version=$(head -n1 "$node_version_path")
    if ! check-node-version "$package_dir" "$expected_node_version"; then
      all_versions_match=false
    fi
  done

  [[ "$all_versions_match" == true ]]
}

# Rewrite any `uses: actions/setup-node@<sha> # <tag>` pin(s) under the current
# repo's .github/ dir to the latest release. No-op if none are found, if the
# lookup for the latest release failed, or if they're already current.
bump-setup-node-action() {
  [[ -n "$latest_setup_node_sha" ]] || return 0
  [[ -d .github ]] || return 0

  local workflow_file
  while IFS= read -r workflow_file; do
    [[ -n "$workflow_file" ]] || continue
    sd \
      "${setup_node_repo}@[0-9a-f]{40}( # v[0-9.]+)?" \
      "${setup_node_repo}@${latest_setup_node_sha} # ${latest_setup_node_tag}" \
      "$workflow_file"
  done < <(rg -l "${setup_node_repo}@" .github 2>/dev/null || true)
}

if [[ -z "$new_node_version" ]]; then
  echo "Usage: $0 <new_node_version>"
  exit 1
fi

old_global_node_version=$(mise config get --global tools.node)
if [[ "$old_global_node_version" == "$new_node_version" ]]; then
  echo "Global Node is already at $new_node_version; skipping global Node setup and config branch."
else
  set -x
  mise use --global "node@$new_node_version"
  set +x

  # `mise use --global` just wrote to `$mise_config_file`, wherever dotfiles
  # happens to be checked out right now. Stash that change so we can carry it
  # onto a proper bump-node branch, same as every other repo below.
  cd "$HOME/code/dotfiles" || exit
  blue "# dotfiles (mise global config)"

  mise_config_file="mise.global-config-symlink.toml"
  mise_global_node_branch_name="mise/bump-global-node"

  if git diff --quiet -- "$mise_config_file"; then
    echo "No mise global config changes to commit."
  elif branch-exists "$mise_global_node_branch_name"; then
    echo "Branch $mise_global_node_branch_name already exists."
  else
    set -x

    update-main-branch
    git checkout -b "$mise_global_node_branch_name" "origin/$(main-branch)"
    git add "$mise_config_file"
    verify-on-ok-branch
    git commit --message "[mise] Bump global Node from $old_global_node_version to $new_node_version"
    hwm

    { set +ex; } 2>/dev/null
  fi
fi

echo

# `actions/setup-node` may add support for a new Node version quickly, but
# Dependabot's cooldown means the workflow files don't pick that update up
# right away. Look up the latest release once, up front, so every repo below
# gets bumped to the same tag/commit.
setup_node_repo="actions/setup-node"
latest_setup_node_tag=""
latest_setup_node_sha=""
if latest_setup_node_tag=$(gh api "repos/${setup_node_repo}/releases/latest" --jq '.tag_name' 2>/dev/null) \
  && latest_setup_node_sha=$(gh api "repos/${setup_node_repo}/commits/${latest_setup_node_tag}" --jq '.sha' 2>/dev/null); then
  echo "Latest $setup_node_repo: $latest_setup_node_tag ($latest_setup_node_sha)"
else
  echo "Warning: couldn't look up latest $setup_node_repo release; skipping Action pin bumps." >&2
  latest_setup_node_tag=""
  latest_setup_node_sha=""
fi

echo

code_dir="$HOME/code"
declare -A node_version_files_by_repo=()

while IFS= read -r -d '' node_version_path; do
  package_dir=$(dirname "$node_version_path")
  if ! repo_dir=$(git -C "$package_dir" rev-parse --show-toplevel 2>/dev/null); then
    echo "No Git repository found for $node_version_path; skipping."
    continue
  fi

  node_version_files_by_repo["$repo_dir"]+="$node_version_path"$'\n'
done < <(
  rg --files --hidden --null \
    --glob "$node_version_file" \
    --glob '!**/.git/**' \
    "$code_dir" 2>/dev/null || true
)

while IFS= read -r repo_dir; do
  [[ -n "$repo_dir" ]] || continue

  relative_repo_dir="${repo_dir#"$code_dir/"}"
  cd "$repo_dir" || exit
  blue "# $relative_repo_dir"

  if [[ "$relative_repo_dir" =~ ^(${ignore_dirs})$ ]]; then
    echo "Directory is ignored for Node upgrades."
  else
    node_version_files=()
    while IFS= read -r node_version_path; do
      [[ -n "$node_version_path" ]] || continue
      node_version_files+=("$node_version_path")
    done <<< "${node_version_files_by_repo[$repo_dir]}"

    old_node_version=""
    node_version_needs_update=false
    for node_version_path in "${node_version_files[@]}"; do
      current_node_version=$(head -n1 "$node_version_path")
      if [[ "$current_node_version" != "$new_node_version" ]]; then
        node_version_needs_update=true
        [[ -n "$old_node_version" ]] || old_node_version="$current_node_version"
      fi
    done

    if [[ "$node_version_needs_update" == false ]]; then
      echo "Already at Node $new_node_version"
    elif git diff --quiet && ! branch-exists "$branch_name"; then
      set -x

      update-main-branch
      git checkout -b "$branch_name" "origin/$(main-branch)"
      for node_version_path in "${node_version_files[@]}"; do
        old_node_version_for_file=$(head -n1 "$node_version_path")
        sd -F "$old_node_version_for_file" "$new_node_version" "$node_version_path"
      done
      bump-setup-node-action
      if ((${#node_version_files[@]} == 1)); then
        gacm "Bump Node from $old_node_version to $new_node_version"
      else
        gacm "Bump Node to $new_node_version"
      fi

      if check-node-version-files; then
        hpr
      else
        red "Node version mismatch in $relative_repo_dir; leaving the branch and commit in place and skipping the PR."
      fi

      { set +ex; } 2>/dev/null
    else
      echo "Worktree has changes or branch $branch_name already exists."
    fi
  fi

  echo

  cd - &>/dev/null || exit
done < <(printf '%s\n' "${!node_version_files_by_repo[@]}" | sort)
