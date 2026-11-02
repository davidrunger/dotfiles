#!/usr/bin/env bash

# Example:
#   ./tools/update-python.sh 3.14.0

# Tip: after running this and merging the PRs, then run
#   ./tools/delete-merged-branches.sh to delete the branches.

set -euo pipefail # don't allow undefined variables, pipes don't swallow errors

python_version_file=".python-version"
new_python_version="${1:-}"
branch_name="bump-python"
ignore_dirs=$(runger-config -d ~/code/dotfiles --show forks | paste -sd '|' -)

# Check the Python executable selected for a package directory against its
# `.python-version` file. A mismatch can have several causes, such as a
# conflicting version constraint elsewhere in the project's mise config, so
# leave the committed change in place for manual resolution.
check-python-version() {
  local package_dir="$1"
  local expected_python_version="$2"
  local actual_python_version

  if ! actual_python_version=$(mise -C "$package_dir" exec --no-deps -- python --version 2>/dev/null); then
    echo "Warning: couldn't determine the Python version in $package_dir." >&2
    return 1
  fi
  # `python --version` prints e.g. "Python 3.14.0"
  actual_python_version="${actual_python_version#Python }"

  if [[ "$actual_python_version" != "$expected_python_version" ]]; then
    echo "Warning: python uses ${actual_python_version:-none} in $package_dir, but $python_version_file specifies Python $expected_python_version." >&2
    return 1
  fi
}

# Run this after committing so a mismatch leaves the branch and commit in
# place for manual resolution instead of discarding the requested update.
check-python-version-files() {
  local python_version_path
  local package_dir
  local expected_python_version
  local all_versions_match=true

  for python_version_path in "${python_version_files[@]}"; do
    package_dir=$(dirname "$python_version_path")
    expected_python_version=$(head -n1 "$python_version_path")
    if ! check-python-version "$package_dir" "$expected_python_version"; then
      all_versions_match=false
    fi
  done

  [[ "$all_versions_match" == true ]]
}

# Rewrite any `uses: actions/setup-python@<sha> # <tag>` pin(s) under the current
# repo's .github/ dir to the latest release. No-op if none are found, if the
# lookup for the latest release failed, or if they're already current.
bump-setup-python-action() {
  [[ -n "$latest_setup_python_sha" ]] || return 0
  [[ -d .github ]] || return 0

  local workflow_file
  while IFS= read -r workflow_file; do
    [[ -n "$workflow_file" ]] || continue
    sd \
      "${setup_python_repo}@[0-9a-f]{40}( # v[0-9.]+)?" \
      "${setup_python_repo}@${latest_setup_python_sha} # ${latest_setup_python_tag}" \
      "$workflow_file"
  done < <(rg -l "${setup_python_repo}@" .github 2>/dev/null || true)
}

if [[ -z "$new_python_version" ]]; then
  echo "Usage: $0 <new_python_version>"
  exit 1
fi

old_global_python_version=$(mise config get --global tools.python)
if [[ "$old_global_python_version" == "$new_python_version" ]]; then
  echo "Global Python is already at $new_python_version; skipping global Python setup and config branch."
  # Cheap no-op if it's already installed, but makes sure the later per-repo
  # version checks can succeed even if a previous install was interrupted.
  mise install "python@$new_python_version"
else
  # This installs the new version (compiling from source if there's no
  # precompiled build, which can take a while) and updates the global config.
  set -x
  mise use --global "python@$new_python_version"
  set +x

  # `mise use --global` just wrote to `$mise_config_file`, wherever dotfiles
  # happens to be checked out right now. Stash that change so we can carry it
  # onto a proper bump branch, same as every other repo below.
  cd "$HOME/code/dotfiles" || exit
  blue "# dotfiles (mise global config)"

  mise_config_file="mise.global-config-symlink.toml"
  mise_global_python_branch_name="mise/bump-global-python"

  if git diff --quiet -- "$mise_config_file"; then
    echo "No mise global config changes to commit."
  elif branch-exists "$mise_global_python_branch_name"; then
    echo "Branch $mise_global_python_branch_name already exists."
  else
    set -x

    update-main-branch
    git checkout -b "$mise_global_python_branch_name" "origin/$(main-branch)"
    git add "$mise_config_file"
    verify-on-ok-branch
    git commit --message "[mise] Bump global Python from $old_global_python_version to $new_python_version"
    hwm

    { set +ex; } 2>/dev/null
  fi
