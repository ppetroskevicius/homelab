# Legacy Setup Scripts

## Overview

This directory contains legacy bash scripts used to provision and configure systems in the homelab environment. These scripts are being migrated to a modern Infrastructure-as-Code (IaC) stack using **Ansible** and **Terraform** as part of the project's modernization effort.

The scripts support both **macOS** and **Linux** (Ubuntu/Debian) platforms, with platform-specific logic handled within each script. The scripts are designed to be idempotent where possible, checking for existing installations before proceeding.

## Script Structure

```
.
├── setup.sh                    # Main entry point (The Controller)
└── legacy_scripts/             # Module directory
    ├── 01_update.sh            # Updates packages
    ├── 02_credentials.sh       # Setup credentials
    ├── 03_shell.sh             # Setup zsh
    ├── 04_dotfiles.sh          # Setup dot files
    ├── 05_system.sh            # Setup Core system utilities
    ├── 06_hypervisor.sh        # Setup KVM
    ├── 07_storage.sh           # Setup Storage utilities
    ├── 08_containers.sh        # Setup Containerization utilities
    ├── 09_languages.sh         # Setup Python, Node, Go, Rust, Java, Kotlin
    ├── 10_cloud.sh             # Setup AWS CLI, GCP CLI, Terraform, Ansible
    ├── 11_desktop.sh           # Setup Ubuntu Sway desktop
    ├── 12_desktop_apps.sh      # Setup Alacritty, Firefox, Claude Code
    ├── 13_gpus_ml.sh           # Setup NVidia, AMD GPU drivers and libraries
    ├── 14_cleanup.sh           # Clean-up installation
    └── 15_profiles.sh          # Definition of "dt-dev", "vm-k8s-node"
```

## Script-by-Script Documentation

### 01_update.sh - System Updates and Prerequisites

**Purpose:** Updates system packages and installs foundational tools required by other scripts.

**Key Functions:**

- `install_homebrew()` - Installs Homebrew package manager on macOS (supports both Intel and Apple Silicon)
- `install_chezmoi()` - Installs Chezmoi dotfile manager (required for script 04)
  - macOS: via Homebrew
  - Linux: downloads binary to `~/.local/bin`
- `update_packages()` - Updates system packages
  - macOS: `brew update && brew upgrade`
  - Linux: `apt update && apt upgrade -y`
- `setup_timezone()` - Sets system timezone to `Asia/Tokyo`
  - macOS: uses `systemsetup`
  - Linux: uses `timedatectl`
- `setup_macos_preferences()` - Configures macOS system preferences (macOS only)
  - Finder: shows all files, pathbar, status bar
  - Dock: autohide enabled, tile size 36
  - Keyboard: KeyRepeat=2, InitialKeyRepeat=15

**Dependencies:** None (first script in sequence)

**Platform Notes:** Full cross-platform support. Chezmoi is installed to `~/.local/bin` on Linux and added to PATH.

---

### 02_credentials.sh - Credential Management

**Purpose:** Sets up credential management tools and prepares for secure key storage.

**Key Functions:**

- `setup_1password_cli()` - Installs and authenticates 1Password CLI
  - macOS: via Homebrew
  - Linux: adds official 1Password APT repository with GPG key verification
  - Signs in using `$OP_ACCOUNT` environment variable if not already authenticated
- `setup_ssh_credentials()` - Prepares SSH directory structure
  - Creates `~/.ssh` with 700 permissions
  - Note: Actual SSH keys are managed by Chezmoi (encrypted templates)
- `setup_wireguard_client()` - Installs Wireguard client
  - Linux: installs `wireguard` package
  - Note: Configuration is managed by Chezmoi (encrypted templates)

**Dependencies:** Requires `01_update.sh` (for package updates)

**Platform Notes:** 1Password CLI installation differs significantly between platforms. SSH and Wireguard configs are template-based via Chezmoi.

---

### 03_shell.sh - Zsh Shell Setup

**Purpose:** Installs and configures Zsh as the default shell with Oh My Zsh framework.

**Key Functions:**

- `install_zsh()` - Installs Zsh and Oh My Zsh
  - macOS: via Homebrew
  - Linux: via apt, sets as default shell with `chsh`
  - Clones Oh My Zsh to `~/.oh-my-zsh`
  - Installs `zsh-autosuggestions` plugin

**Dependencies:** Requires `01_update.sh`

**Platform Notes:** On Linux, automatically changes default shell. Oh My Zsh installation is identical across platforms.

---

### 04_dotfiles.sh - Dotfile Management via Chezmoi

