# Secrets Strategy

Secrets are split by execution context.

## Desktops

Desktops (`dt-*` and `work-mac`) are interactive machines. They may use:

- 1Password desktop app with biometric unlock
- 1Password SSH agent for private keys
- `op` through Chezmoi templates
- `direnv` for project-local environment loading

Chezmoi is initialized by Ansible but applied manually after 1Password is installed and signed in.

## Servers and VMs

Non-desktop machines (`bm-*`, `vm-*`) should not store personal private keys or depend on 1Password for normal shell startup.

They receive only minimal static dotfiles through Ansible:

- Bash startup files
- Vim/tmux/editor config
- Git config
- SSH config that uses agent forwarding

SSH access should come from a desktop/control node via forwarded agent.

## Service Account Tokens

`OP_SERVICE_ACCOUNT_TOKEN` is reserved for automation contexts such as CI or scheduled jobs. Do not put it in global shell startup files.

## Practical Rules

- Keep private SSH keys on desktops only.
- Do not make server login depend on `op`.
- Prefer `direnv` for per-project secrets instead of global exports.
- Use Ansible lookups from the control node for provisioning-time secrets such as `ansible_become_password`.
