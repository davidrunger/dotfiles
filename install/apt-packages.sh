#!/usr/bin/env bash

set -euo pipefail # exit on any error, don't allow undefined variables, pipes don't swallow errors

sudo apt update

is_installed() {
  dpkg -l "$1" &> /dev/null
}

# Install packages in provided package list file (if they are not already installed).
while IFS= read -r package; do
  if is_installed "$package"; then
    echo "$package is already installed"
  else
    blue "Installing $package"
    sudo apt install -y "$package"
  fi
done < ~/code/dotfiles/packages.txt
