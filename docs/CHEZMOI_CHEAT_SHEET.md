# Chezmoi Cheat Sheet

## Desktop Bootstrap

```bash
cd ~/fun/homelab/ansible
ansible-playbook -i inventory.yaml site.yml --limit dt-dev-01
```

After 1Password desktop is installed and signed in:

```bash
chezmoi apply
```

## Common Commands

```bash
chezmoi status
chezmoi diff
chezmoi apply
chezmoi source-path
chezmoi edit ~/.zshrc
```

## Source Location

This repo uses `.chezmoiroot`, so the source state is the `chezmoi/` subdirectory of the monorepo.

Desktop hardware data for Sway, Mako, and i3status-rust lives in:

```bash
chezmoi/.chezmoidata.yaml
```

## Server Dotfiles

Servers and VMs do not run Chezmoi directly. Ansible copies minimal static files from `chezmoi/` and renders server-specific templates from `ansible/roles/dotfiles/templates/`.
