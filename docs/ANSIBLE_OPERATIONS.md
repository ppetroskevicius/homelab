# Ansible Setup for Home Lab

This directory contains Ansible playbooks and roles for managing the home lab infrastructure.

## Prerequisites

1. **Ansible Installation**: On your Ansible control node:

   ```bash
   sudo apt update && sudo apt install ansible

   # brew install ansible

   ansible --version
   ```

2. **SSH Access**: You must have SSH access to the target hosts. For `bm-hypervisor-04`:

   - Ensure SSH is configured and accessible
   - Your SSH key should be authorized on the target host, or you'll need to provide credentials
   - Test connectivity: `ssh <user>@192.168.10.194`

3. **Sudo Access**: The playbooks use `become: true`, so your SSH user must have sudo privileges on the target host.

## Quick Start: Update and Upgrade `bm-hypervisor-04`

To run apt update and upgrade on `bm-hypervisor-04`:

```bash
cd /home/fastctl/fun/homelab/ansible
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-04 -b --ask-become-pass
```

This will:

- Update the apt cache
- Upgrade all packages to the latest distribution versions
- Install basic utilities (vim, tmux, git, htop)

### Run Only the Common Role (Update/Upgrade)

If you want to run only the update/upgrade tasks without other roles:

```bash
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-04 --tags common
```

Note: This requires tags to be added to the role. Alternatively, you can use an ad-hoc command:

```bash
# With sudo password prompt
ansible bm-hypervisor-04 -i inventory.yaml -m apt -a "update_cache=yes upgrade=dist" -b --ask-become-pass

# If passwordless sudo is configured, you can omit --ask-become-pass
ansible bm-hypervisor-04 -i inventory.yaml -m apt -a "update_cache=yes upgrade=dist" -b
```

## Inventory Structure

> **See also:** [`INVENTORY.md`](INVENTORY.md) for detailed inventory structure and machine type mappings.

The `inventory.yaml` file organizes hosts into groups:

- **`bm_hypervisor`**: Bare metal hypervisor hosts (KVM hosts)
- **`vm_k8s_node`**: Kubernetes VM nodes (k3s master/worker nodes)
- **`vm_dev_container`**: Development container VM hosts
- **`vm_service`**: Service-specific VMs (standalone services)
- **`dt_dev`**: Development desktops (physical desktops)

Each host can be referenced by its hostname (e.g., `bm-hypervisor-04`) or by group name (e.g., `bm_hypervisor`).

### Current Host Configuration

- **`bm-hypervisor-04`** (aka `mini`): `192.168.10.194`

## Running Playbooks

### Run on a Specific Host

```bash
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-04 -b --ask-become-pass
```

### Run on a Group

```bash
ansible-playbook -i inventory.yaml site.yml --limit bm_hypervisor
```

### Run on All Hosts

```bash
ansible-playbook -i inventory.yaml site.yml
```

### Dry Run (Check Mode)

Test what would change without making actual changes:

```bash
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-04 --check
```

### Verbose Output

For debugging, use verbose output:

```bash
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-04 -v
# -v: basic, -vv: more, -vvv: even more, -vvvv: connection debugging
```

## Playbook Structure

- **`site.yml`**: Main playbook that orchestrates all roles
- **`roles/common/`**: Base configuration (updates, basic utilities) - runs on all hosts
- **`roles/hypervisor/`**: KVM/libvirt configuration - runs on `bm_hypervisor` group
- **`roles/storage/`**: ZFS/RAID/NFS configuration - runs on `bm_hypervisor` group
- **`roles/container/`**: Docker/K3s configuration - runs on container hosts
- **`roles/dotfiles/`**: Dotfiles management via chezmoi - runs on all hosts
- **`roles/desktop/`**: Desktop environment setup - runs on `dt_dev` group
- **`roles/dev_languages/`**: Development language tools - runs on `dt_dev` group

## Troubleshooting

### Host Key Checking

**Problem**: `The authenticity of host '192.168.10.194' can't be established`

**Solutions**:

- Manually accept the host key: `ssh <user>@192.168.10.194` and type "yes"
- Or disable host key checking (not recommended for production):
  - Create/edit `ansible.cfg`:
    ```ini
    [defaults]
    host_key_checking = False
    ```

## Next Steps

### 1. Install Required Collections

Create `requirements.yml`:

```yaml
---
collections:
  - name: community.general
    version: ">=7.0.0"
```

Install collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

### 2. Current Roles

The main playbook currently uses these roles:

- `common` - Package cache refresh, base utilities, timezone, snap removal
- `credentials` - 1Password CLI on desktops, SSH directory setup
- `dotfiles` - Chezmoi bootstrap on desktops, minimal dotfile copy on servers/VMs
- `hypervisor` - KVM/libvirt and bridge setup
- `storage` - ZFS, NFS exports/mounts, local storage mounts
- `gpu_passthrough` - IOMMU and VFIO setup on enabled hypervisors
- `container` - Docker and K3s
- `desktop` - Sway, desktop apps, audio, fonts, rclone sync
- `dev_languages` - Rust, Python tooling, mise, Go, Java/Kotlin, Deno
- `cloud_tools` - AWS/GCP CLIs, Terraform, GitHub CLI, Playwright/Firebase utilities

### 3. Set Up SSH Keys

For passwordless authentication (recommended):

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "ansible-control"

# Copy key to target host
ssh-copy-id <user>@192.168.10.194
```
