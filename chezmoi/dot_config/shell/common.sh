# shellcheck shell=sh
# Common shell configuration (bash + zsh)
# Source this from .bashrc, .zshrc, etc.
# Make changes in portable sh-style syntax (shellcheck compatible)

if [ -n "${COMMON_SH_LOADED-}" ]; then
  return 0
fi
export COMMON_SH_LOADED=1

export EDITOR='vim'
export CLICOLOR=1

# Idempotent PATH addition - prevents duplicates
add_to_path() {
  case ":$PATH:" in
    *":$1:"*) ;;  # Already in PATH, skip
    *) [ -d "$1" ] && PATH="$1:$PATH" ;;
  esac
}

# Homebrew shellenv (macOS)
if [ "$(uname -s)" = "Darwin" ]; then
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

PATH="$HOME/bin:$HOME/.local/bin:$PATH"
add_to_path "$HOME/.npm-global/bin"
add_to_path "$HOME/.cargo/bin"
add_to_path "$HOME/.local/share/pnpm"
add_to_path "/opt/rocm-6.4.0/bin"
add_to_path "$HOME/.lmstudio/bin"
add_to_path "/usr/local/go/bin"
export PATH

export PNPM_HOME="$HOME/.local/share/pnpm"

# Desktop / hypervisor environment (Linux; optional)
if [ "$(uname -s)" = "Linux" ]; then
  if [ -e /var/run/libvirt/libvirt-sock ]; then
    export LIBVIRT_DEFAULT_URI="qemu:///system"
  fi

  if command -v sway >/dev/null 2>&1; then
    export XDG_CURRENT_DESKTOP=sway
    export MOZ_ENABLE_WAYLAND=1

    export XMODIFIERS=@im=fcitx
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
  fi
fi

# keychain (optional)
if command -v keychain >/dev/null 2>&1 && [ -f "$HOME/.ssh/id_ed25519" ]; then
  eval "$(keychain --eval --quiet id_ed25519)"
fi

# NVM (optional)
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  if [ -n "${BASH_VERSION-}" ] && [ -s "$NVM_DIR/bash_completion" ]; then
    . "$NVM_DIR/bash_completion"
  fi
fi

# Java (optional) — prefer asdf, fallback to Homebrew/system
if [ "$(uname -s)" = "Darwin" ]; then
  if command -v asdf >/dev/null 2>&1 && asdf which java >/dev/null 2>&1; then
    JAVA_HOME="$(dirname "$(dirname "$(asdf which java)")")"
  elif command -v brew >/dev/null 2>&1; then
    JAVA_HOME="$(brew --prefix)/opt/openjdk"
  fi
elif [ -d "/usr/lib/jvm/default-java" ]; then
  JAVA_HOME="/usr/lib/jvm/default-java"
fi
if [ -n "${JAVA_HOME-}" ]; then
  export JAVA_HOME
  PATH="$JAVA_HOME/bin:$PATH"
  export PATH
fi

# GCP helpers (optional)
if command -v gcloud >/dev/null 2>&1; then
  gset() {
    env=$1
    identity=${2:-owner}

    if [ -z "$env" ]; then
      echo "Usage: gset <env> [identity]"
      echo "  env: dev, test, prod"
      echo "  identity: owner, tf, sa (default: owner)"
      return 1
    fi

    case "$env" in
    dev | test | prod) ;;
    *)
      echo "Error: env must be one of: dev, test, prod"
      return 1
      ;;
    esac

    env_upper=$(printf '%s' "$env" | tr '[:lower:]' '[:upper:]')
    project_id_var="GCP_${env_upper}_PROJECT_ID"
    eval "project_id=\${$project_id_var}"
    if [ -z "$project_id" ]; then
      echo "Error: $project_id_var is not set"
      return 1
    fi

    if ! gcloud config configurations activate "$env" >/dev/null 2>&1; then
      echo "Error: failed to activate gcloud configuration '$env'"
      return 1
    fi
    gcloud auth application-default set-quota-project "$project_id" >/dev/null 2>&1

    case "$identity" in
    tf)
      sa_var="GCP_${env_upper}_TERRAFORM_SA"
      eval "sa_email=\${$sa_var}"
      if [ -z "$sa_email" ]; then
        echo "Error: $sa_var is not set"
        return 1
      fi
      gcloud config set auth/impersonate_service_account "$sa_email" >/dev/null 2>&1
      ;;
    sa)
      sa_var="GCP_${env_upper}_DEVELOPER_SA"
      eval "sa_email=\${$sa_var}"
      if [ -z "$sa_email" ]; then
        echo "Error: $sa_var is not set"
        return 1
      fi
      gcloud config set auth/impersonate_service_account "$sa_email" >/dev/null 2>&1
      ;;
    owner)
      gcloud config unset auth/impersonate_service_account >/dev/null 2>&1
      ;;
    *)
      echo "Error: unknown identity '$identity'"
      return 1
      ;;
    esac

    export GCP_ENV="$env"
    export GCP_IDENTITY="$identity"
  }
fi

# Git worktree helpers (requires: git; optional: fzf for gwl)
gwa() {
  # Create worktree: gwa <branch> [base-ref]
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "gwa: not a git repository" >&2; return 1
  fi
  if [ -z "$1" ]; then
    echo "Usage: gwa <branch> [base-ref]" >&2; return 1
  fi
  _branch="$1"; _base="${2:-HEAD}"
  _root=$(git rev-parse --show-toplevel)
  _wt_dir="${_root}/.worktrees/${_branch}"
  git worktree add "$_wt_dir" -b "$_branch" "$_base" && cd "$_wt_dir"
}

gwl() {
  # List worktrees; with fzf: interactive select + cd
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "gwl: not a git repository" >&2; return 1
  fi
  if command -v fzf >/dev/null 2>&1; then
    _selected=$(git worktree list | fzf --prompt="worktree> " --reverse)
    if [ -n "$_selected" ]; then
      cd "$(echo "$_selected" | awk '{print $1}')" || return 1
    fi
  else
    git worktree list
  fi
}

gwr() {
  # Remove worktree: gwr <branch-or-path>
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "gwr: not a git repository" >&2; return 1
  fi
  if [ -z "$1" ]; then
    echo "Usage: gwr <branch-or-path>" >&2
    git worktree list; return 1
  fi
  _target="$1"
  case "$_target" in
    */*) ;;  # path — use as-is
    *) _target="$(git rev-parse --show-toplevel)/.worktrees/${_target}" ;;
  esac
  git worktree remove "$_target"
}

