# Rclone

## OneDrive Files Download

> [!NOTE]
> This is already completed. Do not need to run again.

Rclone command to download files from OneDrive to `/data/onedrive_back` on Lenovo.

```sh
until rclone copy onedrive_remote: /data/onedrive_backup \
    -P \
    --transfers=32 \
    --checkers=32 \
    --buffer-size=512M \
    --multi-thread-streams=4 \
    --multi-thread-cutoff=256M; do
    echo "Network interruption or throttling detected. Retrying in 30 seconds..."
    sleep 30
done
```

## Upload Files to Google Drive

```sh
until rclone copy /data/onedrive_backup gdrive_remote:onedrive_backup \
    -P \
    --transfers=24 \
    --checkers=24 \
    --drive-chunk-size=128M \
    --drive-pacer-min-sleep=10ms \
    --drive-pacer-burst=200; do
    echo "Upload interrupted. Retrying in 30 seconds..."
    sleep 30
done
```

Configuration is read from 1password through chezmoi template:

```sh
chezmoi edit ~/.config/rclone/rclone.conf
```

```txt
{{- /* Read the entire rclone.conf attachment from 1Password */ -}}
{{- onepasswordRead "op://Personal/rclone_config/rclone.conf" -}}
```

## Bidirectional Sync with Google Drive

The recommended approach uses `rclone bisync` to keep `/data/google_drive` synchronized with Google Drive. Changes on either side are synced to the other.

### How It Works

- **Local path**: `/data/google_drive`
- **Remote**: `gdrive_remote:` (configured in rclone.conf via 1Password)
- **Frequency**: Hourly via systemd timer
- **Direction**: Bidirectional (changes sync both ways)

### Ansible Setup

The `desktop` role includes rclone sync configuration:

```bash
# Run Ansible to set up rclone and systemd services
ansible-playbook -i inventory.yaml site.yml --limit dt-dev-02 --tags rclone
```

This installs:
- Rclone package
- `/data/google_drive` directory
- Systemd user service (`rclone-bisync.service`)
- Systemd timer (`rclone-bisync.timer`) - runs hourly
- Initialization script (`~/.local/bin/rclone-bisync-init`)

### First-Time Setup

After running Ansible, you must initialize bisync:

```bash
# 1. Ensure rclone config is deployed (requires 1Password)
chezmoi apply

# 2. Verify rclone config works
rclone lsd gdrive_remote:

# 3. Initialize bisync (creates baseline)
# First, do a dry run to see what would happen:
rclone-bisync-init --dry-run

# If everything looks good, run for real:
rclone-bisync-init
```

The init script will:
1. Perform initial `--resync` to establish baseline
2. Enable the systemd timer for hourly syncs

### Manual Operations

```bash
# Run sync manually
systemctl --user start rclone-bisync

# Check sync status
systemctl --user status rclone-bisync.timer

# View logs
journalctl --user -u rclone-bisync -f

# Disable automatic sync
systemctl --user disable rclone-bisync.timer
```

### Filter Rules

Customize what gets synced by editing `~/.config/rclone/bisync-filters.txt`:

```txt
# Exclude patterns
- .DS_Store
- *.tmp
- .Trash-*
- **/.git/**

# Include everything else by default
```

### Safety Features

The service includes safeguards:
- `--max-delete 50`: Prevents accidental mass deletion (max 50 files per sync)
- `--check-access`: Verifies remote is accessible before sync
- `--resilient`: Continues on minor errors
- `--recover`: Attempts to recover from previous failed syncs

### Troubleshooting

```bash
# Check if rclone config exists
ls -la ~/.config/rclone/rclone.conf

# Test remote connection
rclone lsd gdrive_remote:

# Check timer status
systemctl --user list-timers

# Force a resync (WARNING: destructive if sides differ)
rclone bisync /data/google_drive gdrive_remote: --resync --verbose
```

---

## Alternative: FUSE Mount (Read-Only Access)

If you prefer accessing Google Drive as a mounted filesystem (streaming, no local copy), use the mount approach instead.

> Note: Mount and bisync are mutually exclusive. Choose one approach.

### Mount Setup (Legacy)

```yaml
# Standalone playbook for mount approach
- name: Configure Google Drive Rclone Mount (User Level)
  hosts: localhost
  connection: local
  gather_facts: true
  vars:
    rclone_remote_name: "gdrive_remote"
    mount_path: "{{ ansible_env.HOME }}/google_drive"
    service_name: "rclone_gdrive"
    rclone_vfs_cache_mode: "full"
    rclone_vfs_max_size: "10G"
    rclone_log_level: "NOTICE"

  tasks:
    - name: Ensure Rclone is installed
      become: true
      ansible.builtin.apt:
        name: rclone
        state: present

    - name: Check if Rclone config exists
      ansible.builtin.stat:
        path: "{{ ansible_env.HOME }}/.config/rclone/rclone.conf"
      register: rclone_conf

    - name: Fail if Rclone config is missing
      ansible.builtin.fail:
        msg: "Rclone config not found! Run 'chezmoi apply' first."
      when: not rclone_conf.stat.exists

    - name: Ensure mount point directory exists
      ansible.builtin.file:
        path: "{{ mount_path }}"
        state: directory
        mode: '0755'

    - name: Enable systemd linger for the user
      become: true
      ansible.builtin.command:
        cmd: "loginctl enable-linger {{ ansible_user_id }}"
        creates: "/var/lib/systemd/linger/{{ ansible_user_id }}"

    - name: Create Systemd user directory
      ansible.builtin.file:
        path: "{{ ansible_env.HOME }}/.config/systemd/user"
        state: directory
        mode: '0755'

    - name: Deploy Rclone Systemd Service
      ansible.builtin.copy:
        dest: "{{ ansible_env.HOME }}/.config/systemd/user/{{ service_name }}.service"
        mode: '0644'
        content: |
          [Unit]
          Description=Rclone Mount for Google Drive
          Wants=network-online.target
          After=network-online.target

          [Service]
          Type=notify
          ExecStart=/usr/bin/rclone mount {{ rclone_remote_name }}: %h/google_drive \
              --vfs-cache-mode {{ rclone_vfs_cache_mode }} \
              --vfs-cache-max-size {{ rclone_vfs_max_size }} \
              --log-file %h/{{ service_name }}.log \
              --log-level {{ rclone_log_level }}
          ExecStop=/bin/fusermount -u %h/google_drive
          Restart=on-failure
          RestartSec=10

          [Install]
          WantedBy=default.target
      notify: Restart Rclone Service

  handlers:
    - name: Restart Rclone Service
      ansible.builtin.systemd:
        scope: user
        name: "{{ service_name }}"
        state: restarted
        enabled: true
        daemon_reload: true
```

