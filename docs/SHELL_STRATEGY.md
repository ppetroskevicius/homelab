# Shell Strategy

We want to implify our shell management (Zsh vs. Bash), and implement the `direnv` workflow.

### 2. Shell Strategy: Zsh vs. Bash

**The Strategy:**

1. **Desktops (`dt-dev`):** Use **Zsh**. This is your "cockpit" where you want autocomplete, themes, and plugins.
2. **Servers/VMs/Containers:** Stick to **Bash**.

- **Why?** It is standard. Installing Zsh + OhMyZsh on ephemeral Kubernetes nodes or throwaway containers is "pet" management. It adds noise to your Ansible scripts and increases build times for containers.
- **Maintenance:** Your current setup with `common.sh` is actually excellent. It allows you to have a single "core" config that works everywhere, while keeping the "fancy" stuff restricted to your desktop Zsh.

---

### 3. Startup Files: The "Cleanup"

Here is the mystery of `.zprofile` vs `.zshrc` solved, and how to refactor your `common.sh`.

#### The Rules

- **`.zprofile` (Login):** Runs **once** when you log in.
- _Put here:_ Environment variables that rarely change (`PATH`, `EDITOR`, `LANG`).

- **`.zshrc` (Interactive):** Runs **every time** you open a new terminal tab.
- _Put here:_ Aliases, prompt setup (Starship), shell history options, key bindings, and `direnv hook`.
- _Why?_ If you put `export PATH` here, every sub-shell keeps pre-pending the same paths, making your `$PATH` messy.

#### Refactoring Your Files

**A. `~/.config/shell/common.sh` (Refactored)**
_Remove the heavy 1Password injection. Keep it lightweight._

```bash
# Refactored common.sh
# ... (Keep your existing checks and PATH exports) ...

# 1. REMOVE THIS BLOCK entirely:
# if [ -z "${OP_SERVICE_ACCOUNT_TOKEN-}" ] ...
#   eval "$(op inject ...)"
# fi

# 2. KEEP simple exports
export EDITOR='vim'
export CLICOLOR=1

# 3. KEEP functions
add_to_path() { [ -d "$1" ] && PATH="$1:$PATH"; }

# ... (Keep PATH setup, Java, NVM, etc.) ...

```

**B. `~/.zprofile**`
_Load the environment once._

```bash
#
# Load common environment variables
[ -f "$HOME/.config/shell/common.sh" ] && . "$HOME/.config/shell/common.sh"

```

**C. `~/.zshrc**`*Setup the interactive session and hook in`direnv`.\*

```bash
#
# ... (Keep Oh My Zsh plugins) ...

# 1. Initialize direnv (The replacement for your global exports)
eval "$(direnv hook zsh)"

# 2. Starship (Prompt)
eval "$(starship init zsh)"

# 3. Aliases
alias k="kubectl"
alias tf="terraform"

```

**D. `~/.bashrc` (For Servers/Containers)**
_Minimal setup for when you SSH into servers._

```bash
#
# Load common environment
[ -f "$HOME/.config/shell/common.sh" ] && . "$HOME/.config/shell/common.sh"

# Hook direnv (useful if you enter a folder on a server with an .envrc)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

# Basic prompt if Starship isn't there
if ! command -v starship >/dev/null 2>&1; then
  PS1='\u@\h:\w\$ '
fi

```

---

### 4. Implementation Steps

1. **Install `direnv`:**

- MacOS: `brew install direnv`
- Linux: `apt install direnv` (or via your Ansible playbooks).

2. **Delete** the `op.env.exports.tpl` file. You won't need it anymore.

3. **Create your first `.envrc`:**
   Go to one of your project folders (e.g., `~/code/my-k8s-lab`) and run:

```bash
echo 'export AWS_ACCESS_KEY_ID=$(op read op://build/aws-access-key/credential)' >> .envrc
direnv allow

```

4. **Test:**

- Open a new terminal. `echo $AWS_ACCESS_KEY_ID` should be empty (fast startup!).
- `cd` into the project folder. You will see `direnv: loading...`.
- `echo $AWS_ACCESS_KEY_ID` will now show the key.

