#!/usr/bin/env bash

mkdir -p ~/.config/

ln -sf ~/code/dotfiles/aprc.rb ~/.config/aprc
ln -sf ~/code/dotfiles/gemrc.yml ~/.gemrc
ln -sf ~/code/dotfiles/global_gitignore ~/.gitignore
ln -sf ~/code/dotfiles/irbrc.rb ~/.irbrc.rb
ln -sf ~/code/dotfiles/pryrc.rb ~/.pryrc
ln -sf ~/code/dotfiles/rspec ~/.rspec
ln -sf ~/code/dotfiles/rubocop.yml ~/.rubocop.yml
ln -sf ~/code/dotfiles/zsh/themes/bolso.zsh-theme ~/.oh-my-zsh/custom/themes/bolso.zsh-theme
ln -sf ~/code/dotfiles/zshrc.sh ~/.zshrc

if [ -d "~/code/commonlit/" ]; then
  ln -sf ~/code/dotfiles/commonlit/initializers/z.rb ~/code/commonlit/config/initializers/z.rb
  ln -sf ~/code/dotfiles/commonlit/personal/qr.rb ~/code/commonlit/personal/qr.rb
  ln -sf \
    ~/code/dotfiles/commonlit/workers/load_runner.rb \
    ~/code/commonlit/app/workers/load_runner.rb
fi

touch ~/.hushlogin
touch ~/.pry_history

# gem install \
#   amazing_print \
#   benchmark-ips \
#   chronic \
#   fcom \
#   foreman \
#   guard \
#   guard-shell \
#   memery \
#   memo_wise \
#   runger_style \
#   simple_cov-formatter-terminal \
#   slop \
#   tapp
# yarn global add ts-node
