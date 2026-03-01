# Fingerprint Scanner Setup Documentation

## Hardware

- **Device**: Synaptics Fingerprint Scanner
- **USB ID**: `06cb:00f9`
- **Machine**: ThinkPad P14s Gen 5 AMD
- **OS**: Ubuntu Server 24.04 (minimized) with Sway

## Packages Installed

```bash
sudo apt install fprintd libpam-fprintd lxpolkit
```

| Package | Version | Purpose |
|---------|---------|---------|
| `fprintd` | 1.94.3-1 | D-Bus daemon for fingerprint reader access |
| `libpam-fprintd` | 1.94.3-1 | PAM module for fingerprint authentication |
| `lxpolkit` | 0.5.5-4 | Lightweight polkit authentication agent (works with Sway) |

**Note**: We use `lxpolkit` instead of `policykit-1-gnome` because polkit-gnome crashes on minimal Ubuntu Server without full GNOME infrastructure.

## Packages Removed

```bash
sudo apt remove --purge gnome-keyring libpam-gnome-keyring gnome-keyring-pkcs11
rm -rf ~/.local/share/keyrings/
```

| Package | Reason for Removal |
|---------|-------------------|
| `gnome-keyring` | Not needed - using 1Password for secrets |
| `libpam-gnome-keyring` | Dependency of gnome-keyring |
| `gnome-keyring-pkcs11` | Dependency of gnome-keyring |

## Services

### Started/Enabled

| Service | Type | Command |
|---------|------|---------|
| `fprintd.service` | System | Auto-started on demand by D-Bus |
| `lxpolkit.service` | User | `systemctl --user enable --now lxpolkit.service` |

### Stopped/Disabled

| Service | Type | Command |
|---------|------|---------|
| `gnome-keyring-daemon.service` | User | Removed with package |
| `polkit-gnome-agent.service` | User | Replaced by lxpolkit |

## Configuration Files

### Created

| File | Purpose |
|------|---------|
| `~/.config/systemd/user/lxpolkit.service` | Systemd user service for lxpolkit auth agent (auto-restarts) |
| `/etc/pam.d/polkit-1` | Symlink to `/usr/lib/pam.d/polkit-1` (required for polkit PAM auth) |
| `/etc/polkit-1/rules.d/50-fprint-enroll.rules` | Allow sudo group to enroll fingerprints with password auth |

### Modified

| File | Change |
|------|--------|
| `~/.config/sway/config` | Removed `exec` lines for polkit-gnome and gnome-keyring |
| `/etc/pam.d/common-auth` | Added fprintd via `pam-auth-update --enable fprintd` |

## File Contents

### ~/.config/systemd/user/lxpolkit.service

```ini
[Unit]
Description=LXPolkit Authentication Agent
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/lxpolkit
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
```

### /etc/polkit-1/rules.d/50-fprint-enroll.rules

```javascript
polkit.addRule(function(action, subject) {
    if (action.id == "net.reactivated.fprint.device.enroll" &&
        subject.isInGroup("sudo")) {
        return polkit.Result.AUTH_SELF_KEEP;
    }
});
```

**Note**: Uses `AUTH_SELF_KEEP` which requires your password (cached for ~5 minutes). This is more secure than `YES` (no auth required).

### /etc/pam.d/polkit-1

This is a symlink to `/usr/lib/pam.d/polkit-1`:

```bash
sudo ln -s /usr/lib/pam.d/polkit-1 /etc/pam.d/polkit-1
```

Required because some PAM configurations only check `/etc/pam.d/` and don't fall back to `/usr/lib/pam.d/`.

## Fingerprint Enrollment

```bash
# Enroll fingers (run as your user, not root)
fprintd-enroll                        # right-index-finger (default)
fprintd-enroll -f left-index-finger
fprintd-enroll -f right-middle-finger

# List enrolled fingers
fprintd-list $USER

# Test verification
fprintd-verify

# Delete all fingerprints (if needed)
fprintd-delete $USER
```

## Usage

| Application | How to Use Fingerprint |
|-------------|----------------------|
| `sudo` | Touch sensor when "Place your finger" prompt appears |
| `swaylock` | Press Enter, then touch sensor within 10 seconds |
| `1Password` | Click fingerprint icon (or Enter), then enter password in lxpolkit popup |
| `fprintd-enroll` | Enter password in lxpolkit popup when prompted |

## Troubleshooting

### USB Device Stalled

If fingerprint stops working with error "endpoint stalled or request not supported" or "No devices available":

```bash
# Reset USB device
sudo usbreset "06cb:00f9"

# Verify device is working
fprintd-list $USER
```

### Device Already In Use

```bash
# Kill stuck fprintd process
sudo pkill -9 fprintd

# Restart service
sudo systemctl start fprintd.service
```

### Polkit Popup Not Appearing

```bash
# Check if lxpolkit is running
pgrep -la lxpolkit

# Restart lxpolkit
systemctl --user restart lxpolkit.service

# Check status
systemctl --user status lxpolkit.service
```

### Permission Denied When Enrolling

If you get `PermissionDenied: Not Authorized`:

1. Verify lxpolkit is running: `pgrep lxpolkit`
2. Check polkit PAM config exists: `ls -la /etc/pam.d/polkit-1`
3. If missing, create symlink: `sudo ln -s /usr/lib/pam.d/polkit-1 /etc/pam.d/polkit-1`

### Check Logs

```bash
# fprintd service logs
journalctl -u fprintd.service --since "10 minutes ago"

# lxpolkit agent logs
journalctl --user -u lxpolkit.service

# System polkit logs
journalctl -u polkit --since "10 minutes ago"
```

### Verify PAM Configuration

```bash
# Check fprintd is in PAM
grep fprintd /etc/pam.d/common-auth

# Expected output:
# auth [success=2 default=ignore] pam_fprintd.so max-tries=1 timeout=10
```

### Re-enroll Fingerprints

```bash
# Delete existing fingerprints
fprintd-delete $USER

# Re-enroll
fprintd-enroll
fprintd-enroll -f left-index-finger
fprintd-enroll -f right-middle-finger
```

## Why lxpolkit Instead of polkit-gnome?

`policykit-1-gnome` (polkit-gnome) crashes on minimal Ubuntu Server with Sway because:

1. It expects GNOME Session Manager (`org.gnome.SessionManager`)
2. It has unhandled null pointer errors without GNOME infrastructure
3. Results in segmentation faults during PAM authentication

`lxpolkit` is a lightweight alternative that:
- Has no GNOME dependencies
- Works reliably with Sway/Wayland
- Provides the same password prompt functionality

## References

- [fprintd Supported Devices](https://fprint.freedesktop.org/supported-devices.html)
- [1Password System Authentication on Linux](https://support.1password.com/system-authentication-linux/)
- [Ubuntu Fingerprint ThinkPad Guide](https://ubuntuhandbook.org/index.php/2024/02/fingerprint-reader-t480s/)
