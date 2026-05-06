#!/usr/bin/env bash
set -Eeuo pipefail

# macOS Homebrew developer-tool bootstrap.
# Installs tools, writes user-level shell PATH/init blocks, then verifies commands.
# Usage:
#   chmod +x install-dev-tools.sh
#   ./install-dev-tools.sh              # install + configure + verify
#   ./install-dev-tools.sh --verify-only
#   ./install-dev-tools.sh --install-only
#   ./install-dev-tools.sh --start-colima

INSTALL=1
CONFIGURE=1
VERIFY=1
START_COLIMA=0

for arg in "$@"; do
  case "$arg" in
    --install-only)
      INSTALL=1
      CONFIGURE=1
      VERIFY=0
      ;;
    --verify-only)
      INSTALL=0
      CONFIGURE=0
      VERIFY=1
      ;;
    --start-colima)
      START_COLIMA=1
      ;;
    -h|--help)
      sed -n '1,22p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is intended for macOS." >&2
  exit 1
fi

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '\033[0;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[0;31mFAIL\033[0m %s\n' "$*"; }
warn() { printf '\033[0;33mWARN\033[0m %s\n' "$*"; }

require_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi
  echo "Homebrew is not installed or not on PATH. Install Homebrew first: https://brew.sh" >&2
  exit 1
}

require_brew
BREW_PREFIX="$(brew --prefix)"
BREW_BIN="$BREW_PREFIX/bin/brew"

FORMULAE=(
  atuin
  bat
  btop
  colima
  docker
  eza
  fd
  fzf
  git-delta
  difftastic
  direnv
  just
  lazygit
  lnav
  lychee
  mise
  mysql-client
  neovim
  pnpm
  ripgrep
  ripgrep-all
  semgrep
  shellcheck
  shfmt
  starship
  stripe/stripe-cli/stripe
  tldr
  tmux
  watchexec
  yazi
  yq
  zoxide
  zsh-autosuggestions
  zsh-syntax-highlighting
  bats-core
  actionlint
)

CASKS=(
  copilot-cli
)

install_formulae() {
  log "Updating Homebrew metadata"
  brew update

  log "Installing formulae"
  local formula
  for formula in "${FORMULAE[@]}"; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
      ok "$formula already installed"
    else
      brew install "$formula"
    fi
  done

  log "Installing casks"
  local cask
  for cask in "${CASKS[@]}"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      ok "$cask already installed"
    else
      brew install --cask "$cask"
    fi
  done

  if (( START_COLIMA )); then
    log "Starting Colima Docker runtime"
    colima start || warn "Colima failed to start. Check: colima status"
  fi
}

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  cp "$file" "$file.backup-$stamp"
}

replace_marked_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local block="$4"

  mkdir -p "$(dirname "$file")"
  touch "$file"
  backup_file "$file"

  local tmp
  tmp="$(mktemp)"

  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    skip != 1 {print}
  ' "$file" > "$tmp"

  {
    sed '${/^$/d;}' "$tmp"
    printf '\n%s\n%s\n%s\n' "$start_marker" "$block" "$end_marker"
  } > "$file"

  rm -f "$tmp"
}

configure_shell() {
  log "Writing PATH and shell integration blocks"

  local zprofile_block zshrc_block bash_profile_block bashrc_block

  zprofile_block=$(cat <<'BLOCK'
# Homebrew shellenv: supports Apple Silicon (/opt/homebrew) and Intel (/usr/local).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# mysql-client is keg-only in Homebrew, so expose its binaries explicitly.
if command -v brew >/dev/null 2>&1 && brew --prefix mysql-client >/dev/null 2>&1; then
  MYSQL_CLIENT_HOME="$(brew --prefix mysql-client)"
  case ":$PATH:" in
    *":$MYSQL_CLIENT_HOME/bin:"*) ;;
    *) export PATH="$MYSQL_CLIENT_HOME/bin:$PATH" ;;
  esac
fi

# pnpm global binaries.
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
BLOCK
)

  zshrc_block=$(cat <<'BLOCK'
# Homebrew zsh completions.
if command -v brew >/dev/null 2>&1; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
fi

# Prompt, shell history, environment hooks, runtime shims, navigation.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# fzf key bindings and completion. Newer fzf supports --zsh; fallback keeps older Homebrew layouts working.
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)" 2>/dev/null || {
    [ -f "$(brew --prefix)/opt/fzf/shell/completion.zsh" ] && source "$(brew --prefix)/opt/fzf/shell/completion.zsh"
    [ -f "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh" ] && source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
  }
fi

# Zsh plugins from Homebrew.
if command -v brew >/dev/null 2>&1; then
  ZSH_AUTOSUGGESTIONS="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_SYNTAX_HIGHLIGHTING="$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  [ -f "$ZSH_AUTOSUGGESTIONS" ] && source "$ZSH_AUTOSUGGESTIONS"
  [ -f "$ZSH_SYNTAX_HIGHLIGHTING" ] && source "$ZSH_SYNTAX_HIGHLIGHTING"
