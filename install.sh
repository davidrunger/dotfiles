#!/usr/bin/env bash

mkdir -p ~/.config/

ln -sf ~/code/dotfiles/aprc.rb ~/.config/aprc
ln -sf ~/code/dotfiles/asdfrc ~/.asdfrc
ln -sf ~/code/dotfiles/gemrc.yml ~/.gemrc
ln -sf ~/code/dotfiles/git/gitconfig ~/.gitconfig
ln -sf ~/code/dotfiles/global_gitignore ~/.gitignore
ln -sf ~/code/dotfiles/irbrc.rb ~/.irbrc.rb
ln -sf ~/code/dotfiles/pryrc.rb ~/.pryrc
ln -sf ~/code/dotfiles/rspec ~/.rspec
ln -sf ~/code/dotfiles/rubocop.yml ~/.rubocop.yml
ln -sf ~/code/dotfiles/zsh/themes/bolso.zsh-theme ~/.oh-my-zsh/custom/themes/bolso.zsh-theme
ln -sf ~/code/dotfiles/zshrc.sh ~/.zshrc

if [ -d "$HOME/code/commonlit" ]; then
  ln -sf ~/code/dotfiles/commonlit/initializers/z.rb ~/code/commonlit/config/initializers/z.rb
  ln -sf ~/code/dotfiles/commonlit/personal/qr.rb ~/code/commonlit/personal/qr.rb
  ln -sf \
    ~/code/dotfiles/commonlit/workers/load_runner.rb \
    ~/code/commonlit/app/workers/load_runner.rb
fi

if [ -e "$HOME/code/dotfiles-personal/install.sh" ]; then
  cd $HOME/code/dotfiles-personal/
  $HOME/code/dotfiles-personal/install.sh
  cd - &> /dev/null
fi

git config core.hookspath ~/code/dotfiles/git/hooks/dotfiles

touch ~/.hushlogin
touch ~/.pry_history

# Uninstall/untap commonlit Brewfile tools that I don't use.
# brew uninstall dopplerhq/cli/doppler > /dev/null 2>&1 || true
# brew untap dopplerhq/cli > /dev/null 2>&1 || true

# brew bundle

# gem install \
#   amazing_print \
#   benchmark-ips \
#   chronic \
#   clipboard \
#   fcom \
#   guard \
#   guard-shell \
#   memery \
#   memo_wise \
#   runger_config \
#   runger_style \
#   simple_cov-formatter-terminal \
#   slop \
#   tapp

# yarn global add \
#   collapsify \
#   http-server \
#   ts-node