**Purpose:** Manages all dotfiles and configuration files using Chezmoi.

**Key Functions:**

- `install_dotfiles_core()` - Applies core CLI dotfiles
- `install_dotfiles_desktop()` - Applies desktop GUI dotfiles
- `install_dotfiles_via_chezmoi()` - Core implementation
  - Initializes Chezmoi from `$CHEZMOI_REPO` if not already initialized
  - Updates repository and applies dotfiles with `chezmoi apply --verbose`
  - Requires 1Password CLI for encrypted templates

**Dependencies:** Requires `01_update.sh` (Chezmoi) and `02_credentials.sh` (1Password CLI)

**Platform Notes:** Same behavior on both platforms. Encrypted templates require 1Password CLI to be authenticated.

---

### 05_system.sh - Core System Utilities

**Purpose:** Installs essential system utilities, monitoring tools, and development prerequisites.

**Key Functions:**

- `install_basic_utilities()` - Core CLI tools
  - macOS: vim, tmux, git, htop, unzip, netcat, jq, coreutils
  - Linux: vim, tmux, git, keychain, htop, unzip, netcat-openbsd, locales, direnv
- `install_system_monitoring()` - System monitoring tools
  - macOS: inxi
  - Linux: btop, nvtop, inxi, lm-sensors
- `install_file_text_utilities()` - File and text processing
  - macOS: ripgrep, fd, git-lfs, jq
  - Linux: csvtool, fd-find, file, ripgrep, rsync, jq, jc
- `install_system_info_utilities()` - System information tools (Linux only)
  - lshw, lsof, man-db, parallel, time
- `install_network_utilities()` - Network and remote management (Linux only)
  - infiniband-diags, ipmitool, rclone, rdma-core, systemd-journal-remote
- `install_python_base()` - Python 3 base installation (Linux only)
  - python3, python3-pip, python3-venv, python-is-python3
- `install_build_tools()` - Compilation tools (Linux only)
  - build-essential, clang

**Dependencies:** Requires `01_update.sh`

**Platform Notes:** Many functions are Linux-only. macOS relies more on Homebrew packages.

---

### 06_hypervisor.sh - KVM/Libvirt Virtualization

**Purpose:** Sets up KVM hypervisor and Libvirt management tools for VM provisioning.

**Key Functions:**

- `install_kvm()` - Installs KVM virtualization stack (Linux only)
  - Packages: qemu-kvm, libvirt-daemon-system, libvirt-clients, bridge-utils, virt-manager
  - Enables and starts `libvirtd` service
  - Adds user to `libvirt` group

**Dependencies:** Requires `01_update.sh`

**Platform Notes:** macOS not supported (exits early). User must log out/in for group membership to take effect.

---

### 07_storage.sh - Storage and Filesystem Management

**Purpose:** Installs storage utilities and configures RAID arrays for storage servers.

**Key Functions:**

- `install_storage_utilities()` - Storage tools (Linux only)
  - Packages: zfsutils-linux, mdadm, fio, nvme-cli, pciutils, nfs-kernel-server
- `setup_raid()` - Creates RAID 0 array (Linux only, BM-Hypervisor specific)
  - **WARNING:** Hardcoded devices `/dev/nvme[1-4]n1`
  - Creates `/dev/md0` as RAID 0 with 4 devices
  - Formats as ext4, mounts to `/mnt/raid0`
  - Adds to `/etc/fstab` with UUID
  - Configures mdadm and updates initramfs
  - Sets ownership to `fastctl:fastctl` with 755 permissions

**Dependencies:** Requires `01_update.sh`

**Platform Notes:** Linux only. RAID setup includes 5-second warning before destructive operation. Should only run on storage servers.

---

### 08_containers.sh - Container Runtime and Orchestration

**Purpose:** Installs Docker, K3s, and DevContainer CLI for containerized workloads.

**Key Functions:**

- `install_docker()` - Installs Docker Engine
  - macOS: Docker Desktop via Homebrew cask
  - Linux: Official Docker CE repository, installs docker-ce, containerd, docker-buildx-plugin, docker-compose-plugin
  - Creates `docker` group and adds user
  - Enables and starts Docker service
- `install_k3s()` - Installs K3s lightweight Kubernetes (Linux only)
  - Downloads and installs via official script
  - Sets kubeconfig mode to 644
  - Enables and starts k3s service
- `install_dev_container_cli()` - Installs DevContainer CLI
  - Installs via npm or pnpm as global package: `@devcontainers/cli`

**Dependencies:** Requires `01_update.sh`. DevContainer CLI requires Node.js (from `09_languages.sh`).