fi
BLOCK
)

  bash_profile_block=$(cat <<'BLOCK'
# Homebrew shellenv: supports Apple Silicon (/opt/homebrew) and Intel (/usr/local).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# mysql-client is keg-only in Homebrew, so expose its binaries explicitly.
if command -v brew >/dev/null 2>&1 && brew --prefix mysql-client >/dev/null 2>&1; then
  MYSQL_CLIENT_HOME="$(brew --prefix mysql-client)"
  case ":$PATH:" in
    *":$MYSQL_CLIENT_HOME/bin:"*) ;;
    *) export PATH="$MYSQL_CLIENT_HOME/bin:$PATH" ;;
  esac
fi

# pnpm global binaries.
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
BLOCK
)

  bashrc_block=$(cat <<'BLOCK'
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)" 2>/dev/null || true
BLOCK
)

  replace_marked_block "$HOME/.zprofile" \
    "# >>> dev-tools bootstrap >>>" \
    "# <<< dev-tools bootstrap <<<" \
    "$zprofile_block"

  replace_marked_block "$HOME/.zshrc" \
    "# >>> dev-tools interactive zsh >>>" \
    "# <<< dev-tools interactive zsh <<<" \
    "$zshrc_block"

  replace_marked_block "$HOME/.bash_profile" \
    "# >>> dev-tools bootstrap >>>" \
    "# <<< dev-tools bootstrap <<<" \
    "$bash_profile_block"

  replace_marked_block "$HOME/.bashrc" \
    "# >>> dev-tools interactive bash >>>" \
    "# <<< dev-tools interactive bash <<<" \
    "$bashrc_block"

  ok "Updated ~/.zprofile, ~/.zshrc, ~/.bash_profile, ~/.bashrc"
}

check_cmd() {
  local label="$1"
  shift
  if "$@" >/tmp/dev-tools-check.out 2>/tmp/dev-tools-check.err; then
    local first_line
    first_line="$(head -n 1 /tmp/dev-tools-check.out 2>/dev/null || true)"
    [[ -n "$first_line" ]] && ok "$label: $first_line" || ok "$label"
  else
    fail "$label"
    sed 's/^/  /' /tmp/dev-tools-check.err >&2 || true
    return 1
  fi
}

verify_tools() {
  log "Verifying command availability in a fresh zsh login shell"

  local verify_script
  verify_script=$(mktemp)
  cat > "$verify_script" <<'VERIFY'
set -u
failures=0

check() {
  label="$1"
  shift
  if "$@" >/tmp/dev-tools-check.out 2>/tmp/dev-tools-check.err; then
    first_line="$(head -n 1 /tmp/dev-tools-check.out 2>/dev/null || true)"
    if [ -n "$first_line" ]; then
      printf 'PASS %s: %s\n' "$label" "$first_line"
    else
      printf 'PASS %s\n' "$label"
    fi
  else
    printf 'FAIL %s\n' "$label"
    sed 's/^/  /' /tmp/dev-tools-check.err >&2 || true
    failures=$((failures + 1))
  fi
}

check atuin atuin --version
check bat bat --version
check btop btop --version
check colima colima version
check docker docker --version
check eza eza --version
check fd fd --version
check fzf fzf --version
check delta delta --version
check difftastic difft --version
check direnv direnv --version
check copilot-cli copilot --version
check just just --version
check lazygit lazygit --version
check lnav lnav --version
check lychee lychee --version
check mise mise --version
check mysql-client mysql --version
check neovim nvim --version
check pnpm pnpm --version
check ripgrep rg --version
check ripgrep-all rga --version
check semgrep semgrep --version
check shellcheck shellcheck --version
check shfmt shfmt --version
check starship starship --version
check stripe stripe --version
check tldr tldr --version
check tmux tmux -V
check watchexec watchexec --version
check yazi yazi --version
check yq yq --version
check zoxide zoxide --version
check bats-core bats --version
check actionlint actionlint --version

if command -v brew >/dev/null 2>&1; then
  test -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" && printf 'PASS zsh-autosuggestions file exists\n' || { printf 'FAIL zsh-autosuggestions file missing\n'; failures=$((failures + 1)); }
  test -f "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" && printf 'PASS zsh-syntax-highlighting file exists\n' || { printf 'FAIL zsh-syntax-highlighting file missing\n'; failures=$((failures + 1)); }
fi

exit "$failures"
VERIFY

  if zsh -lic "source '$verify_script'"; then
    ok "All verification checks passed"
  else
    local status=$?
    fail "$status verification check(s) failed"
    rm -f "$verify_script"
    exit "$status"
  fi

  rm -f "$verify_script"
}

if (( INSTALL )); then
  install_formulae
fi

if (( CONFIGURE )); then
  configure_shell
fi

if (( VERIFY )); then
  verify_tools
fi

log "Done"
printf 'Open a new terminal, or run: exec zsh -l\n'
