#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
fi

# The installer renames any existing ~/.zshrc (even a symlink) to
# ~/.zshrc.pre-oh-my-zsh and drops in its own template. Reassert the
# dotfiles symlink afterward so this stays correct either way.
rm -f ~/.zshrc.pre-oh-my-zsh
ln -sf ~/code/dotfiles/zshrc.zsh ~/.zshrc

if [ "$SHELL" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

declare -A plugin_repos=(
  [fzf-tab]="https://github.com/Aloxaf/fzf-tab"
  [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
  [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

for plugin in "${!plugin_repos[@]}"; do
  dest="$zsh_custom/plugins/$plugin"
  if [ ! -d "$dest" ]; then
    git clone "${plugin_repos[$plugin]}" "$dest"
  fi
done
