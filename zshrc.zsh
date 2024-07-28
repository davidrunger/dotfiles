setopt +o nomatch # https://unix.stackexchange.com/a/310553/276727
export EDITOR='code'
export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="bolso"
plugins=(zsh-autosuggestions)
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#555555"
zstyle ':omz:lib:theme-and-appearance' gnu-ls no
source $ZSH/oh-my-zsh.sh

# Delete oh-my-zsh d function (which lists directories, I think).
unfunction d

# Remove zsh fwd-i-search / history-incremental-search-forward keyboard shortcut.
bindkey -r "^S"

if [ "$(uname)" = 'Linux' ] ; then
  . "$HOME/code/dotfiles/shell/linux.zsh"
  export LINUX=true
fi

. ~/code/dotfiles/shell/aliases.zsh
. ~/code/dotfiles/shell/functions.zsh

if [ -e "$HOME/code/dotfiles-personal/zshrc.zsh" ]; then
  . "$HOME/code/dotfiles-personal/zshrc.zsh"
fi

# asdf setup
if [ -d "$HOME/.asdf/" ]; then
  . "$HOME/.asdf/asdf.sh"
fi

# ruby setup
if [ -e ~/.rbenv/bin/rbenv ]; then
  eval "$(~/.rbenv/bin/rbenv init - zsh)"
else
  eval "$(rbenv init - zsh)"
fi

# path setup
export PATH=$PATH:/opt/homebrew/bin:/opt/homebrew/sbin

# yarn setup
if command -v yarn &> /dev/null ; then
  # https://github.com/yarnpkg/yarn/issues/ 9015#issuecomment-2141841791
  export SKIP_YARN_COREPACK_CHECK=1

  export PATH=$PATH:$(yarn global bin)
fi

# pnpm setup
if [ -d "$HOME/Library/pnpm" ]; then
  export PNPM_HOME="$HOME/Library/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
else if [ -d "$HOME/.local/share/pnpm" ]
  export PNPM_HOME="$HOME/.local/share/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
fi
# pnpm end

# basher
export PATH="$HOME/.basher/bin:$PATH"
eval "$(basher init - zsh)"

# fzf
if [ -v LINUX ] ; then
  source <(fzf --zsh)
else
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi

# Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1

export PATH=node_modules/.bin:$PATH

export PATH=$HOME/Filen/bin:$HOME/code/dotfiles-personal/bin:\
$HOME/code/dotfiles/bin:$HOME/bin:$HOME/.local/bin/:$PATH

if [[ "$(uname)" == "Linux" ]]; then
  export PATH=$HOME/code/dotfiles/bin-linux:$PATH
else if [[ "$(uname)" == "Darwin" ]]
  export PATH=$HOME/code/dotfiles/bin-mac:$PATH
fi

# https://github.com/Homebrew/homebrew-core/issues/ 121043#issuecomment-1397888835
export PATH=$PATH:$HOMEBREW_PREFIX/opt/postgresql@16/bin

# less options
export LESS='-Rj6 -X --quit-if-one-screen'
export LESSHISTFILE=- # don't store less search history https://web.archive.org/web/20141129223918/http://linuxcommand.org/man_pages/less1.html

# for SimpleCov::Formatter::Terminal
export SIMPLECOV_WRITE_TARGET_TO_FILE=1

# prevent horrible Mac/Ruby/Rails bug
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
