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

if [ -e "$HOME/code/dotfiles-personal/install.sh" ]; then
  cd $HOME/code/dotfiles-personal/
  $HOME/code/dotfiles-personal/install.sh
  cd - &> /dev/null
fi

git config core.hookspath ~/code/dotfiles/git/hooks/dotfiles

touch ~/.hushlogin
touch ~/.pry_history

# brew bundle

# pnpm add --global http-server
