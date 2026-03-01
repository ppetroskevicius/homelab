# Google Drive sync with Rclone

Configure a folder on desktops `/data/google_drive` to sync with the Google Drive.

## Upload Files to Google Drive

```sh
until rclone copy /data/google_drive gdrive_remote:google_drive \
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

Google Drive (also legacy Micrsoft OneDrive) credentials configuration is read from 1password through chezmoi template:

```sh
chezmoi edit ~/.config/rclone/rclone.conf
```

```txt
{{- /* Read the entire rclone.conf attachment from 1Password */ -}}
{{- onepasswordRead "op://Personal/rclone_config/rclone.conf" -}}
```

## Ansible Setup

Here is the Ansible playbook to configure and auto-start your Google Drive mount.

This playbook assumes:

1. **Rclone** configuration is already present (deployed via your Chezmoi template).
2. **Rclone** software might need installing.
3. **Systemd** needs to be set up to mount the drive on boot.

### `setup_gdrive_mount.yml`

```yaml
---
- name: Configure Google Drive Rclone Mount (User Level)
  hosts: localhost
  connection: local
  gather_facts: true
  vars:
    # Configuration
    rclone_remote_name: "gdrive_remote"
    mount_path: /data/google_drive"
    service_name: "rclone_gdrive"

    # Rclone Settings
    rclone_vfs_cache_mode: "full"
    rclone_vfs_max_size: "10G"
    rclone_log_level: "NOTICE"

  tasks:
    # 1. Install Rclone (Requires Sudo)
    - name: Ensure Rclone is installed
      become: true
      ansible.builtin.apt:
        name: rclone
        state: present
        update_cache: false

    # 2. Verify Config Exists (Safety Check)
    - name: Check if Rclone config exists
      ansible.builtin.stat:
        path: "{{ ansible_env.HOME }}/.config/rclone/rclone.conf"
      register: rclone_conf

    - name: Fail if Rclone config is missing (Chezmoi should have run)
      ansible.builtin.fail:
        msg: "Rclone config not found! Please run 'chezmoi apply' first to deploy secrets from 1Password."
      when: not rclone_conf.stat.exists

    # 3. Create Mount Directory
    - name: Ensure mount point directory exists
      ansible.builtin.file:
        path: "{{ mount_path }}"
        state: directory
        mode: "0755"

    # 4. Enable Linger (Allows service to start at boot without login)
    - name: Enable systemd linger for the user
      become: true
      ansible.builtin.command:
        cmd: "loginctl enable-linger {{ ansible_user_id }}"
        creates: "/var/lib/systemd/linger/{{ ansible_user_id }}"

    # 5. Create Systemd Service File
    - name: Create Systemd user directory
      ansible.builtin.file:
        path: "{{ ansible_env.HOME }}/.config/systemd/user"
        state: directory
        mode: "0755"

    - name: Deploy Rclone Systemd Service
      ansible.builtin.copy:
        dest: "{{ ansible_env.HOME }}/.config/systemd/user/{{ service_name }}.service"
        mode: "0644"
        content: |
          [Unit]
          Description=Rclone Mount for Google Drive
          Wants=network-online.target
          After=network-online.target

          [Service]
          Type=notify
          # Pointing to the mount path dynamically
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

### How to Run It

Since this playbook manages **User** services (Systemd) but requires **Root** privileges for package installation and `loginctl`, you run it as your normal user and let Ansible ask for the sudo password when needed.

```bash
ansible-playbook setup_gdrive_mount.yml --ask-become-pass

```

### Why specific steps?

- **`loginctl enable-linger`**: This is critical for servers. Without it, your "User Service" (Google Drive mount) would only start when you actively log in via SSH/Sway and would die when you log out. Linger ensures it starts when the server boots.
- **`ansible.builtin.fail`**: I added a safety check. If you run this on a fresh machine where `chezmoi apply` hasn't pulled the secrets yet, the playbook stops immediately instead of creating a broken service loop.
