# Agent Instructions

Instructions for coding agents (Codex and others) working in this repo. Claude Code reads
[`CLAUDE.md`](CLAUDE.md); the project context there applies to every agent, so read it first: mission,
architecture, Ansible/Terraform conventions, and the development workflow.

## This repo is public

Before anything leaves this machine (`git push`, merge to `main`, PR), check that nothing work-specific is
in the code, comments, docs, config, or commit messages being published. See
[`CLAUDE.md` section 6](CLAUDE.md#6-public-repo-no-work-specific-content) for the full rule. In short:

- No employer/company names, work product or internal project names, internal hostnames/URLs/repo names,
  or customer/coworker names.
- No credentials of any kind (API tokens, keys, private-key blocks, JWTs).
- No agent config from `~/.claude` or `~/.codex` (deliberately not tracked).
- Scan the added lines of the **whole range being pushed**, not just `HEAD`.
- The concrete list of names to scan for is deliberately not written here. If you do not have it, ask the
  user before pushing.
