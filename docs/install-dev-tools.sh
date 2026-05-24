#!/usr/bin/env bash
set -Eeuo pipefail

# macOS Homebrew developer-tool bootstrap.
#
# Usage:
#   chmod +x install-dev-tools.sh
#   ./install-dev-tools.sh
#   ./install-dev-tools.sh --verify-only
#   ./install-dev-tools.sh --install-only
#   ./install-dev-tools.sh --skip-profiles
#   ./install-dev-tools.sh --start-colima
#
# Output:
#   ~/.dev-cli-tools/install-dev-tools.log
#   ~/.dev-cli-tools/install-dev-tools-report.md

INSTALL=1
CONFIGURE=1
VERIFY=1
START_COLIMA=0
SKIP_PROFILES=0

REPORT_DIR="${HOME}/.dev-cli-tools"
LOG_FILE="${REPORT_DIR}/install-dev-tools.log"
REPORT_MD="${REPORT_DIR}/install-dev-tools-report.md"

mkdir -p "$REPORT_DIR"
: > "$LOG_FILE"

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
  tlrc
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

CASKS=()

usage() {
  sed -n '1,24p' "$0"
}

log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$*" | tee -a "$LOG_FILE"
}

ok() {
  printf '\033[0;32mPASS\033[0m %s\n' "$*" | tee -a "$LOG_FILE"
}

warn() {
  printf '\033[0;33mWARN\033[0m %s\n' "$*" | tee -a "$LOG_FILE"
}

fail() {
  printf '\033[0;31mFAIL\033[0m %s\n' "$*" | tee -a "$LOG_FILE" >&2
}

die() {
  fail "$*"
  exit 1
}

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
    --skip-profiles)
      SKIP_PROFILES=1
      CONFIGURE=0
      ;;
    --start-colima)
      START_COLIMA=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $arg"
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This script is intended for macOS."
fi

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

  die "Homebrew is not installed or not on PATH. Install Homebrew first: https://brew.sh"
}

require_brew

BREW_PREFIX="$(brew --prefix)"
BREW_BIN="${BREW_PREFIX}/bin/brew"

backup_file() {
  local file="$1"

  [[ -f "$file" ]] || return 0

  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"

  cp "$file" "${file}.backup-${stamp}"
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
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$file" > "$tmp"

  {
    sed '${/^$/d;}' "$tmp"
    printf '\n%s\n%s\n%s\n' "$start_marker" "$block" "$end_marker"
  } > "$file"

  rm -f "$tmp"
}

install_formulae() {
  log "Updating Homebrew metadata"
  brew update

  log "Installing Homebrew formulae"

  local formula
  for formula in "${FORMULAE[@]}"; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
      ok "$formula already installed"
    else
      log "Installing formula: $formula"
      brew install "$formula"
    fi
  done

  log "Installing Homebrew casks"

  local cask
  for cask in "${CASKS[@]}"; do
    if brew list --cask "$cask" >/dev/null 2>&1; then
      ok "$cask already installed"
    else
      log "Installing cask: $cask"
      brew install --cask "$cask"
    fi
  done

  if (( START_COLIMA )); then
    log "Starting Colima Docker runtime"
    if colima start; then
      ok "Colima started"
    else
      warn "Colima failed to start. Check: colima status"
    fi
  fi
}

configure_shell() {
  if (( SKIP_PROFILES )); then
    warn "Profile configuration skipped"
    return 0
  fi

  log "Writing shell integration blocks"

  local zprofile_block
  local zshrc_block
  local bash_profile_block
  local bashrc_block

  zprofile_block="$(cat <<'BLOCK'
# Homebrew shellenv: Apple Silicon and Intel.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# mysql-client is keg-only in Homebrew.
if command -v brew >/dev/null 2>&1 && brew --prefix mysql-client >/dev/null 2>&1; then
  MYSQL_CLIENT_HOME="$(brew --prefix mysql-client)"
  case ":$PATH:" in
    *":$MYSQL_CLIENT_HOME/bin:"*) ;;
    *) export PATH="$MYSQL_CLIENT_HOME/bin:$PATH" ;;
  esac
  unset MYSQL_CLIENT_HOME
