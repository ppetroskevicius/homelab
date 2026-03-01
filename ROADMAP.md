# Implementation Roadmap

> **Project Context:** See [`CLAUDE.md`](CLAUDE.md) for project mission, architecture, and development workflow.

## Migration Strategy (Legacy → Ansible)

We are migrating logic from `legacy_scripts/` (documented in `docs/LEGACY_REFERENCE.md`) into Ansible Roles.

| New Ansible Role    | Source Legacy Scripts                  | Description                                               |
| :------------------ | :------------------------------------- | :-------------------------------------------------------- |
| **`common`**        | `01_update`, `05_system`, `14_cleanup` | Updates, Timezone, Basic Utils (vim, git, htop), Cleanup. |
| **`credentials`**   | `02_credentials`                       | 1Password CLI, SSH directory setup.                       |
| **`dotfiles`**      | `03_shell`, `04_dotfiles`              | Zsh, Oh-My-Zsh, Chezmoi init & apply.                     |
| **`hypervisor`**    | `06_hypervisor`                        | KVM, Libvirt, Bridge Utils (Run on `bm_hypervisor`).      |
| **`storage`**       | `07_storage`                           | ZFS Pools, NFS Server/Client (Run on `bm_hypervisor`).    |
| **`container`**     | `08_containers`                        | Docker (for `vm_dev_container`), K3s (for `vm_k8s_node`). |
| **`desktop`**       | `11_desktop`, `12_desktop_apps`        | Sway, Fonts, GUI Apps (Run on `dt_dev`).                  |
| **`dev_languages`** | `09_languages`                         | Python (UV), Rust, Node, Go, Java.                        |
| **`cloud_tools`**   | `10_cloud`                             | AWS/GCP CLIs, Terraform, Ansible.                         |

---

## Phase 1: The "Control Plane" & Foundation (Ansible)

**Goal:** Configure the physical hosts (`bm-hypervisor-*`) so they are ready to run virtualization and storage.

**Status:** ✅ Complete (2026-01)

- [x] **Prerequisites**

  - [x] Install Ansible & Collections (`community.general`, `community.libvirt`) on Control Node.
  - [x] Verify SSH access to all physical hosts.

- [x] **Role: `common`**

  - [x] Port `install_basic_utilities` (vim, tmux, git, htop, btop) from `05_system.sh`.
  - [x] Port `setup_timezone` from `01_update.sh`.
  - [x] Ensure `snap` is removed (if on Linux).

- [x] **Role: `credentials`**

  - [x] Install 1Password CLI.
  - [x] Ensure `OP_SERVICE_ACCOUNT_TOKEN` is usable by the remote session.

- [x] **Role: `dotfiles`**

  - [x] Port `install_zsh` logic from `03_shell.sh`.
  - [x] Install `chezmoi`.
  - [x] Run `chezmoi init --apply` (ensure idempotency).

- [x] **Role: `storage`** (Refer to [`docs/STORAGE.md`](docs/STORAGE.md))

  - [x] **ZFS (bm-hypervisor-01):** Create `ssdpool`, `hddmirror`, `hddsingle` using `community.general.zfs`.
  - [x] **NFS Server (bm-hypervisor-01):** Export the ZFS datasets.
  - [x] **NFS Client (bm-hypervisor-02/03):** persist mounts in `/etc/fstab` using `ansible.posix.mount`.

- [x] **Role: `hypervisor`**
  - [x] Port `install_kvm` logic from `06_hypervisor.sh`.
  - [x] Ensure `br0` (Bridge) is configured via Netplan if not present.
  - [x] Enable `libvirtd` service.

> **⚠️ Lessons Learned:** Lost access to `bm-hypervisor-02` due to incorrect interface name in the Netplan bridge configuration. Always verify interface names with `ip link` before applying network changes. Consider adding a validation step or `netplan try` (with automatic rollback) for safer deployments.

---

## Phase 2: Infrastructure Provisioning (Terraform)

**Goal:** Spin up the virtual machines defined in [`docs/TOPOLOGY.md`](docs/TOPOLOGY.md).

**Status:** ✅ Complete (2026-01)

