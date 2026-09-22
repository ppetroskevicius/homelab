# Alacritty

Terminal emulator. Built **from source on every platform**, pinned to a release
tag. Config is managed by chezmoi.

| | |
|---|---|
| Pinned version | `alacritty_version` in [`ansible/roles/desktop/defaults/main.yml`](../ansible/roles/desktop/defaults/main.yml) |
| Install/upgrade | [`ansible/roles/desktop/tasks/alacritty.yml`](../ansible/roles/desktop/tasks/alacritty.yml) |
| Config (source) | `chezmoi/dot_config/alacritty/alacritty.toml.tmpl` |
| Config (deployed) | `~/.config/alacritty/alacritty.toml` |
| Themes | `~/.config/alacritty/themes` — cloned by `chezmoi/run_once_alacritty_themes.sh` |

---

## Why we build from source

The Homebrew cask was **disabled on 2026-09-01**:

```
$ brew info --cask alacritty
disabled: True   disable_reason: fails_gatekeeper_check
```

Upstream ships macOS builds that are ad-hoc signed only — no Apple Developer ID
and no notarization:

```
$ codesign -dv /Applications/Alacritty.app
Signature=adhoc
TeamIdentifier=not set
$ spctl -a -t install /Applications/Alacritty.app
rejected
```

Homebrew's cask policy now requires artifacts to pass Gatekeeper, so the cask
was dropped. **This is a packaging-policy outcome, not a malware finding.** It
will not return unless upstream starts notarizing.

`brew upgrade` will keep printing this warning forever; it is not actionable:

```
Warning: Not upgrading alacritty, it is disabled because it does not pass
the macOS Gatekeeper check! It was disabled on 2026-09-01.
```

### Is it safe?

Yes, with the tradeoff stated plainly. Losing notarization means losing Apple's
malware scan, an accountable Developer ID, and Apple's ability to revoke a
compromised build — a supply-chain concern about *prebuilt binaries*.

Building from source addresses exactly that: we build a **pinned release tag**
and cargo verifies every dependency against `Cargo.lock` hashes, so no opaque
prebuilt artifact is trusted. That is a better posture than the cask provided.

A locally built bundle also never carries `com.apple.quarantine`, so Gatekeeper
does not gate it — which is what removes the need for notarization in the first
place.

---

## Upgrading

Upstream releases are infrequent (0.16.1 → 0.17.0 spanned Oct 2025 → Apr 2026).

**1. Check for a new release**

```bash
gh api repos/alacritty/alacritty/releases/latest --jq .tag_name
```

**2. Bump the pin** in `ansible/roles/desktop/defaults/main.yml`:

```yaml
alacritty_version: "0.17.0"   # <- new version, no leading "v"
```

**3. Apply**

```bash
cd ansible
ansible-playbook -i inventory.yaml site.yml --limit <host> --tags alacritty
```

`alacritty` is the **only tag in this repo** — it exists specifically so a
version bump can be applied without a full desktop run. Drop `--tags` to run
everything.

Dry-run first to see the decision without building:

```bash
ansible-playbook -i inventory.yaml site.yml --limit <host> --tags alacritty --check
```

It prints e.g. `Alacritty 0.17.0 -> target 0.18.0 (building)`. The play compares
the installed `alacritty --version` against the pin and only builds on mismatch,
so re-running is cheap. Expect a few minutes of compile when it does build.

**4. Restart Alacritty.** On macOS the running process keeps its old bundle
inode, so a running terminal survives the swap but keeps the old binary until
relaunched.

### Safety properties worth preserving

Two things in the play are deliberate and easy to break by "simplifying":

- **The version comparison parses the version, it does not substring-match.**
  `"0.18.1" in "alacritty 0.18.10"` is `True`, so a substring test would report
  "up to date" for the wrong version and skip the build with no error.
- **The build is verified before the installed app is deleted.** `make app` can
  exit 0 with a broken bundle (the Makefile `@`-prefixes its `scdoc`/`tic`
  steps), and the delete is irreversible. The gate turns "no terminal on the
  machine" into an ordinary failed play.

### Do not use a `creates:` guard

The previous Linux task guarded the build with
`creates: ~/.cargo/bin/alacritty`. That fires once and never again, so Linux
silently froze at whatever version it first installed. Version comparison is
what makes upgrades actually happen — keep it that way.

---

## What the play does

