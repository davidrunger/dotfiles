# AVIT ZSH Theme

PROMPT='
${_current_dir} $(git_prompt_info) $(git_commits_ahead) $(git_commits_behind) %D{%r}
%{$fg[green]%}❯%{$reset_color%} '

PROMPT2='%{$fg[grey]%}❮%{$reset_color%} '
MODE_INDICATOR="%{$fg_bold[yellow]%}❮%{$reset_color%}%{$fg[yellow]%}❮❮%{$reset_color%}"

local _current_dir="%{$fg[blue]%}%3~%{$reset_color%} "

ZSH_THEME_GIT_COMMITS_AHEAD_SUFFIX="%{$fg[green]%}↥%{$reset_color%}"
ZSH_THEME_GIT_COMMITS_BEHIND_SUFFIX="%{$fg[red]%}↧%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[cyan]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%}✚ "
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[yellow]%}⚑ "
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%}✖ "
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[blue]%}▴ "
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[cyan]%}§ "
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[grey]%}◒ "

# LS colors, made with http://geoff.greer.fm/lscolors/
export LSCOLORS="exfxcxdxbxegedabagacad"
export LS_COLORS='di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43'