> **Note:** All hypervisors (`bm-hypervisor-01`, `bm-hypervisor-02`, `bm-hypervisor-03`) are now operational (2026-01-26). VMs can be distributed across hosts as needed.

- [x] **Setup**

  - [x] Create `terraform/` directory structure.
  - [x] Initialize local Terraform state (`terraform.tfstate`).
  - [x] Configure `dmacvicar/libvirt` provider to use SSH transport to `bm-hypervisor-01`.

- [x] **Base Image Strategy**

  - [x] Use `libvirt_volume` to download `Ubuntu 24.04 Cloud Image` (.qcow2) to the host cache.
  - [x] Do **not** build custom ISOs; rely on Cloud-Init.

- [x] **VM Provisioning** (all on `bm-hypervisor-01`)

  - [x] **K8s Nodes:** Provision `vm-k8s-node-[01..03]`.
  - [x] **Dev Containers:** Provision `vm-dev-container-01`.
  - [x] **Services:** Provision `vm-service-01`.

- [x] **Bootstrap (Cloud-Init)**
  - [x] Inject `user-data`: Create `fastctl` user, add SSH public key.
  - [x] Inject `network-config`: Set **Static IPs** (defined in [`docs/TOPOLOGY.md`](docs/TOPOLOGY.md)) to ensure Ansible reachability.

> **⚠️ Known Issues:** The `dmacvicar/libvirt` provider v0.9.x has state tracking bugs with graphics, console, and capacity attributes. These don't affect the actual VM creation - just run `terraform apply` multiple times or use `-refresh=false` if needed.

---

## Phase 3: Service Configuration (Ansible)

**Goal:** Turn generic Ubuntu VMs into K8s nodes and Dev containers.

**Status:** ✅ Complete (2026-01)

- [x] **Inventory Update**

  - [x] Add new VMs to `inventory.yaml` with static IP addresses.

- [x] **Role: `container`**

  - [x] **Docker:** Install on `vm_dev_container` group (Source: `08_containers.sh`).
  - [x] **K3s:** Install on `vm_k8s_node` group (Source: `08_containers.sh`).
    - `vm-k8s-node-01` as control plane (server)
    - `vm-k8s-node-02` and `vm-k8s-node-03` as worker nodes (agents)

- [x] **Role: `dotfiles` (VMs)**
  - [x] Run common roles (credentials, dotfiles) on all new VMs.

> **Verification:**
>
> ```
> kubectl get nodes
> vm-k8s-node-01   Ready    control-plane   v1.34.3+k3s1
> vm-k8s-node-02   Ready    <none>          v1.34.3+k3s1
> vm-k8s-node-03   Ready    <none>          v1.34.3+k3s1
>
> docker --version (on vm-dev-container-01)
> Docker version 29.1.5
> ```

---

## Phase 4: Simplify Secrets Management

**Goal:** Implement least-privilege secrets architecture per [`docs/SECRETS.md`](docs/SECRETS.md). Separate interactive contexts (desktops) from execution contexts (servers/nodes).

**Status:** ✅ Complete (2026-01)

- [x] **SSH Key Strategy: Stop Copying Private Keys**

  - [x] **Desktop (`dt-dev`):** Keep private keys here only, use 1Password SSH Agent with biometrics.
  - [x] **Remotes (`vm-*`, `bm-*`):** Chezmoi configured to not deploy private keys.
  - [x] Keep only public keys in `~/.ssh/authorized_keys` on remotes.
  - [x] Configure `~/.ssh/config` on desktop with `ForwardAgent yes` for lab hosts.
  - [x] Update Chezmoi to not deploy private keys on non-desktop machines.

- [x] **API Key Strategy: Kill Global Exports**

  - [x] Remove the block of 40+ `op read` exports from `.zshrc`/`common.sh`.
  - [x] Configure `direnv` hook in `.zshrc` for just-in-time secrets.

- [x] **Dev Container Strategy**

  - [x] Do NOT put `op` commands in `.zshrc` on `vm-dev-container`.

- [x] **Ansible Control Node Pattern**

  - [x] Designate `dt-dev` as the **only** Ansible Control Node.
  - [x] Do NOT use Ansible Vault (avoid dual secret backends).