fi

echo

# `actions/setup-python` may add support for a new Python version quickly, but
# Dependabot's cooldown means the workflow files don't pick that update up
# right away. Look up the latest release once, up front, so every repo below
# gets bumped to the same tag/commit.
setup_python_repo="actions/setup-python"
latest_setup_python_tag=""
latest_setup_python_sha=""
if latest_setup_python_tag=$(gh api "repos/${setup_python_repo}/releases/latest" --jq '.tag_name' 2>/dev/null) \
  && latest_setup_python_sha=$(gh api "repos/${setup_python_repo}/commits/${latest_setup_python_tag}" --jq '.sha' 2>/dev/null); then
  echo "Latest $setup_python_repo: $latest_setup_python_tag ($latest_setup_python_sha)"
else
  echo "Warning: couldn't look up latest $setup_python_repo release; skipping Action pin bumps." >&2
  latest_setup_python_tag=""
  latest_setup_python_sha=""
fi

echo

code_dir="$HOME/code"
declare -A python_version_files_by_repo=()

while IFS= read -r -d '' python_version_path; do
  package_dir=$(dirname "$python_version_path")
  if ! repo_dir=$(git -C "$package_dir" rev-parse --show-toplevel 2>/dev/null); then
    echo "No Git repository found for $python_version_path; skipping."
    continue
  fi

  python_version_files_by_repo["$repo_dir"]+="$python_version_path"$'\n'
done < <(
  rg --files --hidden --null \
    --glob "$python_version_file" \
    --glob '!**/.git/**' \
    "$code_dir" 2>/dev/null || true
)

while IFS= read -r repo_dir; do
  [[ -n "$repo_dir" ]] || continue

  relative_repo_dir="${repo_dir#"$code_dir/"}"
  cd "$repo_dir" || exit
  blue "# $relative_repo_dir"

  if [[ "$relative_repo_dir" =~ ^(${ignore_dirs})$ ]]; then
    echo "Directory is ignored for Python upgrades."
  else
    python_version_files=()
    while IFS= read -r python_version_path; do
      [[ -n "$python_version_path" ]] || continue
      python_version_files+=("$python_version_path")
    done <<< "${python_version_files_by_repo[$repo_dir]}"

    old_python_version=""
    python_version_needs_update=false
    for python_version_path in "${python_version_files[@]}"; do
      current_python_version=$(head -n1 "$python_version_path")
      if [[ "$current_python_version" != "$new_python_version" ]]; then
        python_version_needs_update=true
        [[ -n "$old_python_version" ]] || old_python_version="$current_python_version"
      fi
    done

    if [[ "$python_version_needs_update" == false ]]; then
      echo "Already at Python $new_python_version"
    elif git diff --quiet && ! branch-exists "$branch_name"; then
      set -x

      update-main-branch
      git checkout -b "$branch_name" "origin/$(main-branch)"
      for python_version_path in "${python_version_files[@]}"; do
        old_python_version_for_file=$(head -n1 "$python_version_path")
        sd -F "$old_python_version_for_file" "$new_python_version" "$python_version_path"
      done
      bump-setup-python-action
      if ((${#python_version_files[@]} == 1)); then
        gacm "Bump Python from $old_python_version to $new_python_version"
      else
        gacm "Bump Python to $new_python_version"
      fi

      if check-python-version-files; then
        hpr
      else
        red "Python version mismatch in $relative_repo_dir; leaving the branch and commit in place and skipping the PR."
      fi

      { set +ex; } 2>/dev/null
    else
      echo "Worktree has changes or branch $branch_name already exists."
    fi
  fi

  echo

  cd - &>/dev/null || exit
done < <(printf '%s\n' "${!python_version_files_by_repo[@]}" | sort)
