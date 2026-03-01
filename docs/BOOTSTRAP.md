# Bootstrapping Desktop Machines

Desktop machines (`dt-*`) require a two-phase setup because 1Password must be authenticated interactively before chezmoi can access secrets.

## The Challenge

1. **SSH Config Deadlock**: Desktop SSH configs point to 1Password agent (`~/.1password/agent.sock`)
2. **Git Config Deadlock**: Desktop gitconfig rewrites HTTPS→SSH
3. **1Password Requires GUI**: Can't authenticate 1Password without a working desktop session

## The Solution: Two-Phase Bootstrap

### Phase 1: Ansible Provisioning (Automated)

Run from the control node (which has working GitHub SSH access):

```bash
ansible-playbook -i inventory.yaml site.yml --limit dt-dev-02
```

Ansible will:
1. Install 1Password CLI and desktop app
2. Clone homelab repo via SSH (using agent forwarding from control node)
3. Install Sway with bootstrap config (uses `foot` terminal and `wofi` launcher)
4. Initialize chezmoi (but NOT apply it)

**Key Technical Details:**

The git clone bypasses the target machine's SSH config (which points to 1Password) by using:
```yaml
environment:
  GIT_SSH_COMMAND: "ssh -o IdentityAgent=$SSH_AUTH_SOCK ..."
```

This forces git to use the forwarded SSH agent from the control node instead of the non-functional 1Password agent.

### Phase 2: User Personalization (Manual)

After Ansible completes:

1. **Reboot** into the bootstrap Sway session
2. **Open terminal**: `Mod4+Return` (opens `foot`)
3. **Launch 1Password**: `Mod4+d` → search for "1Password"
4. **Sign in** to 1Password desktop app (enables biometric/system integration)
5. **Apply dotfiles**:
   ```bash
   chezmoi apply
   ```

This replaces the bootstrap config with your full configuration (alacritty, kickoff, i3status-rs, etc.).

## Bootstrap vs Full Configuration

| Component | Bootstrap (Phase 1) | Full (After chezmoi apply) |
|-----------|---------------------|---------------------------|
| Terminal | `foot` (apt) | `alacritty` (cargo) |
| Launcher | `wofi` (apt) | `kickoff` (cargo) |
| Status bar | Basic sway bar | `i3status-rs` (cargo) |
| Secrets | None | 1Password integration |

## Troubleshooting

### Git clone fails with "Permission denied (publickey)"

**Cause**: The target machine's `~/.ssh/config` has `IdentityAgent ~/.1password/agent.sock`, which doesn't work yet.

**Solution**: Already handled in Ansible via `GIT_SSH_COMMAND` environment variable that forces use of the forwarded agent.

### Can't open terminal in bootstrap Sway

**Cause**: Bootstrap config was deployed before `foot` was installed.

**Solution**: Re-run Ansible - sway_wayland now installs packages before deploying config.

### chezmoi apply fails with 1Password errors

**Cause**: 1Password desktop app not signed in.

**Solution**:
1. Launch 1Password GUI via wofi (`Mod4+d`)
2. Sign in with your account
3. Retry `chezmoi apply`

### Want to skip cargo builds for faster testing

Run only the bootstrap-critical tasks:
```bash
ansible-playbook -i inventory.yaml site.yml --limit dt-dev-02 --skip-tags cargo_builds
```

(Note: This tag would need to be added to desktop_tools.yml if desired)

## Reprovisioning a Desktop (Fresh Start)

If a desktop has remnants from previous chezmoi/ansible runs and you want to start fresh:

### Step 1: Clean up stale files on the target machine

SSH into the target and remove problematic configs:

```bash
ssh dt-dev-02

# Remove chezmoi-applied SSH config (keeps authorized_keys intact)
rm -f ~/.ssh/config

# Remove gitconfig with SSH enforcement
rm -f ~/.gitconfig

# Remove chezmoi state (will re-initialize)
rm -rf ~/.config/chezmoi

# Remove existing repo clone (will re-clone)
rm -rf ~/fun/homelab
```

### Step 2: Re-run Ansible

```bash
ansible-playbook -i inventory.yaml site.yml --limit dt-dev-02
```

### What gets cleaned up

| File/Directory | Why it causes issues |
|----------------|---------------------|
| `~/.ssh/config` | Contains `IdentityAgent ~/.1password/agent.sock` which breaks SSH before 1Password is set up |
| `~/.gitconfig` | Rewrites HTTPS→SSH which breaks clone before SSH works |
| `~/.config/chezmoi/` | Stale chezmoi state may prevent proper re-initialization |
| `~/fun/homelab` | May be in inconsistent state from failed previous runs |

**Note**: Ansible includes a pre-flight check that warns if stale 1Password SSH config is detected. The clone will still work due to `GIT_SSH_COMMAND` override, but cleaning up is recommended.

## Architecture Diagram

```
Control Node (dt-dev-01)           Target (dt-dev-02)
┌─────────────────────┐            ┌─────────────────────┐
│ 1Password ✓         │            │ 1Password ✗         │
│ SSH Agent ✓         │───SSH+────▶│ SSH Agent (fwd) ✓   │
│ GitHub Access ✓     │  Agent     │ GitHub Access ✓     │
└─────────────────────┘  Forward   └─────────────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  GitHub     │
                    │  (clone)    │
                    └─────────────┘
```