- [x] **Service Account Token Usage**

  - [x] Reserve `OP_SERVICE_ACCOUNT_TOKEN` for automated pipelines only (CI/CD, cron jobs).
  - [x] Remove hardcoded service account tokens from shell configs.

- [x] **Update Chezmoi Configuration**

  - [x] Modify `.chezmoiignore` to skip private key deployment on non-desktop machines.
  - [x] Update SSH config templates to enable agent forwarding for lab hosts.
  - [x] Skip 1Password SSH agent config on non-desktop machines.
  - [x] Skip SSH key setup script on non-desktop machines.

> **Implementation Notes:**
> - SSH config uses 1Password agent (`~/.1password/agent.sock`) on desktops only
> - `ForwardAgent yes` enabled globally for all hosts
> - `.chezmoiignore` excludes `private_id_ed25519.tmpl`, `run_ssh_keys.sh`, and `dot_config/1Password/` on non-desktop machines
> - `common.sh` is POSIX-compliant with no 1Password/secrets loading
> - `.zshrc` includes `direnv` hook for project-specific secrets

## Phase 5: Simplify Shell Startup Scripts

**Goal:** Implement "Load Once, Run Everywhere" shell strategy per [`docs/SHELL_STRATEGY.md`](docs/SHELL_STRATEGY.md) and [`docs/SECRETS.md`](docs/SECRETS.md).

**Status:** ✅ Complete (2026-01)

- [x] **Refactor `common.sh` (POSIX Core)**

  - [x] Remove 1Password injection block (`op inject`/`eval` exports).
  - [x] Keep lightweight: `EDITOR`, `CLICOLOR` exports only.
  - [x] Implement idempotent `add_to_path()` function (prevents PATH duplication).
  - [x] Maintain POSIX compliance for Bash/Zsh portability.

- [x] **Decouple Profile from RC Files**

  - [x] **`.zprofile` (Desktop Login):** Source `common.sh`, set `HISTFILE`/`HISTSIZE`.
  - [x] **`.zshrc` (Desktop Interactive):** Oh-My-Zsh, direnv hook, Starship, aliases only.
  - [x] **`.bash_profile` (Server Login):** Source `common.sh`, conditionally source `.bashrc`.
  - [x] **`.bashrc` (Server Interactive):** Minimal - direnv hook, Starship fallback, basic aliases.
  - [x] Stop cross-sourcing between profile and rc files.

- [x] **Shell Strategy by Machine Type**

  - [x] **Desktops (`dt-*`):** Keep Zsh with Oh-My-Zsh, plugins, themes.
  - [x] **Servers/VMs (`bm-*`, `vm-*`):** Use Bash only (no Zsh/Oh-My-Zsh).
  - [x] Update Chezmoi `.chezmoiignore` to skip Zsh configs on non-desktop machines.

- [x] **Install and Configure `direnv`**

  - [x] Install `direnv` via Ansible (`common` role).
  - [x] Add `eval "$(direnv hook zsh)"` to `.zshrc` (desktops).
  - [x] Add `eval "$(direnv hook bash)"` to `.bashrc` (servers, conditional).
  - [x] Remove legacy 1Password exports from shell configs.

- [x] **Update Chezmoi Templates**

  - [x] Refactor `dot_zshrc` per new structure.
  - [x] Refactor `dot_zprofile` per new structure.
  - [x] Create/update `dot_bashrc` for servers.
  - [x] Create/update `dot_bash_profile` for servers.
  - [x] Update `dot_config/shell/common.sh` to POSIX-compliant version.

> **Implementation Notes:**
> - `common.sh` uses `COMMON_SH_LOADED` guard to prevent re-sourcing
> - `add_to_path()` checks `":$PATH:"` pattern to prevent duplicates
> - Profile files (`zprofile`, `bash_profile`) source `common.sh` once at login
> - RC files (`zshrc`, `bashrc`) handle interactive setup only (prompts, hooks, aliases)
> - 1Password SSH agent configured only on desktops via hostname check in `.zprofile`
> - `direnv` hooks in both shells enable just-in-time secrets via `.envrc` files

## Phase 6: Desktop & Development Environment (Ansible)

**Goal:** Configure the physical desktop (`dt-dev`) and development tools.

