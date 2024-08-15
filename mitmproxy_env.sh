#!/bin/sh

if [ -f "$HOME/code/dotfiles/feature-flags/mitmproxy" ] ; then
  mitmproxy_address="http://127.0.0.1:8080"

  # http/https/ftp/no_proxy
  export http_proxy="$mitmproxy_address"
  export https_proxy="$mitmproxy_address"
  # export ftp_proxy="$mitmproxy_address"
  # export no_proxy="127.0.0.1,localhost"

  # For curl
  export HTTP_PROXY="$mitmproxy_address"
  export HTTPS_PROXY="$mitmproxy_address"
  # export FTP_PROXY="$mitmproxy_address"
  # export NO_PROXY="127.0.0.1,localhost"
fi
