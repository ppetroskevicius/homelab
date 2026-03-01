#!/usr/bin/env bash
set -euo pipefail

# Check if 1Password CLI is available
if ! command -v op &>/dev/null; then
  echo "Warning: 1Password CLI (op) not found. WireGuard setup may be incomplete."
  exit 0
fi

# Set up WireGuard config (Linux only)
if [ "$(uname -s)" != "Darwin" ]; then
  echo ">>> Installing WireGuard config..."

  # Use chezmoi to execute the template and install it
  chezmoi execute-template </home/fastctl/fun/homelab/chezmoi/private_etc_wireguard_gw0.conf.tmpl |
    sudo tee /etc/wireguard/gw0.conf >/dev/null

  sudo chmod 600 /etc/wireguard/gw0.conf
  sudo chown root:root /etc/wireguard/gw0.conf

  echo ">>> Wireguard config installed at /etc/wireguard/gw0.conf"
  echo ">>> Enable with: sudo wg-quick up gw0"
fi