**Status:** 🚧 In Progress - Testing on `dt-dev-02`

> **Note:** Test on `dt-dev-02` first before applying to primary workstation `dt-dev-01`.

- [x] **Prerequisites**

  - [x] Connect `dt-dev-02` and update inventory with IP address.
  - [x] Verify SSH access to desktop machines.

- [x] **Ansible Become Password via 1Password**

  - [x] Remove `~/.config/ansible/get_become_pass.sh` script.
  - [x] Remove `become_password_file` from `ansible.cfg`.
  - [x] Use `community.general.onepassword` lookup plugin in `site.yml`.
  - [x] Authenticate via 1Password desktop app (biometrics), not service account token.

- [x] **Role: `desktop`** (Source: `11_desktop.sh`, `12_desktop_apps.sh`)

  - [x] **Sway/Wayland Stack:**
    - [x] Install Sway, xwayland, swayidle, swaylock, swayimg
    - [x] Install xdg-desktop-portal, xdg-desktop-portal-wlr
  - [x] **Audio Stack (PipeWire):**
    - [x] Install pipewire, pipewire-pulse, pipewire-audio, wireplumber
    - [x] Install bluez, blueman, pavucontrol, playerctl
  - [x] **Desktop Components:**
    - [x] Install i3status-rs (build from source via cargo)
    - [x] Install Mako notification daemon
    - [x] Install Kickoff launcher (via cargo)
    - [x] Install screenshot tools: slurp, shotman, oculante
  - [x] **Input & Localization:**
    - [x] Install fcitx5-mozc for Japanese input
    - [x] Install Nerd Fonts (0xProto, FiraCode, Hack, Meslo, etc.)
  - [x] **Power & Display:**
    - [x] Install TLP power management
    - [x] Install brightnessctl (add user to `video` group)
    - [x] Install wl-gammarelay-rs (via cargo)
  - [x] **Desktop Applications:**
    - [x] Install Alacritty terminal (build from source via cargo)
    - [x] Install Starship prompt
    - [x] Install Firefox, Chrome
    - [x] Install Cursor (via official install script)
    - [x] Install 1Password GUI
    - [x] Install Claude Code CLI (via pnpm)
    - [x] Install Discord, Spotify, Zotero
    - [x] Install Remmina (remote desktop)

- [x] **Role: `dev_languages`** (Source: `09_languages.sh`)

  - [x] **Rust:** Install via rustup
  - [x] **Python:**
    - [x] Install UV package manager (from astral.sh)
    - [x] Install linters/formatters: ruff, mypy, pyright, pylint, pytest, pre-commit
    - [x] Install shellcheck, shfmt
  - [x] **Node.js:**
    - [x] Install nvm (Node Version Manager)
    - [x] Install Node.js LTS
    - [x] Install pnpm package manager
  - [x] **Go:** Install golang-go package
  - [x] **Java:** Install OpenJDK (default-jdk)
  - [x] **Kotlin:** Install via SDKMAN

- [x] **Role: `cloud_tools`** (Source: `10_cloud.sh`)

  - [x] **Cloud CLIs:**
    - [x] Install AWS CLI v2
    - [x] Install GCP CLI (google-cloud-sdk)
    - [x] Install Firebase CLI (via pnpm)
  - [x] **Infrastructure Tools:**
    - [x] Install Terraform (from HashiCorp repo)
    - [x] Install GitHub CLI
    - [x] Install Ansible
  - [x] **Utilities:**
    - [x] Install Playwright (via pnpm, with browser dependencies)

- [ ] **Testing & Validation on `dt-dev-02`**

  - [x] Fix Ansible become password (use 1Password lookup plugin)
  - [x] Fix /tmp disk space issue (clean up stale cargo build dirs)
  - [x] Remove Yazi (compilation issues with vergen dependency conflict)
  - [x] Replace Cursor AppImage with official install script
  - [ ] Run full playbook successfully on `dt-dev-02`
  - [ ] Verify Sway/Wayland desktop launches correctly
  - [ ] Verify audio stack (PipeWire/Bluetooth) functional
  - [ ] Verify all Cargo-installed tools work (i3status-rs, alacritty, kickoff)
  - [ ] Verify development language toolchains (rust, python/uv, node/pnpm, go)
  - [ ] Verify cloud tools (aws, gcloud, terraform, gh)
  - [ ] Test 1Password SSH agent integration
  - [ ] Test chezmoi dotfiles apply correctly
  - [ ] Document any fixes required for production deployment

