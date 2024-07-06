# bundle
b() { bundle install }

# build ctags
build_ctags() {
  if [[ $BUILD_CTAGS == 'true' ]]
  then
    echo
    echo 'Building CTags. Thanks for your patience! :)'
    ctags -f .gemtags -R --languages=ruby $(bundle list --paths)
    if [ $? -eq 0 ]
    then
      echo "Great job! You built CTags successfully!"
    else
      echo "There might have been a problem building CTags."
    fi
  fi
}

# git checkout branch (from (almost) all of them) w/ fzf
gca() {
  git checkout $(git for-each-ref --format="%(refname:short)" refs/heads | \
    rg -v "^(($(main-branch)|$(branch)|safe)$)" | fzf) && \
    gst
}

# git checkout branch based on current branch
gcob() {
  git checkout -b $@
  gsup
}

# find file
ff() { find . -type f -name $1 }

# "git diff date"
# shows the diff in code between the specified date and now
# example usage:
#   gddate 2022-10-01
gddate() { git diff `git rev-list -1 --before=\"$1\" $(main-branch)`..origin/$(main-branch) }

# show git diff in editor
# ex:
#   gsd ae2b5a9c7c61597e34820694fed4612639274dba
gsd() {
  git show $1 | EXT=diff tos
}

# git commit with message written in terminal
gcomm() {
  verify-on-ok-branch
  if [ $? -ne 0 ]
  then
    return 1
  fi

  git commit -m $1
}

# git rebase interactive
# Enter the number of commits back that you want to go.
# Ex: `gri 3` to rebase with the most recent 3 commits.
gri() { git rebase -i HEAD~$1 && git status -sb }

# copy my IP address to clipboard
myip() {
  curl -s ifconfig.co | cpy
}

# copy my IP v4 address to clipboard
myip4() {
  curl -s ifconfig.co -4 | cpy
}

# copy my IP v6 address to clipboard
myip6() {
  curl -s ifconfig.co -6 | cpy
}

# make directory and cd into it
mcd() { mkdir $1 && cd $1; }

# "sublime code" (open a GitHub repo in $EDITOR)
# ex: `sc https://github.com/plashchynski/crono`
sc() {
  cd ~/Downloads
  git clone $1
  repo_name=$(echo $1 | sed -E 's/https\:\/\/github.com\/[^/]*\///')
  $EDITOR $repo_name
  cd -
}

# receive input from stdout and open it in $EDITOR
# ex: `git diff | tos`
tos() {
  TMPDIR=${TMPDIR:-/tmp}  # default to /tmp if TMPDIR isn't set
  DATE="`date +%Y%m%d%H%M%S`"
  EXT=${EXT:-}
  F=$(mktemp $TMPDIR/tos-$DATE.$EXT)
  cat >| $F  # use >| instead of > if you set noclobber in bash
  $EDITOR $F
  sleep .3  # give editor a little time to open the file
}
