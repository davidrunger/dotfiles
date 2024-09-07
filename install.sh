#!/usr/bin/env bash

set -euo pipefail # exit on any error, don't allow undefined variables, pipes don't swallow errors

mkdir -p ~/.config/
mkdir -p ~/.mitmproxy/
mkdir -p ~/code/dotfiles/feature-flags/

ln -sf ~/code/dotfiles/aprc.rb ~/.config/aprc
ln -sf ~/code/dotfiles/asdfrc ~/.asdfrc
ln -sf ~/code/dotfiles/cheat/ ~/.config/
ln -sf ~/code/dotfiles/gemrc.yml ~/.gemrc
ln -sf ~/code/dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/code/dotfiles/git/global_gitignore ~/.gitignore
ln -sf ~/code/dotfiles/irbrc.rb ~/.irbrc.rb
ln -sf ~/code/dotfiles/kitty/ ~/.config/
ln -sf ~/code/dotfiles/mitmproxy.yml ~/.mitmproxy/config.yaml
ln -sf ~/code/dotfiles/pryrc.rb ~/.pryrc
ln -sf ~/code/dotfiles/rspec ~/.rspec
ln -sf ~/code/dotfiles/zsh/themes/bolso.zsh-theme ~/.oh-my-zsh/custom/themes/bolso.zsh-theme
ln -sf ~/code/dotfiles/zshrc.zsh ~/.zshrc

# Check whether it's worth making the user type in their password (i.e. if update is needed).
mitmproxy_env_vars_source=~/code/dotfiles/mitmproxy_env.sh
mitmproxy_env_vars_destination=/etc/X11/Xsession.d/90mitmproxy_env
if [ ! -f "$mitmproxy_env_vars_destination" ] || \
    ! diff -q "$mitmproxy_env_vars_source" "$mitmproxy_env_vars_destination" > /dev/null ;
then
  sudo ln -sf "$mitmproxy_env_vars_source" "$mitmproxy_env_vars_destination"
fi

if [ -e "$HOME/code/dotfiles-personal/install.sh" ]; then
  cd "$HOME/code/dotfiles-personal/"
  "$HOME/code/dotfiles-personal/install.sh"
  cd - &> /dev/null
fi

git config core.hookspath bin/githooks

touch ~/.hushlogin
touch ~/.pry_history

# install-apt-packages ~/code/dotfiles/packages.txt

# brew bundle

# bundle install

# pnpm add --global http-server prettier typescript tsx

# shards install
