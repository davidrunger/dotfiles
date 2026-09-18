# bundle
b() { bundle install }

# git checkout branch based on current branch
gcob() {
  git checkout -b $@
  gsup
}

# find file
ff() { find . -type f -name $1 }

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
