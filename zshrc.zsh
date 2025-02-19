if [ "$(uname)" = 'Linux' ] ; then
  export LINUX=true
elif [ "$(uname)" = 'Darwin' ] ; then
  export DARWIN=true
fi

if [ -v LINUX ] ; then
  . "$HOME/code/dotfiles/shell/linux.zsh"
elif [ -v DARWIN ] ; then
  . "$HOME/code/dotfiles/shell/mac.zsh"
fi

# Look for zsh completion definitions in dotfiles/completions/ directory.
# NOTE: This must come before loading oh-my-zsh.
fpath=(~/code/dotfiles/completions $fpath)
fpath=(~/.asdf/completions $fpath)

# zsh/oh-my-zsh
# NOTE: must come after sourcing linux.zsh, so that git is available via Homebrew for update check.
setopt +o nomatch # https://unix.stackexchange.com/a/310553/276727
export ZSH=$HOME/.oh-my-zsh
ZSH_THEME="bolso"
plugins=(
  fzf-tab # git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
  zsh-autosuggestions # git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  zsh-syntax-highlighting # git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
)
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#555555"
zstyle ':omz:update' mode disabled
zstyle ':omz:lib:theme-and-appearance' gnu-ls no
source $ZSH/oh-my-zsh.sh
# Delete oh-my-zsh d function (which lists directories, I think).
unfunction d
# Remove zsh fwd-i-search / history-incremental-search-forward keyboard shortcut.
bindkey -r "^S"

. ~/code/dotfiles/shell/aliases.zsh
. ~/code/dotfiles/shell/functions.zsh

if [ -e "$HOME/code/dotfiles-personal/zshrc.zsh" ]; then
  . "$HOME/code/dotfiles-personal/zshrc.zsh"
fi

# snap setup
export PATH=$PATH:/snap/bin

# rbenv setup
if [ -e ~/.rbenv/bin/rbenv ]; then
  eval "$(~/.rbenv/bin/rbenv init - zsh)"
fi
# NOTE: YJIT requires Rust to be installed.
# NOTE: Jemalloc requires `sudo apt-get install libjemalloc-dev`.
export RUBY_CONFIGURE_OPTS="--enable-yjit --with-jemalloc"

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
# This avoids a warning from `brew doctor`.
if [ -v LINUX ] ; then
  export XDG_DATA_DIRS="/home/linuxbrew/.linuxbrew/share:$XDG_DATA_DIRS"
fi

# Rust
. "$HOME/.cargo/env"

path=(
  $HOME/code/dotfiles-personal/bin
  $HOME/code/dotfiles/bin
  $HOME/bin/crystal-symlinks
  $HOME/bin
  $HOME/.local/bin
  node_modules/.bin
  # https://github.com/Homebrew/homebrew-core/issues/ 121043#issuecomment-1397888835
  $HOMEBREW_PREFIX/opt/postgresql@17/bin
  $path
)

# asdf setup (needs to be below path setup)
if [ -d "$HOME/.asdf/" ]; then
  export PATH="$HOME/.asdf/shims:$PATH"
fi

if [ -v LINUX ] ; then
  path=($HOME/code/dotfiles/bin-linux $path)
else if [ -v DARWIN ]
  path=($HOME/code/dotfiles/bin-mac $path)
fi

export PATH

export EDITOR=editor

# Set up (in the background) symlinks for programs written in Crystal
{ ( symlink-crystal-programs >&3 & ) } 3>&1

# less options
export LESS='--quit-if-one-screen -Rj6 -X'
export LESSHISTFILE=- # don't store less search history https://web.archive.org/web/20141129223918/http://linuxcommand.org/man_pages/less1.html

# for SimpleCov::Formatter::Terminal
export SIMPLECOV_TERMINAL_HYPERLINK_PATTERN="vscode://file/%f:%l"

# prevent horrible Mac/Ruby/Rails bug
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# History
export HISTSIZE=123123
export SAVEHIST="$HISTSIZE"

# Atuin (https://github.com/atuinsh/atuin)
. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh --disable-up-arrow)"
