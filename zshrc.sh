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

# asdf setup
. "$HOME/.asdf/asdf.sh"

# ruby setup
eval "$(rbenv init - zsh)"

# path setup
export PATH=node_modules/.bin:$(yarn global bin):bin:$HOME/bin:$HOME/code/dotfiles/bin:$PATH:\
/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

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
