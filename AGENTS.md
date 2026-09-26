# Project Context & Rules

## 1. Project Mission

Migrate the home lab from legacy bash scripts (`legacy_scripts/`) to IaC: **Ansible**, **Terraform**
(`dmacvicar/libvirt`) and **Chezmoi**. Phases and status: `ROADMAP.md`. Topic docs: `docs/` (topology,
network, storage, inventory, secrets, chezmoi, ...).

## 2. Terraform (`./terraform`)

- Do NOT build custom ISOs. Use the generic Ubuntu 24.04 cloud image + `libvirt_cloudinit_disk`
  (SSH keys, hostname, default user `fastctl`).
- Prefer the existing Netplan-defined bridges (e.g. `br0`) over creating new ones.

## 3. Ansible (`./ansible`)

- **Strictly prefer Ansible modules over `command`/`shell`** (e.g. `community.general.zfs`, not
  `zpool create`; `template`/`lineinfile` for `/etc/exports`, not `echo >>`). Use `become: true` for system changes.
- The become password comes from 1Password (`env-vars` / `ansible-become-password`, vault `build`)
  and needs the desktop app signed in.
- Dotfiles: `bm-*`/`vm-*` get minimal Ansible-copied dotfiles; `dt-*` use Chezmoi + 1Password, and the user
  runs `chezmoi apply` (`docs/CHEZMOI.md`).
- Storage source of truth is `docs/STORAGE.md`. `bm-hypervisor-01` serves NFS from ZFS; `bm-hypervisor-02/03`
  mount it via `ansible.posix.mount`.

## 4. Hardware

- **bm-hypervisor-01**: storage server (`zfsutils-linux`, `nfs-kernel-server`).
- **bm-hypervisor-03**: ML compute (`amdgpu-dkms`, `rocm`).
- **bm-hypervisor-04**: low-spec sandbox. No heavy ZFS/K8s loads.

## 5. Development Workflow

```bash
ansible-playbook -i inventory.yaml site.yml --limit bm-hypervisor-04   # sandbox test first
```

Run `ansible-lint` and `terraform fmt` before committing.

## 6. Public Repo: No Work-Specific Content

This repo is **public**. Before anything leaves this machine (`git push`, merge to `main`, PR), check that
nothing work-specific is in the code, comments, docs, config, or commit messages being published:

- Employer/company names, work product or internal project names, internal hostnames/URLs/repo names,
  customer or coworker names.
- Credentials of any kind (API tokens, keys, private-key blocks, JWTs).
- Agent config from `~/.claude` or `~/.codex` (deliberately not tracked; ask before adding anything under
  `chezmoi/dot_claude/`).

How to check:

- Scan the **added lines of the whole range being pushed** (`git diff <remote-tip>..<local-tip>`), not just
  `HEAD`: pushing publishes every commit in the range, and history is hard to retract.
- The concrete list of names to scan for is kept in private agent memory, not in this file (writing them
  here would itself leak them). If you do not have it, ask the user before pushing.
- If something work-specific turns up, stop and ask before pushing. Rewrite or drop the commit rather than
  pushing a follow-up fix.
