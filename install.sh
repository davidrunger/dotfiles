#!/usr/bin/env bash

# Set up this `dotfiles` code on a computer.
#
# Run the full setup with:
#   FULL_INSTALL=1 ./install.sh

set -euo pipefail # exit on any error, don't allow undefined variables, pipes don't swallow errors

mkdir -p ~/.codex/
mkdir -p ~/.config/
mkdir -p ~/.config/bat/
mkdir -p ~/.mitmproxy/
mkdir -p ~/code/dotfiles/feature-flags/

ln -sf ~/code/dotfiles/GLOBAL_AGENTS.md ~/.codex/AGENTS.md
ln -sf ~/code/dotfiles/aprc.rb ~/.config/aprc
ln -sf ~/code/dotfiles/bat/config ~/.config/bat/config
ln -sf ~/code/dotfiles/cheat/ ~/.config/
ln -sf ~/code/dotfiles/gemrc.yml ~/.gemrc
ln -sf ~/code/dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/code/dotfiles/git/global_gitignore ~/.gitignore
ln -sf ~/code/dotfiles/irbrc.rb ~/.irbrc.rb
ln -sf ~/code/dotfiles/kitty/ ~/.config/
ln -sf ~/code/dotfiles/mise.global-config-symlink.toml ~/.config/mise/config.toml
ln -sf ~/code/dotfiles/mitmproxy.yml ~/.mitmproxy/config.yaml
ln -sf ~/code/dotfiles/pryrc.rb ~/.pryrc
ln -sf ~/code/dotfiles/ripgrep ~/.config/ripgrep
ln -sf ~/code/dotfiles/rspec ~/.rspec
ln -sf ~/code/dotfiles/zsh/themes/bolso.zsh-theme ~/.oh-my-zsh/custom/themes/bolso.zsh-theme
ln -sf ~/code/dotfiles/zshrc.zsh ~/.zshrc

touch ~/.hushlogin
touch ~/.pry_history

if [ -e "$HOME/code/dotfiles-personal/install.sh" ]; then
  cd "$HOME/code/dotfiles-personal/"
  "$HOME/code/dotfiles-personal/install.sh"
  cd - &> /dev/null
fi

if [ "${FULL_INSTALL:-0}" = "1" ]; then
  # Configure Git hooks.
  git config core.hookspath bin/githooks

  # Install Homebrew packages.
  brew bundle

  # Install Bundler plugin(s).
  (cd "$HOME" && bundle plugin install bundler-why)

  # Install global JavaScript packages.
  pnpm add --global http-server live-server prettier typescript tsx

  # Install Crystal shards.
  shards install

  # NOTE: Some of these depend on earlier steps, like `brew bundle`.
  ~/code/dotfiles/install/apt-packages.sh
  ~/code/dotfiles/install/basher.sh
  ~/code/dotfiles/install/mitmproxy-env.sh
  ~/code/dotfiles/install/oh-my-zsh.sh
  ~/code/dotfiles/install/ufw.sh
fi