---

This is the correct direction. You are moving towards a "Clean Architecture" for your shell.

To answer your specific questions:

1. **Should you stop including `profile` inside `rc` (or vice-versa)?**

- **Yes.** Ideally, they should be distinct.
- **The Catch (MacOS vs. Linux):**
- **On Linux Desktops:** You log in once (GUI), which reads `.zprofile` (setting PATHs globally). When you open Alacritty, it runs `.zshrc` (Interactive). They are naturally separated.
- **On MacOS:** Every single terminal tab you open runs as a **Login Shell** by default. This means it reads `.zprofile` _and_ `.zshrc` every time.

- **The Fix:** Even though MacOS blurs the lines, maintaining strict separation is best practice. It prevents "path explosion" (where your PATH variable gets `:/usr/bin:/usr/bin:/usr/bin` appended 5 times).

2. **Are there benefits to "Zsh-isms" (rewriting code in Zsh)?**

- **Speed:** Negligible for simple variable setting. POSIX `export FOO="bar"` is fast enough.
- **Power:** Yes. Zsh handling of arrays and globbing is vastly superior to Bash.
- **Verdict:** Keep `common.sh` as **POSIX** (portable). It allows you to share your complex logic (like that `gset` function or PATH construction) across both Bash (servers) and Zsh (desktop) without rewriting it twice.

Here is your optimized, decoupled architecture.

### 1. The Strategy: "Load Once, Run Everywhere"

We will stop cross-sourcing.

- **Profile:** Sets the stage (Environment Variables).
- **RC:** Sets the scene (Prompts, Aliases, Tools).

### 2. The Refactored Files

#### A. `common.sh` (The Shared Core)

_Keep this POSIX compliant. It is the only file that exists on both Desktops and Servers._

```bash
# ~/.config/shell/common.sh
# POSIX COMPLIANT - Sourced by both Bash and Zsh

# 1. Path Management (Idempotent - prevents duplicates)
add_to_path() {
  case ":$PATH:" in
    *":$1:"*) ;;         # Already in path, do nothing
    *) PATH="$1:$PATH" ;; # Add if missing
  esac
}

# 2. Global Environment Variables
export EDITOR='vim'
export CLICOLOR=1
export LANG=en_US.UTF-8

# 3. Setup Paths
add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"
add_to_path "/usr/local/go/bin"
# ... add your other paths here ...

export PATH

```

---

#### B. `~/.zprofile` (Desktop Login - Zsh)

_Runs once per login (Linux) or per tab (MacOS). Only loads the environment._

```zsh
# ~/.zprofile

# 1. Load the shared environment
[ -f "$HOME/.config/shell/common.sh" ] && . "$HOME/.config/shell/common.sh"

# 2. Zsh-specific environment variables (that Bash doesn't need)
# e.g., History file location
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=50000
export SAVEHIST=10000

```

---

#### C. `~/.zshrc` (Desktop Interactive - Zsh)

_Runs when you open a terminal. Heavy UI lifting._

```zsh
# ~/.zshrc

# 1. Oh-My-Zsh / Plugin Manager
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions terraform kubectl)
source $ZSH/oh-my-zsh.sh

# 2. Interactive-only Tools
# direnv: Loads secrets just-in-time
eval "$(direnv hook zsh)"

# Starship: The prompt
eval "$(starship init zsh)"

# 3. Aliases (Zsh-isms allowed here)
alias k="kubectl"
alias ll="ls -lh"

# 4. Bindings
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

```

---

#### D. `~/.bash_profile` (Server Login - Bash)

_This is all you need on your VMs. It mirrors zprofile._

```bash
# ~/.bash_profile

# 1. Load shared environment
[ -f "$HOME/.config/shell/common.sh" ] && . "$HOME/.config/shell/common.sh"

# 2. Source bashrc if this is also an interactive shell (SSH login)
if [[ $- == *i* ]]; then
    [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
fi

```

