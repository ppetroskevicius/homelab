# AeroSpace Cheat Sheet

Modifier: **Alt (Option)**

## Navigation

| Shortcut | Action |
|----------|--------|
| `alt-h` | Focus left |
| `alt-j` | Focus down |
| `alt-k` | Focus up |
| `alt-l` | Focus right |
| `alt-space` | Focus back-and-forth |

## Move Windows

| Shortcut | Action |
|----------|--------|
| `alt-shift-h` | Move window left |
| `alt-shift-j` | Move window down |
| `alt-shift-k` | Move window up |
| `alt-shift-l` | Move window right |

## Layout

| Shortcut | Action |
|----------|--------|
| `alt-f` | Toggle fullscreen |
| `alt-shift-space` | Toggle floating/tiling |
| `alt-b` | Join with left (group horizontally) |
| `alt-v` | Join with down (group vertically) |
| `alt-/` | **Cycle tiles layout** |
| `alt-,` | Cycle accordion layout |

## Workspaces

| Shortcut | Action |
|----------|--------|
| `alt-1` to `alt-9` | Switch to workspace 1-9 (focuses assigned monitor) |
| `alt-shift-1` to `alt-shift-9` | Move window to workspace 1-9 |
| `alt-tab` | Workspace back-and-forth |

## Multi-Monitor

| Shortcut | Action |
|----------|--------|
| `alt-shift-tab` | Move workspace to next monitor |
| `alt-shift-[` | Focus previous monitor |
| `alt-shift-]` | Focus next monitor |

## App Launchers

| Shortcut | Action |
|----------|--------|
| `alt-enter` | Open Alacritty |
| `alt-g` | Open Google Chrome |
| `alt-c` | Open VS Code |
| `alt-s` | Open Slack |
| `alt-a` | Open Claude Desktop |
| `alt-n` | Open Notion |
| `alt-shift-q` | Close window |

## Resize Mode

| Shortcut | Action |
|----------|--------|
| `alt-x` | **Enter resize mode** |
| `h` | Shrink width |
| `l` | Grow width |
| `k` | Shrink height |
| `j` | Grow height |
| `esc` / `enter` | **Exit resize mode** |

## Config Management

| Shortcut | Action |
|----------|--------|
| `alt-shift-c` | Reload AeroSpace config |

CLI: `aerospace reload-config`

## macOS Shortcuts

| Shortcut | Action |
|----------|--------|
| `ctrl-cmd-f` | Toggle native macOS fullscreen |

## Auto-Assign Rules

Apps are automatically moved to their assigned workspace on open:

| App | Workspace | Rule |
|-----|-----------|------|
| Slack | S | `com.tinyspeck.slackmacgap` |
| Notion | N | `notion.id` |
| Claude Desktop | A | `com.anthropic.claudefordesktop` |
| VS Code | E | `com.microsoft.VSCode` |
| Cursor | E | `com.todesktop.230313mzl4w4u92` |
| Alacritty | T | app-name regex `alacritty` (also forced tiling) |
| Google Chrome | G | `com.google.Chrome` |
| Obsidian | O | `md.obsidian` |
| DataGrip | D | `com.jetbrains.datagrip` |
| IntelliJ | I | `com.jetbrains.intellij` |
| Spotify | M | `com.spotify.client` |
| Figma | P | `com.figma.Desktop` |
| Rancher Desktop | R | `io.rancherdesktop.app` |

## Floating Apps

| App | Behavior |
|-----|----------|
| System Settings | Auto-float |
| Cisco VPN | Auto-float |
| Preview | Auto-float |
| Finder | Auto-float |
| 1Password | Auto-float |

---

## Monitor Profiles

AeroSpace doesn't support conditional config or per-location profiles natively.
A profile system is set up using `aerospace-profile` to swap between 4 location configs.

### File Structure

```
~/.config/aerospace/
├── base.toml              # Shared config (keybindings, gaps, window rules)
├── monitors-home.toml     # Home monitor assignments
├── monitors-office.toml   # Office monitor assignments
├── monitors-villa.toml    # Villa monitor assignments
└── monitors-cafe.toml     # Cafe (laptop only, no assignments)

~/.aerospace.toml          # Generated file (base.toml + selected profile)
~/.local/bin/aerospace-profile  # Switcher script
```

> **Do not edit `~/.aerospace.toml` directly** — it is regenerated on every profile switch.
> Edit `~/.config/aerospace/base.toml` for shared settings, or the `monitors-*.toml` files for monitor layouts.

### Usage

```bash
aerospace-profile home     # Switch to home layout
aerospace-profile office   # Switch to office layout
aerospace-profile villa    # Switch to villa layout
aerospace-profile cafe     # Switch to cafe layout
aerospace-profile          # Show available profiles and current selection
```

The script concatenates `base.toml` + the selected monitor file into `~/.aerospace.toml` and runs `aerospace reload-config`.

### Workspace Assignments by Location

#### Home — Mac (left) + Dell U4323QE 43" vertical (center) + LG 43" horizontal (right)

| Monitor | Workspaces | Purpose |
|---------|------------|---------|
| Mac (left) | 1, 2, 3, M | Scratch + Spotify (privacy filter screen) |
| Dell (center, vertical) | 7, 8, 9, E, S | Scratch + editor (VS Code/Cursor) + Slack |
| LG (right) | 4, 5, 6, G, N, A, T, W, O, D, I, P, R | Scratch + remaining app workspaces |

#### Office — Mac (left) + Dell 36" (right)

| Monitor | Workspaces | Purpose |
|---------|------------|---------|
| Mac (left) | 1, 2, 3 | Comms, secondary |
| Dell (right) | 4, 5, 6, 7, 8, 9 | Main work |

#### Villa — Mac (left) + LG 43" horizontal (right)

| Monitor | Workspaces | Purpose |
|---------|------------|---------|
| Mac (left) | 1, 2, 3 | Comms, secondary |
| LG (right) | 4, 5, 6, 7, 8, 9 | Main work |

#### Cafe — Mac only

All workspaces on the built-in display. No forced assignments.
