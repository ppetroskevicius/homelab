#!/bin/bash

# Install TLP configuration
# This script creates a symbolic link from the managed .tlp.conf to /etc/tlp.conf
# Requires sudo privileges

set -euo pipefail

# Check if TLP is installed
if ! command -v tlp &> /dev/null; then
    echo "TLP is not installed. Please install tlp package first."
    exit 1
fi

# Check if tlp.conf exists in ~/.config/tlp/ (managed by chezmoi)
if [ ! -f "$HOME/.config/tlp/tlp.conf" ]; then
    echo "Error: $HOME/.config/tlp/tlp.conf not found"
    exit 1
fi

# Create symbolic link to /etc/tlp.conf
echo "Installing TLP configuration..."
sudo ln -sf "$HOME/.config/tlp/tlp.conf" /etc/tlp.conf

# Restart TLP service if it's running
if systemctl is-active --quiet tlp.service; then
    echo "Restarting TLP service..."
    sudo systemctl restart tlp.service
else
    echo "Starting TLP service..."
    sudo systemctl start tlp.service
    sudo systemctl enable tlp.service
fi

echo "TLP configuration installed successfully"