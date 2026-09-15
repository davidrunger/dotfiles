#!/usr/bin/env bash
set -euo pipefail

mitmproxy_env_vars_source=~/code/dotfiles/mitmproxy_env.sh
mitmproxy_env_vars_destination=/etc/X11/Xsession.d/90mitmproxy_env

# Check whether it's worth making the user type in their password (i.e. if update is needed).
if [ ! -f "$mitmproxy_env_vars_destination" ] || \
    ! diff -q "$mitmproxy_env_vars_source" "$mitmproxy_env_vars_destination" > /dev/null ;
then
  sudo ln -sf "$mitmproxy_env_vars_source" "$mitmproxy_env_vars_destination"
fi
