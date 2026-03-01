#!/usr/bin/env bash
set -euo pipefail

# Clone TPM (Tmux Plugin Manager) if not already present
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
	echo ">>> Installing TPM (Tmux Plugin Manager)..."
	git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
	"$TPM_DIR/bin/install_plugins" || true
fi
