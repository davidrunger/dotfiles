#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "$HOME/.basher" ]; then
  git clone --depth=1 https://github.com/basherpm/basher.git "$HOME/.basher"
fi

# Initialize basher for this script's own process so `basher install` below
# actually works. This is separate from the init lines that need to be in
# `zshrc.zsh`.
export PATH="$HOME/.basher/bin:$PATH"
eval "$(basher init - bash)"

if ! command -v gh-md-toc &> /dev/null; then
  basher install ekalinin/github-markdown-toc
fi
