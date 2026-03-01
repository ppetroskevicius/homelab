#!/usr/bin/env bash
set -euo pipefail

# Clone Alacritty themes if not already present
if [ ! -d "$HOME/.config/alacritty/themes" ]; then
	echo ">>> Cloning Alacritty themes..."
	mkdir -p "$HOME/.config/alacritty"
	git clone https://github.com/alacritty/alacritty-theme "$HOME/.config/alacritty/themes"
fi
