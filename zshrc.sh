setopt +o nomatch # https://unix.stackexchange.com/a/310553/276727
export EDITOR='code'
export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="bolso"
plugins=(zsh-autosuggestions)
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#555555"
zstyle ':omz:lib:theme-and-appearance' gnu-ls no
source $ZSH/oh-my-zsh.sh

. ~/code/dotfiles/shell/aliases.sh
. ~/code/dotfiles/shell/functions.sh

if [ -e "$HOME/code/dotfiles-personal/zshrc.sh" ]; then
  . "$HOME/code/dotfiles-personal/zshrc.sh"
fi

if [ "$(uname)" = 'Linux' ] ; then
  . "$HOME/code/dotfiles/shell/linux.sh"
  export LINUX=true
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
  export PATH=$(yarn global bin):$PATH
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

# Homebrew
export HOMEBREW_NO_AUTO_UPDATE=1

export PATH=node_modules/.bin:$PATH

export PATH=$HOME/Filen/bin:$HOME/code/dotfiles-personal/bin:$HOME/code/dotfiles/bin:$HOME/bin:$PATH

# https://github.com/Homebrew/homebrew-core/issues/ 121043#issuecomment-1397888835
export PATH=$PATH:$HOMEBREW_PREFIX/opt/postgresql@16/bin

# load fzf (fuzzy searching)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# less options
export LESS='-Rj6 -X --quit-if-one-screen'
export LESSHISTFILE=- # don't store less search history https://web.archive.org/web/20141129223918/http://linuxcommand.org/man_pages/less1.html

# for SimpleCov::Formatter::Terminal
export SIMPLECOV_WRITE_TARGET_TO_FILE=1

# use homebrew curl rather than system curl
export PATH="/opt/homebrew/opt/curl/bin:$PATH"

# prevent horrible Mac/Ruby bug https://commonlit.slack.com/archives/C5BFTS7NC/p1643900889475599
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# jest config
export DEBUG_PRINT_LIMIT=99999999

# Variables for git-related commands:
export GIT_SELF_AUTHOR_NAME="David Runger"

# Export here because in `.env` file seems to be too late.
# Relevant issue: https://github.com/DataDog/dd-trace-rb/issues/3084
export DD_TRACE_STARTUP_LOGS=false