**Platform Notes:** Docker Desktop on macOS, Docker CE on Linux. K3s is Linux-only.

---

### 09_languages.sh - Development Languages and Runtimes

**Purpose:** Installs multiple programming language runtimes and development tools.

**Key Functions:**

- `install_rust()` - Installs Rust toolchain
  - Downloads and runs `rustup` installer
  - Sources `~/.cargo/env` after installation
- `install_uv()` - Installs UV Python package manager
  - Downloads from astral.sh
  - Sources `~/.local/bin/env` and runs self-update
- `install_linters_formatters()` - Python tooling via UV
  - Installs: ruff, mypy, pyright, pylint, pytest, pre-commit
  - Installs shellcheck and shfmt (Homebrew on macOS, apt on Linux)
- `install_node()` - Installs Node.js and pnpm
  - Installs nvm (Node Version Manager) v0.40.3
  - Installs Node.js LTS version
  - Installs pnpm via official installer
  - Calls `install_playwright_cli()` (defined in `10_cloud.sh`)
- `install_java()` - Installs OpenJDK
  - macOS: via Homebrew, creates symlink in `/Library/Java/JavaVirtualMachines/`
  - Linux: default-jdk package
- `install_kotlin()` - Installs Kotlin via SDKMAN
  - Installs SDKMAN if not present
  - Sources SDKMAN and installs Kotlin
- `install_golang()` - Installs Go
  - macOS: via Homebrew
  - Linux: golang-go package

**Dependencies:** Requires `01_update.sh`. Some functions require Rust (for cargo-based installs).

**Platform Notes:** Cross-platform with platform-specific package managers. UV and Rust use official installers.

---

### 10_cloud.sh - Cloud CLIs and Infrastructure Tools

**Purpose:** Installs cloud provider CLIs, infrastructure tools, and related utilities.

**Key Functions:**

- `install_aws_cli()` - Installs AWS CLI v2
  - macOS: downloads and installs .pkg
  - Linux: downloads zip, extracts, runs installer
- `install_gcp_cli()` - Installs Google Cloud SDK
  - macOS: via Homebrew cask
  - Linux: adds official APT repository with GPG key
- `install_firebase_cli()` - Installs Firebase CLI
  - Installs via pnpm as global package: `firebase-tools`
- `install_terraform_cli()` - Installs Terraform
  - macOS: via HashiCorp Homebrew tap
  - Linux: adds HashiCorp APT repository with GPG key
- `install_github_cli()` - Installs GitHub CLI
  - macOS: via Homebrew
  - Linux: via apt
- `install_cloud_tools()` - Master function
  - Calls all above functions
  - Installs Ansible on Linux only (via apt)
- `install_yazi()` - Installs Yazi file manager
  - macOS: via Homebrew (with all dependencies)
  - Linux: installs dependencies via apt, builds from source via cargo
- `install_playwright_cli()` - Installs Playwright browser automation
  - Linux: installs system dependencies (libwoff1, libevent, etc.)
  - Installs via pnpm: `playwright`
  - Installs browsers: chromium, firefox, webkit

**Dependencies:** Requires `01_update.sh`. Firebase and Playwright require Node.js/pnpm (from `09_languages.sh`). Yazi requires Rust (from `09_languages.sh`).

**Platform Notes:** Most tools have platform-specific installation methods. Ansible is Linux-only.

---

### 11_desktop.sh - Desktop Environment (Linux)

**Purpose:** Sets up Sway Wayland compositor and desktop environment components.

**Key Functions:**

- `install_desktop_env_linux()` - Master function (Linux only)
  - Calls all desktop setup functions
- `setup_sway_wayland()` - Installs Sway and Wayland components
  - Packages: sway, wayland-protocols, xwayland, swayidle, swaylock, swayimg, desktop-file-utils, xdg-desktop-portal, xdg-desktop-portal-wlr, pipewire-audio-client-libraries
  - Enables xdg-desktop-portal user service
- `install_i3status-rs()` - Installs Rust-based status bar
  - Installs build dependencies
  - Clones and builds from source via cargo
  - Runs install script
- `install_notifications()` - Installs Mako notification daemon
- `install_kickoff()` - Installs Kickoff launcher via cargo
- `setup_bluetooth_audio()` - Configures Bluetooth audio
  - Packages: bluez, blueman, bluetooth, pavucontrol, alsa-utils, playerctl, pulsemixer, fzf, pipewire, pipewire-pulse, pipewire-audio, wireplumber, pipewire-alsa, pulseaudio-module-bluetooth
  - Enables bluetooth and pipewire services