> **Implementation Notes (2026-01-18):**
> - Ansible become password fetched via `community.general.onepassword` lookup from `op://build/env-vars/ansible-become-password`
> - Uses 1Password desktop app with biometrics (not `OP_SERVICE_ACCOUNT_TOKEN`)
> - Cursor installed via official script: `curl https://cursor.com/install -fsS | bash`
> - Yazi removed due to Rust dependency conflicts (vergen-lib version mismatch)
> - No snaps or AppImages used in any ansible roles

---

## Phase 7: GPU Passthrough for KVM VMs

**Goal:** Enable GPU passthrough from hypervisors to VMs for ML/AI workloads (Ollama, training).

**Status:** 🚧 In Progress

> **Documentation:** See [`docs/GPU_PASSTHROUGH.md`](docs/GPU_PASSTHROUGH.md) for detailed setup instructions.

### Hardware Summary

| Hypervisor | GPU | Passthrough Status |
|------------|-----|-------------------|
| bm-hypervisor-01 | NVIDIA GTX 960 (2GB) | Optional (limited VRAM) |
| bm-hypervisor-02 | NVIDIA RTX 3090 (24GB) | **Primary test target** |
| bm-hypervisor-03 | 6x AMD RX 7900 XTX (24GB each) | All GPUs for passthrough |
| bm-hypervisor-04 | None | N/A (down for repairs) |

### Implementation

- [x] **Role: `gpu_passthrough`**
  - [x] Create validation tasks (CPU vendor, PCI devices)
  - [x] Configure IOMMU kernel parameters (GRUB)
  - [x] Configure VFIO modules and device binding
  - [x] Blacklist GPU drivers on host
  - [x] Create handlers for update-grub, update-initramfs

- [x] **Host Configuration**
  - [x] Update `host_vars/bm-hypervisor-02.yml` with GPU config
  - [x] Update `host_vars/bm-hypervisor-03.yml` with GPU config
  - [x] Update `host_vars/bm-hypervisor-01.yml` with GPU config (disabled by default)

- [x] **Playbook Updates**
  - [x] Add gpu_passthrough play to `site.yml`
  - [x] Add `vm_gpu` group to `inventory.yaml`

- [x] **Terraform GPU Support**
  - [x] Extend VM schema with `gpu_devices` option
  - [x] Add `hostdevs` block for PCI passthrough

- [x] **Documentation**
  - [x] Create `docs/GPU_PASSTHROUGH.md`
  - [x] Update `docs/TOPOLOGY.md` with vm-gpu specs

### Testing & Validation

- [ ] **Prerequisites (Manual)**
  - [ ] Enable IOMMU in BIOS on bm-hypervisor-02 (AMD-Vi)
  - [ ] Enable Above 4G Decoding in BIOS
  - [ ] Gather PCI device IDs: `lspci -nn | grep -i nvidia`
  - [ ] Update `host_vars/bm-hypervisor-02.yml` with actual PCI slots

- [ ] **Ansible Deployment (bm-hypervisor-02)**
  - [ ] Run: `ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-02`
  - [ ] Reboot hypervisor
  - [ ] Verify IOMMU: `dmesg | grep -i -E 'DMAR|IOMMU|AMD-Vi'`
  - [ ] Verify VFIO binding: `lspci -nnk | grep -A2 VGA`

- [ ] **GPU VM Deployment (vm-gpu-01)**
  - [ ] Uncomment vm-gpu-01 in `terraform/variables.tf`
  - [ ] Run: `terraform apply`
  - [ ] Verify GPU in VM: `nvidia-smi`
  - [ ] Test Ollama workload

- [ ] **Expand to Other Hypervisors**
  - [ ] Repeat for bm-hypervisor-03 (6x AMD RX 7900 XTX)
  - [ ] Optional: bm-hypervisor-01 (GTX 960 - limited ML utility)