fi

# pnpm global binaries.
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
BLOCK
)"

  zshrc_block="$(cat <<'BLOCK'
# Homebrew zsh completions.
if command -v brew >/dev/null 2>&1; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
fi

# Prompt, history, env hooks, runtime shims, navigation.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# fzf key bindings and completion.
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)" 2>/dev/null || {
    if command -v brew >/dev/null 2>&1; then
      [ -f "$(brew --prefix)/opt/fzf/shell/completion.zsh" ] && source "$(brew --prefix)/opt/fzf/shell/completion.zsh"
      [ -f "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh" ] && source "$(brew --prefix)/opt/fzf/shell/key-bindings.zsh"
    fi
  }
fi

# Zsh plugins from Homebrew.
if command -v brew >/dev/null 2>&1; then
  ZSH_AUTOSUGGESTIONS="$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  ZSH_SYNTAX_HIGHLIGHTING="$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

  [ -f "$ZSH_AUTOSUGGESTIONS" ] && source "$ZSH_AUTOSUGGESTIONS"
  [ -f "$ZSH_SYNTAX_HIGHLIGHTING" ] && source "$ZSH_SYNTAX_HIGHLIGHTING"

  unset ZSH_AUTOSUGGESTIONS
  unset ZSH_SYNTAX_HIGHLIGHTING
fi
BLOCK
)"

  bash_profile_block="$(cat <<'BLOCK'
# Homebrew shellenv: Apple Silicon and Intel.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# mysql-client is keg-only in Homebrew.
if command -v brew >/dev/null 2>&1 && brew --prefix mysql-client >/dev/null 2>&1; then
  MYSQL_CLIENT_HOME="$(brew --prefix mysql-client)"
  case ":$PATH:" in
    *":$MYSQL_CLIENT_HOME/bin:"*) ;;
    *) export PATH="$MYSQL_CLIENT_HOME/bin:$PATH" ;;
  esac
  unset MYSQL_CLIENT_HOME
fi

# pnpm global binaries.
export PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
BLOCK
)"

  bashrc_block="$(cat <<'BLOCK'
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)" 2>/dev/null || true
fi
BLOCK
)"

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

write_report_header() {
  {
    printf '# macOS Dev CLI Verification Report\n\n'
    printf -- '- Generated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Homebrew prefix: %s\n\n' "$BREW_PREFIX"
    printf '| Status | Tool | Command | Version / First output |\n'
    printf '|---|---|---|---|\n'
  } > "$REPORT_MD"
}

append_report_row() {
  local status="$1"
  local label="$2"
  local command_text="$3"
  local output_text="${4:-}"

  output_text="$(printf '%s' "$output_text" | tr '\n' ' ' | sed 's/|/\\|/g')"

  printf '| %s | %s | `%s` | %s |\n' \
    "$status" \
    "$label" \
    "$command_text" \
    "$output_text" >> "$REPORT_MD"
}

