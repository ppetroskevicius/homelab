#!/usr/bin/env bash
set -euo pipefail

# Fingerprint scanner setup - only for desktop machines (dt-*)
HOSTNAME=$(hostname)
if [[ ! "$HOSTNAME" =~ ^dt- ]]; then
  echo ">>> Skipping fingerprint setup on non-desktop machine: $HOSTNAME"
  exit 0
fi

echo ">>> Setting up fingerprint scanner..."

# Create /etc/pam.d/polkit-1 symlink if missing
# This is required for polkit to authenticate via PAM
POLKIT_PAM="/etc/pam.d/polkit-1"
if [ ! -e "$POLKIT_PAM" ]; then
  echo ">>> Creating polkit PAM symlink..."
  sudo ln -s /usr/lib/pam.d/polkit-1 "$POLKIT_PAM"
  echo ">>> Polkit PAM symlink created"
else
  echo ">>> Polkit PAM config already exists"
fi

# Install polkit rules for fingerprint enrollment (AUTH_SELF_KEEP)
POLKIT_RULES="/etc/polkit-1/rules.d/50-fprint-enroll.rules"
EXPECTED_RULE='polkit.Result.AUTH_SELF_KEEP'
if [ ! -f "$POLKIT_RULES" ] || ! grep -q "$EXPECTED_RULE" "$POLKIT_RULES" 2>/dev/null; then
  echo ">>> Installing polkit rules for fingerprint enrollment..."
  sudo tee "$POLKIT_RULES" > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "net.reactivated.fprint.device.enroll" &&
        subject.isInGroup("sudo")) {
        return polkit.Result.AUTH_SELF_KEEP;
    }
});
EOF
  sudo chmod 644 "$POLKIT_RULES"
  sudo systemctl restart polkit
  echo ">>> Polkit rules installed"
else
  echo ">>> Polkit rules already configured"
fi

# Disable old polkit-gnome-agent if it exists
if systemctl --user is-enabled polkit-gnome-agent.service &>/dev/null; then
  echo ">>> Disabling old polkit-gnome-agent.service..."
  systemctl --user disable polkit-gnome-agent.service
  systemctl --user stop polkit-gnome-agent.service 2>/dev/null || true
fi

# Enable lxpolkit user service
if systemctl --user is-enabled lxpolkit.service &>/dev/null; then
  echo ">>> lxpolkit.service already enabled"
else
  echo ">>> Enabling lxpolkit.service..."
  systemctl --user daemon-reload
  systemctl --user enable lxpolkit.service
fi

# Start if not running
if ! systemctl --user is-active lxpolkit.service &>/dev/null; then
  echo ">>> Starting lxpolkit.service..."
  systemctl --user start lxpolkit.service
fi

# Check if fprintd is installed
if ! command -v fprintd-list &>/dev/null; then
  echo ""
  echo ">>> Warning: fprintd not installed. Install with:"
  echo ">>>   sudo apt install fprintd libpam-fprintd lxpolkit"
  echo ">>>   sudo pam-auth-update --enable fprintd"
  exit 0
fi

# Check if fingerprints are enrolled
if fprintd-list "$USER" 2>/dev/null | grep -q "has no fingers enrolled"; then
  echo ""
  echo ">>> Warning: No fingerprints enrolled. Enroll with:"
  echo ">>>   fprintd-enroll"
  echo ">>>   fprintd-enroll -f left-index-finger"
  echo ">>>   fprintd-enroll -f right-middle-finger"
fi

echo ">>> Fingerprint setup complete"
