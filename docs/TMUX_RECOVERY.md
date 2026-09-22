# Tmux and agent conversation recovery

Chezmoi manages the terminal settings, optional patched tmux launcher, and the
`agent-resume` integration with tmux-resurrect. Conversation data and machine-specific
session names remain private local state. No transcripts, session IDs, credentials,
compiled binaries, or recovery snapshots belong in this public repository.

## Managed files

| Source | Installed purpose |
|---|---|
| `chezmoi/dot_tmux.conf` | Tmux settings, pane titles, color environment, recovery hook |
| `chezmoi/dot_local/bin/executable_agent-resume` | Exact-session save hook and launcher |
| `chezmoi/dot_local/bin/executable_tmux` | Prefer optional patched build; otherwise use system tmux |
| `chezmoi/dot_local/bin/executable_tmux-build-patched` | Explicit reproducible build command |
| `chezmoi/dot_config/tmux/tmux-3.7d-backport.patch` | Pinned upstream changes |
| `chezmoi/dot_config/alacritty/alacritty.toml.tmpl` | Terminal launcher and configurable default session |

Set `tmux_session` under `[data]` in local `~/.config/chezmoi/chezmoi.toml` to
choose a default session; the public template defaults to `main`. Changing this
local setting does not publish the session name. Apply only the relevant targets
when unrelated dotfiles have local changes.

## Exact conversation restoration

Tmux-resurrect preserves layout and scrollback. Its post-save-layout hook calls
`~/.local/bin/agent-resume --save <layout-file>`, which replaces recognized agent
commands with immutable recovery keys. Each key identifies the agent, exact
conversation ID, working directory, and account data directory. It never guesses
with `--continue` or `--last`.

Claude discovery reads live PID registrations from `~/.claude/sessions` and
`~/.claude-personal/sessions`. Codex discovery inspects its open thread-writer locks
and the matching root CLI record in `state_5.sqlite`. Ambiguous matches are skipped.
These are internal CLI formats: retest discovery after agent upgrades. Resume
checks for an already-live conversation and skips duplicates. It preserves the
account data directory and does not add permission-bypass flags.

The default Claude profile requires `CLAUDE_CONFIG_DIR` to be unset, not explicitly
set to `~/.claude`. The personal profile sets it explicitly. Codex uses `CODEX_HOME`.

Local state to back up together:

- `~/.local/share/tmux/resurrect/`: layout snapshots and pane-content archive.
- `~/.local/state/tmux-agent-recovery/specs/`: immutable resume specifications.
- Agent conversation stores and their databases in the relevant data directories.
- Working repositories/worktrees, including uncommitted changes.

`~/.local/state/tmux-agent-recovery/last-save.json` shows recognized agents in the
last save. The mappings alone do not contain the conversation transcripts.

Continuum saves every 15 minutes via the status line and restores at server
startup. Keep it last in the TPM plugin list; replacing `status-right` can disable
its scheduling. With this configuration, save manually with **backtick, Ctrl-S**
and restore with **backtick, Ctrl-R**. Save before rebooting or upgrading. A wedged
server cannot make a fresh save. Recovery reopens conversations, not interrupted
tool processes or unsaved terminal input. Do not enable `@resurrect-processes ':all:'`.

## Colors and pane titles

The recovery host can have `NO_COLOR=1` for its own non-interactive output. Do not
propagate this into interactive agents: tmux clears the global variable, and the
resume helper removes it from each agent's environment. This does not force a
particular theme. Already-running processes retain their inherited environment;
reopen the conversation when idle to apply the correction.

Pane titles are enabled at the top border. Existing attention flags and status-bar
colors remain unchanged. Toggle pane zoom with **backtick, z** when a topic window
has many panes. Titles are a usability preference, not a requirement for recovery.

## Pinned redraw fix and updates

Tmux 3.7c can livelock during redraw with invalid/empty visible ranges. The main
fix is upstream commit `c93e2f233206780ec1e2f0409c92326d06496a2d`; its stable-branch
backport is `d28c9f613d0ae19abbf6a34fa0f105ef9e6d3a64`. This repository includes all
non-configure changes from 3.7c through `release_3.7d` commit
`e9634d40749a5ae330aabf5aa46a81505b094a6b`, including the popup range-count fix.
`aggressive-resize` is not a substitute for these code fixes.

On a Homebrew machine, install prerequisites if absent:

```sh
brew install gh python libevent ncurses utf8proc jemalloc
```

After applying the managed files, explicitly run:

```sh
tmux-build-patched
```

The builder verifies the official 3.7c archive SHA-256, applies the checked-in patch,
and installs under `~/.local/libexec/tmux-3.7c-patched/`. It retains the release's
generated configure files, so `tmux -V` still reports 3.7c; the adjacent `BUILD`
file identifies the patch. Chezmoi does not build or restart servers automatically.

The managed `~/.local/bin/tmux` prefers this build; Alacritty invokes that launcher
directly. Do not replace Homebrew's `/opt/homebrew/bin/tmux` symlink. A Homebrew
upgrade cannot overwrite this local binary, although it still depends on Homebrew
libraries and may need rebuilding when those libraries change incompatibly.

Once a published release contains the fixes:

1. Save and back up the recovery data; inspect the new release's changes.
2. Run `brew upgrade tmux` and test its executable on a separate tmux socket.
3. Create `~/.config/tmux/use-system` to make the managed launcher prefer the
   Homebrew/system binary. Remove this marker to select the patched build again.
4. Restart the production server at a deliberate stopping point. Installing a
   binary does not upgrade the running server.

## Validation and sources

Run `python3 -m unittest discover -s tests -p 'test_tmux*.py'`. Test a real save and
isolated restore after changing the helper or CLI versions. The initial integration
was tested with live exact-ID discovery and an isolated plugin restore that skipped
an already-running conversation; a full reboot was not part of that test.

- [Tmux redraw report and maintainer backport](https://github.com/tmux/tmux/issues/5510)
- [Mainline fix](https://github.com/tmux/tmux/commit/c93e2f233206780ec1e2f0409c92326d06496a2d)
- [Pinned stable branch](https://github.com/tmux/tmux/tree/e9634d40749a5ae330aabf5aa46a81505b094a6b)
- [Resurrect program restoration](https://github.com/tmux-plugins/tmux-resurrect/blob/master/docs/restoring_programs.md)
- [Continuum scheduling](https://github.com/tmux-plugins/tmux-continuum)
- [Claude CLI resume](https://code.claude.com/docs/en/cli-reference)
- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
