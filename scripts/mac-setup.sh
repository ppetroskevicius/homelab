#!/usr/bin/env bash
set -euo pipefail

# Minimal bootstrap for a new Mac before Ansible takes over.
# Installs Homebrew (if missing), Ansible, clones the repo, then hands off.

REPO_URL="git@github.com:ppetroskevicius/homelab.git"
REPO_DIR="$HOME/fun/homelab"

# 1. Install Homebrew if not present
if ! command -v brew &>/dev/null; then
  echo "=== Installing Homebrew ==="
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 2. Install Ansible
echo "=== Installing Ansible ==="
brew install ansible ansible-lint

# 3. Clone repo
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "=== Cloning homelab repo ==="
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo ""
echo "Bootstrap complete. Next steps:"
echo "  cd $REPO_DIR/ansible"
echo "  ansible-playbook -i inventory.yaml site.yml --limit work-mac"