Both platforms clone `v{{ alacritty_version }}` at depth 1 and build from it.

**macOS** — `make app` produces a native arm64 bundle at
`target/release/osx/Alacritty.app`, which is copied to `/Applications`.

`make app-universal` is deliberately *not* used: it additionally needs the
`x86_64-apple-darwin` rustup target and builds twice to `lipo` a fat binary,
which is pointless on a single Apple Silicon machine.

Ordering is deliberate — build, then `brew uninstall --cask`, then install:
the cask owns both `/Applications/Alacritty.app` and the `~/.terminfo/61/*`
symlinks, so untracking it removes both. Building first keeps the window with
no terminal on disk as short as possible. (Uninstall still works on a disabled
cask; only install/upgrade are blocked.)

The play then recreates the `~/.terminfo/61/alacritty{,-direct}` symlinks that
the cask used to provide.

**Linux** — `cargo install --path alacritty --locked --force`. The `--force` is
required, otherwise cargo refuses to overwrite the existing binary on a version
bump. Terminfo is installed system-wide with `tic`.

### Build dependencies

| Platform | Deps | Provided by |
|---|---|---|
| macOS | `scdoc` (manpages), `tic` + `lipo` (ship with macOS), Rust | `community.general.homebrew` in the play; Rust from `dev_languages` role |
| Linux | `alacritty_build_deps_debian` in `defaults/main.yml` | `apt` in the play |

The `dev_languages` role runs **first** in `site.yml` and provides the Rust
toolchain both paths rely on.

---

## Configuration

Managed by chezmoi at `chezmoi/dot_config/alacritty/alacritty.toml.tmpl`. Edit
the **template**, not `~/.config/alacritty/alacritty.toml` — `chezmoi apply`
overwrites the deployed file.

```bash
chezmoi diff ~/.config/alacritty/alacritty.toml   # check for drift
chezmoi apply                                      # deploy
```

`shell.program` uses the managed `~/.local/bin/tmux` launcher. See
[tmux recovery](TMUX_RECOVERY.md) for its patched build and Homebrew fallback.

Themes come from the `alacritty/alacritty-theme` repo, cloned once by
`chezmoi/run_once_alacritty_themes.sh`. `general.import` in the config depends
on that clone existing.

---

## Alternatives considered

If upstream's signing situation ever becomes a blocker, **Ghostty** is the
natural fallback: notarized, in Homebrew, self-updating (`auto_updates`). It
would need a config migration (keybinds, font, opacity, tmux-as-shell) and a
new chezmoi template. Not currently needed — building from source works and has
better provenance.

## Opening terminal links

On macOS, these bindings open Google Chrome:

| Gesture | Target |
|---|---|
| Cmd+Shift-click | Full HTTP(S) URL, embedded hyperlink, or `owner/repo#123` |
| Cmd+Shift+O, then type the displayed hint letters | Choose a visible link without the mouse |
| Option-click on `#123` | Issue or PR in the clicked tmux pane's GitHub repository |

Shift lets Alacritty handle a click even when tmux captures mouse events; see
[Alacritty hints documentation](https://alacritty.org/config-alacritty.html#hints).
Embedded hyperlinks also need tmux's `hyperlinks` terminal feature, configured
for Alacritty and xterm-256color. Existing clients may need to detach and reattach
once after enabling that feature. The server and conversations keep running.

The managed `open-terminal-link` helper resolves bare numbers using the clicked
pane's working directory and its `origin` remote, including Git worktrees. GitHub
issues and PRs share numbering; GitHub redirects the issue route for PR numbers.
If the pane is outside a GitHub checkout, use a full URL or `owner/repo#123`.
References to a different repository must also be qualified. Ticket keys from
other trackers and numbers without `#` need a full URL.

Option-click also recognizes embedded hyperlinks. Tmux word selection uses spaces
as separators so double-clicking preserves complete URLs and `#references`.
Only HTTP(S) destinations are opened, and text is passed as a literal browser
argument. Linux uses Chrome/Chromium when installed, otherwise `xdg-open`;
substitute Super for Cmd and Alt for Option.

Validate resolution without opening a browser:

```bash
~/.local/bin/open-terminal-link --print-url 'example/repo#123'
~/.local/bin/open-terminal-link --print-url --cwd "$PWD" '#123'
python3 -m unittest discover -s tests -p 'test_terminal_links.py'
```
