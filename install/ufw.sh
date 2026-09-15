#!/usr/bin/env bash
set -euo pipefail

local_ip=$(ip -4 route get 1.1.1.1 2>/dev/null |
  awk '
    {
      for (field = 1; field <= NF; field++) {
        if ($field == "src") {
          print $(field + 1)
          exit
        }
      }
    }
  ' || true)

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed

sudo ufw logging low
sudo ufw app default skip

sudo ufw allow 53317

if [ -n "$local_ip" ]; then
  lan_subnet="${local_ip%.*}.0/24"
  sudo ufw allow from "$lan_subnet" to any port 3000 proto tcp
  sudo ufw allow from "$lan_subnet" to any port 3036 proto tcp
else
  echo "Could not determine local IP — skipping LAN-scoped rules for ports 3000/3036." >&2
fi

sudo ufw --force enable
sudo ufw status verbose
