alias bc='bc -l'
alias br='bin/rubocop'
alias bs='bin/rspec'
alias chr='open -a Google\ Chrome'
alias cop='run-rubocop'
alias dbr='bin/rails db:rollback db:test:prepare'
alias dl='curl -O'
alias dots='cd ~/code/dotfiles'
alias dotsp='cd ~/code/dotfiles-personal'
alias down='cd ~/Downloads'
alias fix='git diff --name-only | uniq | xargs $EDITOR'
alias fs='format-sql'
alias fsk='redis-cli -n 1 FLUSHDB && sk' # `-n 1` because of `REDIS_DATABASE_NUMBER=1` in `.env`
alias gac='ga . && gcom'
alias gba='GIT_PAGER=cat git branch -vv'
alias gbdf='git branch -D $(active-branches | fzf)'
alias gcme='git commit --allow-empty --message'
alias gcomt='GIT_EDITOR=true gcom'
alias gcoom='git checkout origin/$(main-branch)'
alias gcpf='git cherry-pick $(active-branches | fzf)'
alias gcpfa='git cherry-pick $(non-main-branches | fzf)'
alias gcu='git add . && git commit -m "Z Update"'
alias gd='git diff --no-prefix'
alias gdc='git diff --no-prefix --cached'
alias gdob='git diff origin/$(git branch --show-current)..$(git branch --show-current)'
alias gemd='cd "$(gem-directory)"'
alias gemdg='cd "$(gem-directory)/../bundler/gems"'
alias gg="git log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) %C(bold green)%d%C(reset) %C(white)%s%C(reset) - %C(bold white)%an%C(reset) %C(bold yellow)(%ar)%C(reset)' --all"
alias gig='s ~/.gitignore'
alias gla='git diff --stat $(main-branch)'
alias glc='git diff --stat HEAD^'
alias gld='git diff --stat'
alias glm='git log $(main-branch)..'
alias gmod='$EDITOR $(gf)'
alias gmodc='$EDITOR $(git diff --name-only HEAD^..HEAD)'
alias gpr='git pull --rebase'
alias gpwm='gpf && wm'
alias gra='git rebase --abort'
alias grc='GIT_EDITOR=true git rebase --continue'
alias grep='grep  --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'
alias grs='git rebase --show-current-patch'
alias gsf='git show $(active-branches | fzf)'
alias gsl='git show -s --format=%s'
alias hwm='hpr && echo && wm'
alias hwm='hpr && echo && wm'
alias ls='eza --binary'
alias md='mkdir -p'
alias mdm='main && gdm && echo "----" && gb'
alias rc="bin/rails console"
alias rmrf='rm -rf'
alias rr='bin/rails routes'
alias rs="bin/rails server"
alias rv='for file in $(gf); do whose $file; echo; done'
alias s.='$EDITOR .'
alias s='$EDITOR'
alias sha='git log $(main-branch) --format=format:%H | head -n 1 | cut -c 1-8 | cpy'
alias shaf='git log $(main-branch) --format=format:%H | head -n 1 | cpy'
alias sk="SIDEKIQ_CONCURRENCY=1 bin/sidekiq"
alias ss='bin/spring stop'
alias td='s $HOME/notes/TODO.md'
alias wm='wait-merge'
alias work='cd ~/code'
alias zrc='$EDITOR ~/.zshrc'
alias zs='source ~/.zshrc'

if [ -e "$HOME/code/dotfiles-personal/shell/aliases.zsh" ]; then
  . "$HOME/code/dotfiles-personal/shell/aliases.zsh"
fi

if [ -v LINUX ] ; then
  . "$HOME/code/dotfiles/shell/aliases-linux.zsh"
elif [ -v DARWIN ] ; then
  . "$HOME/code/dotfiles/shell/aliases-mac.zsh"
fi
