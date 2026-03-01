# Chezmoi Deployment Strategy

This document explains how dotfiles are deployed across different machine types.

## Overview

| Machine Type | Method | Dotfiles | Secrets |
|--------------|--------|----------|---------|
| **Desktop** (`dt-*`) | Chezmoi | Full (shell, GUI, dev tools) | 1Password desktop (biometric) |
| **Non-Desktop** (`bm-*`, `vm-*`) | Ansible copy | Minimal (bash, vim, tmux, git) | None (agent forwarding) |

## Repository Structure

```
homelab/                          # Monorepo root
├── .chezmoiroot                  # Contains "chezmoi" - tells chezmoi to use subdirectory
├── chezmoi/                      # Dotfiles source (single source of truth)
│   ├── .chezmoiignore            # Filters files by hostname
│   ├── dot_bashrc                # Static files (used by both methods)
│   ├── dot_vimrc
│   ├── dot_config/
│   │   ├── sway/config.tmpl      # Desktop-only (filtered by .chezmoiignore)
│   │   └── ...
│   └── ...
├── ansible/
│   └── roles/dotfiles/
│       ├── tasks/main.yml        # Copies from chezmoi/ for non-desktops
│       └── templates/
│           └── ssh_config.j2     # SSH config without 1Password agent
└── terraform/
```

## Desktop Machines (`dt-*`)

Desktops use **chezmoi** for full dotfile management with 1Password integration.

### Ansible Bootstrap

Ansible prepares the desktop with a working Sway environment:

```yaml
# What Ansible does:
1. Install GPU drivers, fonts
2. Build desktop tools (alacritty, kickoff, i3status-rs) via cargo
3. Deploy bootstrap Sway config (minimal, functional)
4. Install Sway/Wayland packages
5. Install zsh, Oh My Zsh, plugins
6. Download chezmoi binary
7. Clone homelab monorepo to ~/fun/homelab
8. Run: chezmoi init --source ~/fun/homelab  # NO --apply
```

The **bootstrap Sway config** provides:
- Terminal access (`Mod+Return` → alacritty)
- App launcher (`Mod+d` → kickoff)
- Basic window management keybinds

This solves the chicken-and-egg problem: user can launch Sway, open terminal, set up 1Password.

### Manual Apply (User Action Required)

After Ansible runs, the user must:

```bash
# 1. Log in to Sway (bootstrap config is active)
# 2. Open terminal (Mod+Return)
# 3. Install and sign into 1Password desktop app
# 4. Apply full dotfiles
chezmoi apply
# 5. Reload Sway config (Mod+Shift+c) to get full config
```

This is required because chezmoi templates use 1Password for secrets (rclone, wireguard, etc.).

### Bootstrap vs Full Config

| Aspect | Bootstrap (Ansible) | Full (Chezmoi) |
|--------|---------------------|----------------|
| Terminal | alacritty | alacritty |
| Launcher | kickoff | kickoff |
| Status bar | Basic (no i3status-rs) | i3status-rs |
| Monitor layout | Generic | Host-specific |
| Autostart apps | None | Firefox, htop |
| 1Password | Not required | Required |

### Chezmoi Configuration

Located at `~/.config/chezmoi/chezmoi.toml`:

```toml
sourceDir = "/home/fastctl/fun/homelab"

[onepassword]
    mode = "account"   # Uses 1Password desktop app (biometric)
    prompt = true
```

### Update Workflow

```bash
cd ~/fun/homelab && git pull && chezmoi apply
```

## Non-Desktop Machines (`bm-*`, `vm-*`)

Non-desktops use **Ansible** to copy minimal dotfiles directly. No chezmoi installed.

### Why No Chezmoi?

1. **Simpler** - No extra tooling on servers
2. **Cattle mindset** - Servers get identical, static configs
3. **No secrets needed** - Uses SSH agent forwarding from desktop
4. **No 1Password** - Servers don't have 1Password installed

### What Gets Deployed

Ansible copies these files from the chezmoi source directory:

| Source (chezmoi/) | Destination | Purpose |
|-------------------|-------------|---------|
| `dot_bash_profile` | `~/.bash_profile` | Shell startup |
| `dot_bashrc` | `~/.bashrc` | Shell config |
| `dot_vimrc` | `~/.vimrc` | Vim config |
| `dot_tmux.conf` | `~/.tmux.conf` | Tmux config |
| `dot_editorconfig` | `~/.editorconfig` | Editor formatting |
| `private_dot_gitconfig` | `~/.gitconfig` | Git SSH enforcement |
| `dot_config/shell/common.sh` | `~/.config/shell/common.sh` | Common shell functions |
| *(Ansible template)* | `~/.ssh/config` | SSH hosts (no 1Password agent) |

### Single Source of Truth

The chezmoi directory is the source of truth for both:
- **Desktops**: Chezmoi applies files directly
- **Non-desktops**: Ansible copies files from chezmoi directory

This ensures consistency - edit once in `chezmoi/`, changes apply to all machines.

## File Filtering (.chezmoiignore)

The `.chezmoiignore` file prevents desktop-only files from being applied on non-desktops:

```go-template
{{- if not (hasPrefix "dt-" .chezmoi.hostname) }}
# These are ignored on non-desktop machines:

# Zsh (servers use bash)
dot_zshrc
dot_zprofile

# GUI configs
dot_config/sway/
dot_config/alacritty/
dot_config/starship.toml.tmpl

# 1Password integration
dot_config/1Password/
dot_config/rclone/
dot_aws/

# Audio
dot_config/pipewire/
dot_config/wireplumber/

# Desktop-specific
dot_config/Cursor/
dot_config/systemd/
dot_config/chezmoi/
...
{{- end }}
```

## Secrets Handling

| Machine Type | SSH Keys | 1Password | API Keys |
|--------------|----------|-----------|----------|
| Desktop | Private key via 1Password | Desktop app (biometric) | direnv + 1Password |
| Non-Desktop | None (agent forwarding) | Not installed | None needed |

See [SECRETS.md](SECRETS.md) for the full secrets management strategy.

## Comparison Summary

| Aspect | Desktop (`dt-*`) | Non-Desktop (`bm-*`, `vm-*`) |
|--------|------------------|------------------------------|
| **Dotfile tool** | Chezmoi | Ansible copy |
| **Repo location** | `~/fun/homelab` | N/A (files copied directly) |
| **Shell** | Zsh + Oh My Zsh | Bash |
| **1Password** | Desktop app (biometric) | Not installed |
| **SSH keys** | Private key stored | Agent forwarding only |
| **Secrets access** | Full (templates use 1Password) | None needed |
| **Update method** | `git pull && chezmoi apply` | Re-run Ansible |

## Troubleshooting

### Desktop: 1Password Errors

If `chezmoi apply` fails with 1Password errors:

```bash
# Check 1Password is signed in
op whoami

# Verify chezmoi config
chezmoi data | grep onepassword

# Dry run to see what would change
chezmoi apply --dry-run --verbose
```

### Non-Desktop: Update Dotfiles

Re-run Ansible to update dotfiles:

```bash
# From control node (desktop)
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-01 --tags dotfiles
```

### Check What Chezmoi Would Apply

```bash
# On desktop - see filtered files for current hostname
chezmoi managed

# See what's ignored
chezmoi ignored
```