verify_tools() {
  log "Verifying command availability in a fresh zsh login shell"

  write_report_header

  local verify_script
  verify_script="$(mktemp)"

  cat > "$verify_script" <<'VERIFY'
set -u

failures=0
report_file="${DEV_TOOLS_REPORT_MD:?}"

append_report_row() {
  status="$1"
  label="$2"
  command_text="$3"
  output_text="${4:-}"

  output_text="$(printf '%s' "$output_text" | tr '\n' ' ' | sed 's/|/\\|/g')"

  printf '| %s | %s | `%s` | %s |\n' \
    "$status" \
    "$label" \
    "$command_text" \
    "$output_text" >> "$report_file"
}

check_required() {
  label="$1"
  shift

  command_text="$*"

  if "$@" >/tmp/dev-tools-check.out 2>/tmp/dev-tools-check.err; then
    first_line="$(head -n 1 /tmp/dev-tools-check.out 2>/dev/null || true)"
    [ -n "$first_line" ] || first_line="$(head -n 1 /tmp/dev-tools-check.err 2>/dev/null || true)"

    if [ -n "$first_line" ]; then
      printf 'PASS %s: %s\n' "$label" "$first_line"
    else
      printf 'PASS %s\n' "$label"
    fi

    append_report_row "ok" "$label" "$command_text" "$first_line"
  else
    err_line="$(head -n 1 /tmp/dev-tools-check.err 2>/dev/null || true)"
    printf 'FAIL %s\n' "$label"
    [ -n "$err_line" ] && printf '  %s\n' "$err_line" >&2

    append_report_row "fail" "$label" "$command_text" "$err_line"
    failures=$((failures + 1))
  fi
}

check_optional() {
  label="$1"
  shift

  command_text="$*"

  if "$@" >/tmp/dev-tools-check.out 2>/tmp/dev-tools-check.err; then
    first_line="$(head -n 1 /tmp/dev-tools-check.out 2>/dev/null || true)"
    [ -n "$first_line" ] || first_line="$(head -n 1 /tmp/dev-tools-check.err 2>/dev/null || true)"

    if [ -n "$first_line" ]; then
      printf 'PASS %s: %s\n' "$label" "$first_line"
    else
      printf 'PASS %s\n' "$label"
    fi

    append_report_row "ok" "$label" "$command_text" "$first_line"
  else
    err_line="$(head -n 1 /tmp/dev-tools-check.err 2>/dev/null || true)"
    printf 'WARN optional missing: %s\n' "$label"
    append_report_row "optional-missing" "$label" "$command_text" "$err_line"
  fi
}

check_file_required() {
  label="$1"
  file="$2"

  if [ -f "$file" ]; then
    printf 'PASS %s file exists\n' "$label"
    append_report_row "ok" "$label" "test -f $file" "present"
  else
    printf 'FAIL %s file missing\n' "$label"
    append_report_row "fail" "$label" "test -f $file" "missing"
    failures=$((failures + 1))
  fi
}

check_required atuin atuin --version
check_required bat bat --version
check_required btop btop --version
check_required colima colima version
check_required docker docker --version
check_required eza eza --version
check_required fd fd --version
check_required fzf fzf --version
check_required git-delta delta --version
check_required difftastic difft --version
check_required direnv direnv --version
check_required just just --version
check_required lazygit lazygit --version
check_required lnav lnav --version
check_required lychee lychee --version
check_required mise mise --version
check_required mysql-client mysql --version
check_required neovim nvim --version
check_required pnpm pnpm --version
check_required ripgrep rg --version
check_required ripgrep-all rga --version
check_required semgrep semgrep --version
check_required shellcheck shellcheck --version
check_required shfmt shfmt --version
check_required starship starship --version
check_required stripe stripe --version
check_required tldr-client tldr --version
check_required tmux tmux -V
check_required watchexec watchexec --version
check_required yazi yazi --version
check_required yq yq --version
check_required zoxide zoxide --version
check_required bats-core bats --version
check_required actionlint actionlint --version

if command -v brew >/dev/null 2>&1; then
  check_file_required zsh-autosuggestions "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  check_file_required zsh-syntax-highlighting "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

exit "$failures"
VERIFY

  export DEV_TOOLS_REPORT_MD="$REPORT_MD"

  if zsh -lic "source '$verify_script'"; then
    ok "All required verification checks passed"
  else
    local status=$?
    fail "$status required verification check(s) failed"
    rm -f "$verify_script"
    printf '\nMarkdown report: %s\n' "$REPORT_MD"
    exit "$status"
  fi

  rm -f "$verify_script"
  printf '\nMarkdown report: %s\n' "$REPORT_MD"
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