#### E. `~/.bashrc` (Server Interactive - Bash)

_Minimalist. No plugins. Just pure utility._

```bash
# ~/.bashrc

# 1. If not running interactively, don't do anything
[[ $- != *i* ]] && return

# 2. Basic History Control
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=1000
export HISTFILESIZE=2000

# 3. Enable direnv (Vital for your secrets management on servers)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

# 4. Simple Prompt (Fallback if Starship isn't installed)
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
else
  # A useful, colorful prompt for servers
  PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
fi

# 5. Essential Aliases
alias ll='ls -alF'

```

### 3. Summary of Changes

1. **Decoupled:** `.zshrc` no longer sources `.zprofile`. This makes debugging easier. If your PATH is wrong, you know it's `profile`. If your prompt is missing, it's `rc`.
2. **Bash Simplified:** The `bash` files are now stripped down to only what is needed for a server environment (SSH access).
3. **Idempotent PATH:** The `add_to_path` function in `common.sh` prevents the "infinite path growth" problem, regardless of how many times the files get sourced by MacOS.
4. **Zsh-isms:** We kept `common.sh` portable so you don't have to duplicate logic, but strictly used Zsh syntax in `zshrc` (like `plugins=(...)`) where it belongs.

---

You are absolutely right to question this. It highlights the critical difference between how we handle secrets on a **Secure Workstation** versus a **Remote Server**.

On servers, `direnv` works differently. It acts as a **static loader**, not a dynamic fetcher.

### The "Rendered vs. Dynamic" Strategy

The tool (`direnv`) is the same, but the content of the `.envrc` file is different depending on where it lives.

#### 1. On Your Desktop (`dt-dev`)

You use a **Dynamic** `.envrc`. The file contains instructions to _fetch_ the secret.

- **File Content:** `export DB_PASS=$(op read op://build/db/password)`
- **Mechanism:** When you `cd` into the folder, `direnv` runs the `op` command.
- **Security:** The secret is never stored on disk. It exists only in memory.

#### 2. On Your Servers (`vm-service`)

You use a **Static (Rendered)** `.envrc`. Since `op` is not installed, we cannot fetch secrets dynamically. instead, **Ansible** retrieves the secret on your desktop and writes the _actual value_ into the file on the server.

- **File Content:** `export DB_PASS="super-secret-password-123"`
- **Mechanism:** When you `cd` into the folder (e.g., to debug a service manually), `direnv` simply exports the variable.
- **Security:** The secret **is stored on disk** (readable only by root/owner).

### Why do we allow secrets on disk on Servers?

It is standard industry practice (like `wp-config.php` for WordPress or `/etc/default/postgresql`).

- **Physical Security:** Servers are in your locked home lab (or cloud VPC).
- **Access Control:** Only you (via SSH key) can access the file system.
- **Necessity:** Services need to start automatically on boot (unattended). They cannot wait for a human to scan a fingerprint.

### The Workflow

Here is how the secret travels without you ever copying it manually:

1. **1Password:** Holds the master secret.
2. **Desktop (Control Node):** You run Ansible.

- Ansible asks 1Password: "Give me the database password."
- 1Password (via Desktop App) asks for your fingerprint.
- Ansible gets the secret in memory.

3. **Ansible (Push):** Connects to `vm-service` via SSH.

- It creates `/opt/my-service/.envrc`.
- It writes the _plaintext_ password into that file.
- It sets permissions to `600` (read/write only by owner).

4. **Server (Runtime):**

- If the app runs as a systemd service, Ansible also copies the secret to the systemd unit file (EnvironmentFile).
- If **you** SSH in to debug and `cd /opt/my-service`, `direnv` (via `.bashrc`) loads that `.envrc` so you have the same environment as the app.

### Summary

- **Do we install 1Password on servers?** **No.**
- **Does direnv on servers talk to 1Password?** **No.**
- **Then why install direnv on servers?** To automatically load the **static** variables that Ansible placed there, giving you a consistent "developer experience" when you are debugging remote systems.
