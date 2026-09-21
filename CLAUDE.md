# Project Context & Rules

## 1. Project Mission

Migrate a high-performance home lab from legacy bash scripts to a modern Infrastructure-as-Code (IaC) stack using **Ansible**, **Terraform**, and **Chezmoi**.

---

## 2. Core Architecture

### **Terraform (`./terraform`)**

- **Provider:** `dmacvicar/libvirt`.
- **Image Strategy:** Do NOT build custom ISOs. Use **Cloud-Init**.
  - Download generic `Ubuntu 24.04 Cloud Image` (.qcow2) to the KVM host.
  - Use Terraform `libvirt_cloudinit_disk` to inject SSH keys, hostname, and default user (`fastctl`).
- **Networking:** Manage KVM bridges (e.g., `br0`) if not present, but prefer utilizing existing system bridges defined by Netplan.

### **Ansible (`./ansible`)**

- **Become Password:** Retrieved from 1Password desktop app via `community.general.onepassword` lookup:
  - Item: `env-vars`, Field: `ansible-become-password`, Vault: `build`
  - Requires 1Password desktop app signed in (biometric unlock)
- **Module Preference:** **Strictly prefer Ansible Modules over Shell Commands.**
  - BAD: `command: zpool create ...`
  - GOOD: `community.general.zfs: name=ssdpool state=present ...`
  - BAD: `shell: echo "export..." >> /etc/exports`
  - GOOD: `ansible.builtin.template` or `lineinfile` for `/etc/exports`.
- **Privilege:** Use `become: true` for system-level changes.

### **Storage Strategy**

- **Source of Truth:** See [`docs/STORAGE.md`](docs/STORAGE.md).
- **ZFS:** Managed via `community.general.zfs`.
- **NFS:**
  - Server: `bm-hypervisor-01` exports ZFS datasets.
  - Clients: `bm-hypervisor-02/03` mount via `ansible.posix.mount` (persistent `fstab`).

---

## 3. Implementation Plan

### **Phase 1: Hypervisor Setup (Ansible)**

Target Group: `bm_hypervisor`

1.  **KVM/Libvirt:** Install `qemu-kvm`, `libvirt-daemon-system`.
    - Ensure `libvirtd` service is enabled and running.
    - Add user to `libvirt` group.
    - Set `LIBVIRT_DEFAULT_URI` globally.
2.  **Storage:**
    - On `bm-hypervisor-01`: Detect and create ZFS pools defined in [`docs/STORAGE.md`](docs/STORAGE.md).
    - Configure NFS Server exports.
3.  **Networking:** Ensure Bridge interfaces exist for VMs to attach to.

### **Phase 2: VM Provisioning (Terraform)**

1.  Read [`docs/TOPOLOGY.md`](docs/TOPOLOGY.md) for VM specs (CPU/RAM).
2.  Connect to KVM hosts via SSH.
3.  Provision VMs using `ubuntu-24.04-server-cloudimg-amd64.img`.
4.  Inject `cloud-init` config (User: `fastctl`, SSH Key: from 1Password/Local).

### **Phase 3: VM Configuration (Ansible)**

Target Group: `vm_k8s_node`, `vm_service`

1.  Install Docker/Containerd/K3s.
2.  Apply Dotfiles:
    - **Non-desktops** (`bm-*`, `vm-*`): Ansible copies minimal dotfiles (bash, vim, tmux, git)
    - **Desktops** (`dt-*`): Chezmoi with 1Password (user runs `chezmoi apply` after 1Password setup)
    - See [`docs/CHEZMOI.md`](docs/CHEZMOI.md) for details.

---

## 4. Hardware Specifics

- **bm-hypervisor-01:** Storage Server. Needs `zfsutils-linux`, `nfs-kernel-server`.
- **bm-hypervisor-03:** ML Compute. Needs `amdgpu-dkms`, `rocm`.
- **bm-hypervisor-04:** Sandbox. Low specs. Do not deploy heavy ZFS/K8s loads here.

## 5. Development Workflow

1.  **Sandbox Test:**
    ```bash
    ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-04
    ```
2.  **Linting:**
    - Run `ansible-lint` before committing.
    - Run `terraform fmt` on infrastructure code.

---

## 6. Public Repo: No Work-Specific Content

This repo is **public**. Before anything leaves this machine (`git push`, merge to `main`, PR), check that
nothing work-specific is in the code, comments, docs, config, or commit messages being published:

- Employer/company names, work product or internal project names, internal hostnames/URLs/repo names,
  customer or coworker names.
- Credentials of any kind (API tokens, keys, private-key blocks, JWTs).
- Claude/agent config from `~/.claude` (deliberately not tracked; ask before adding anything under
  `chezmoi/dot_claude/`).

How to check:

- Scan the **added lines of the whole range being pushed** (`git diff <remote-tip>..<local-tip>`), not just
  `HEAD` — pushing publishes every commit in the range, and history is hard to retract.
- The concrete list of names to scan for is kept in private Claude memory, not in this file (writing them
  here would itself leak them).
- If something work-specific turns up, stop and ask before pushing; rewrite or drop the commit rather than
  pushing a follow-up fix.

---

## 7. Related Documentation

For detailed information on specific aspects of the homelab:

- **[docs/TOPOLOGY.md](docs/TOPOLOGY.md)** - Infrastructure topology, physical hosts, and VM specifications
- **[docs/NETWORK.md](docs/NETWORK.md)** - Network architecture, IP allocation, and Netplan configuration
- **[docs/STORAGE.md](docs/STORAGE.md)** - ZFS pools, NFS exports, and storage configuration
- **[docs/INVENTORY.md](docs/INVENTORY.md)** - Ansible inventory structure and machine type mappings
- **[docs/ANSIBLE_OPERATIONS.md](docs/ANSIBLE_OPERATIONS.md)** - Ansible playbook usage and operations guide
- **[docs/SECRETS.md](docs/SECRETS.md)** - Secrets management strategy
- **[docs/SHELL_STRATEGY.md](docs/SHELL_STRATEGY.md)** - Shell startup scripts management
- **[docs/LEGACY_REFERENCE.md](docs/LEGACY_REFERENCE.md)** - Legacy bash scripts documentation (migration reference)
- **[docs/CHEZMOI.md](docs/CHEZMOI.md)** - Dotfiles deployment strategy (desktop vs non-desktop)
- **[docs/ALACRITTY.md](docs/ALACRITTY.md)** - Terminal: source build (Homebrew cask disabled), pinning & upgrade
- **[docs/CHEZMOI_CHEAT_SHEET.md](docs/CHEZMOI_CHEAT_SHEET.md)** - Chezmoi quick reference
- **[ROADMAP.md](ROADMAP.md)** - Implementation roadmap and migration phases