- `install_screenshots()` - Installs screenshot tools
  - Installs slurp and build dependencies
  - Builds shotman from source
  - Installs oculante via cargo
- `setup_japanese()` - Configures Japanese input method
  - Packages: fcitx5, fcitx5-mozc, fcitx5-configtool
  - Sets fcitx5 as input method
- `setup_power_management()` - Configures TLP power management
  - Installs tlp and tlp-rdw
  - Enables TLP service
  - Creates symlink from `~/.tlp.conf` (managed by Chezmoi) to `/etc/tlp.conf`
- `setup_brightness()` - Installs brightness control
  - Installs brightnessctl
  - Adds user to `video` group
- `setup_gamma()` - Installs gamma adjustment tool
  - Installs wl-gammarelay-rs via cargo
- `setup_netplan()` - Configures Netplan (disables NetworkManager)
  - Stops and disables NetworkManager
  - Enables systemd-networkd
- `install_wireguard()` - Installs Wireguard (duplicate of `02_credentials.sh`)
- `install_nerd_fonts()` - Installs Nerd Fonts
  - macOS: via Homebrew casks
  - Linux: downloads latest release from GitHub, installs multiple fonts (0xProto, FiraCode, Hack, Meslo, AnonymousPro, IntelOneMono) to `~/.local/share/fonts`
  - Runs fc-cache

**Dependencies:** Requires `01_update.sh`, `04_dotfiles.sh` (for TLP config). Some functions require Rust (from `09_languages.sh`).

**Platform Notes:** Entire script is Linux-only. Many components are Wayland-specific.

---

### 12_desktop_apps.sh - Desktop Applications

**Purpose:** Installs GUI applications and desktop tools.

**Key Functions:**

- `install_desktop_apps()` - Master function
  - Calls all application installers
  - On Linux, also installs remote desktop tools
- `install_starship()` - Installs Starship prompt
  - Downloads and runs official installer script
- `install_alacritty_app()` - Installs Alacritty terminal
  - macOS: via Homebrew
  - Linux: installs build dependencies, builds from source via cargo
- `install_1password_app()` - Installs 1Password GUI
  - macOS: via Homebrew cask
  - Linux: via apt
- `install_zed_app()` - Installs Zed editor
  - macOS: via Homebrew cask
  - Linux: downloads and runs official installer script
- `install_cursor_app()` - Installs Cursor editor
  - macOS: via Homebrew cask
  - Linux: installs libnotify-bin, runs community installer script
- `install_claude_code_app()` - Installs Claude Code CLI
  - Installs via pnpm: `@anthropic-ai/claude-code`
- `install_chrome_app()` - Installs Google Chrome
  - macOS: via Homebrew cask
  - Linux: downloads .deb, installs dependencies, installs package
- `install_firefox_app()` - Installs Firefox
  - macOS: via Homebrew cask
  - Linux: via apt
- `install_discord_app()` - Installs Discord
  - macOS: via Homebrew cask
  - Linux: downloads .deb from official API, installs package
- `install_zotero_app()` - Installs Zotero reference manager
  - macOS: via Homebrew cask
  - Linux: adds community repository, installs via apt
- `install_spotify_app()` - Installs Spotify
  - macOS: via Homebrew cask
  - Linux: adds official repository with GPG key, installs via apt
- `install_remote_desktop()` - Installs Remmina (Linux only)
  - Installs remmina via apt

**Dependencies:** Requires `01_update.sh`. Some apps require Node.js/pnpm (from `09_languages.sh`). Alacritty requires Rust (from `09_languages.sh`).

**Platform Notes:** Most applications have platform-specific installation methods. Remmina is Linux-only.

---

### 13_gpus_ml.sh - GPU Drivers and ML Tools

**Purpose:** Installs GPU drivers and machine learning runtime tools.

**Key Functions:**

- `install_gpu_ml_tools()` - Master function
  - Detects NVIDIA GPU via `lspci`
  - Installs NVIDIA driver 550 if GPU detected (Linux only)
  - Calls `install_ollama()`
- `install_ollama()` - Installs Ollama LLM runtime
  - Downloads and runs official installer script

**Dependencies:** Requires `01_update.sh`

**Platform Notes:** NVIDIA driver installation is Linux-only and conditional on hardware detection. Ollama is cross-platform.

---

### 14_cleanup.sh - System Cleanup

**Purpose:** Removes unnecessary packages and cleans up system caches.

**Key Functions:**

- `remove_snap()` - Removes Snap package manager (Linux only)
  - Purges snapd package
  - Removes `/var/cache/snapd` and `/snap` directories
- `cleanup_all()` - Master cleanup function
  - macOS: runs `brew cleanup`
  - Linux: runs `apt autoremove -y`, `apt clean -y`, and `remove_snap()`

**Dependencies:** Requires `01_update.sh`

**Platform Notes:** Snap removal is Linux-only. Should be run last in provisioning sequence.

---

### 15_profiles.sh - Profile Definitions

**Purpose:** Defines system profiles that combine specific script functions for different use cases.

**Key Functions:**

- `profile_bm_hypervisor()` - Bare metal hypervisor profile (Linux only)
  - Sequence: update → timezone → credentials → shell → dotfiles (core) → basic utils → monitoring → storage → KVM → RAID → cleanup
  - **Platform:** Linux only (exits on macOS)
- `profile_vm_k8s_node()` - Kubernetes node VM profile (Linux only)
  - Sequence: update → timezone → credentials → shell → dotfiles (core) → basic utils → monitoring → file utils → system info → network utils → python → K3s → cleanup
  - **Platform:** Linux only (exits on macOS)
- `profile_vm_dev_container()` - Development container host VM profile
  - Sequence: update → timezone → credentials → shell → dotfiles (core) → basic utils → monitoring → file utils → system info → network utils → python → Docker → Node.js → DevContainer CLI → cleanup
  - **Platform:** Cross-platform
- `profile_vm_service()` - Lightweight service VM profile
  - Sequence: update → timezone → credentials → shell → dotfiles (core) → basic utils → monitoring → file utils → NFS client → cleanup
  - **Platform:** Cross-platform (NFS client Linux only)
- `profile_dt_dev()` - Full desktop development environment profile
  - Sequence: update → timezone → credentials → Wireguard → shell → dotfiles (core + desktop) → all utilities → build tools → Docker → all languages → cloud tools → Yazi → Playwright → fonts → desktop env (Linux) / macOS prefs → desktop apps → GPU/ML → cleanup
  - **Platform:** Cross-platform with platform-specific desktop components

**Dependencies:** All profiles depend on functions from scripts 01-14.

**Platform Notes:** Profiles enforce platform restrictions. `dt-dev` is the most comprehensive profile, including all development tools and desktop environment.

## Profile Usage

Profiles are invoked from the main `setup.sh` script. Each profile represents a complete system configuration for a specific role:

- **bm-hypervisor**: Storage server with KVM virtualization and ZFS/RAID
- **vm-k8s-node**: Kubernetes worker node with monitoring
- **vm-dev-container**: Development container host with Docker and DevContainer CLI
- **vm-service**: Minimal service VM with basic utilities and NFS client
- **dt-dev**: Full-featured development desktop with all languages, tools, and GUI applications

## Migration Notes

When migrating these scripts to Ansible/Terraform:

1. **Ansible Modules**: Prefer Ansible modules over shell commands (e.g., `community.general.zfs` instead of `zpool create`)
2. **Idempotency**: All functions should be idempotent - check before installing
3. **Platform Detection**: Use Ansible facts (`ansible_os_family`) instead of `$OS` variable
4. **Hardcoded Values**: Replace hardcoded values (e.g., RAID devices) with variables
5. **Service Management**: Use `ansible.builtin.systemd` instead of direct `systemctl` calls
6. **Package Management**: Use `ansible.builtin.apt`/`ansible.builtin.package` instead of direct apt/brew calls
7. **User Groups**: Use `ansible.builtin.user` module instead of `usermod`
8. **File Management**: Use `ansible.builtin.template` or `ansible.builtin.copy` instead of direct file operations

## Dependencies and Prerequisites

- **Global Variables**: Scripts expect variables defined in `setup.sh` (e.g., `$OS`, `$CHEZMOI_REPO`, `$OP_ACCOUNT`)
- **Temp Directory**: Scripts use `$tempdir` for temporary files (initialized in `01_update.sh`)
- **Execution Order**: Scripts are numbered and should be executed in sequence within profiles
- **Privileges**: Many functions require `sudo` for system-level changes

## Warnings

- **RAID Setup** (`07_storage.sh::setup_raid`): Hardcoded device paths (`/dev/nvme[1-4]n1`) - verify before execution
- **NetworkManager** (`11_desktop.sh::setup_netplan`): Disables NetworkManager - ensure Netplan config exists first
- **Group Membership**: User group changes (e.g., `libvirt`, `docker`, `video`) require logout/login to take effect
- **Encrypted Templates**: Chezmoi encrypted templates require 1Password CLI authentication
