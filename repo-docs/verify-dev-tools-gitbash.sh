#!/usr/bin/env bash
set -u

# verify-dev-tools-gitbash.sh
# Non-mutating verifier for Git Bash.
#
# Outputs:
#   ~/.dev-cli-tools/verify-gitbash-report.tsv
#   ~/.dev-cli-tools/verify-gitbash-report.md

REPORT_DIR="$HOME/.dev-cli-tools"
TSV_REPORT="$REPORT_DIR/verify-gitbash-report.tsv"
MD_REPORT="$REPORT_DIR/verify-gitbash-report.md"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-25}"

mkdir -p "$REPORT_DIR"

add_path() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

add_path "/usr/bin"
add_path "/bin"
add_path "/mingw64/bin"
add_path "/mingw64/libexec/git-core"
add_path "/cmd"
add_path "/c/Windows/System32"
add_path "/c/Windows"
add_path "$HOME/bin"
add_path "$HOME/scoop/shims"
add_path "$HOME/AppData/Local/Microsoft/WindowsApps"
add_path "$HOME/AppData/Local/Microsoft/WinGet/Links"
add_path "$HOME/AppData/Roaming/npm"
add_path "$HOME/.cargo/bin"
add_path "$HOME/.local/bin"
add_path "/c/Program Files/nodejs"
add_path "/c/Program Files/PowerShell/7"
add_path "/c/Program Files/Docker/Docker/resources/bin"
add_path "/c/Program Files/Git/cmd"
add_path "/c/Program Files/Git/bin"
add_path "/c/Program Files/Git/usr/bin"
add_path "/c/Program Files/Neovim/bin"
add_path "/c/msys64/usr/bin"
add_path "/c/msys64/mingw64/bin"

for d in /c/Program\ Files/MySQL/*/bin; do
  [ -d "$d" ] && add_path "$d"
done

for d in "$HOME/AppData/Roaming/Python"/*/Scripts "$HOME/AppData/Local/Python"/*/Scripts; do
  [ -d "$d" ] && add_path "$d"
done

NODE_EXE="/c/Program Files/nodejs/node.exe"
NPM_CLI="C:/Program Files/nodejs/node_modules/npm/bin/npm-cli.js"
OPENCODE_JS="C:/Users/UC-LL5S/AppData/Roaming/npm/node_modules/opencode-ai/bin/opencode"
AST_GREP_DIRECT="$HOME/AppData/Roaming/npm/node_modules/@ast-grep/cli/ast-grep"
SG_DIRECT="$HOME/AppData/Roaming/npm/node_modules/@ast-grep/cli/sg"

: > "$TSV_REPORT"
printf "status\ttool\tused\tversion_or_first_output\terror\n" >> "$TSV_REPORT"

first_line() {
  sed '/^[[:space:]]*$/d' | head -n 1 | tr '\r' ' '
}

append_result() {
  local status="$1"
  local name="$2"
  local used="$3"
  local version="$4"
  local error_text="$5"

  used="$(printf '%s' "$used" | tr '\t' ' ' | tr '\n' ' ' | tr '\r' ' ')"
  version="$(printf '%s' "$version" | tr '\t' ' ' | tr '\n' ' ' | tr '\r' ' ')"
  error_text="$(printf '%s' "$error_text" | tr '\t' ' ' | tr '\n' ' ' | tr '\r' ' ')"

  printf "%s\t%s\t%s\t%s\t%s\n" "$status" "$name" "$used" "$version" "$error_text" >> "$TSV_REPORT"
}

run_candidate() {
  local command_line="$1"
  local tmp
  tmp="$(mktemp)"

  if command -v timeout >/dev/null 2>&1; then
    timeout "${TIMEOUT_SECONDS}s" bash -lc "$command_line" >"$tmp" 2>&1
  else
    bash -lc "$command_line" >"$tmp" 2>&1
  fi

  CANDIDATE_RC=$?
  CANDIDATE_OUTPUT="$(cat "$tmp")"
  rm -f "$tmp"
}

check() {
  local name="$1"
  local required="$2"
  shift 2

  local candidate
  local last_error=""
  local used=""
  local version=""

  for candidate in "$@"; do
    run_candidate "$candidate"
    used="$candidate"

    if [ "$CANDIDATE_RC" -eq 0 ]; then
      version="$(printf '%s\n' "$CANDIDATE_OUTPUT" | first_line)"
      append_result "ok" "$name" "$used" "$version" ""
      printf "[OK]   %-34s %s\n" "$name" "$version"
      return 0
    fi

    last_error="$(printf '%s\n' "$CANDIDATE_OUTPUT" | first_line)"
    [ -n "$last_error" ] || last_error="exit code $CANDIDATE_RC"
  done

  if [ "$required" = "optional" ]; then
    append_result "optional-missing" "$name" "$used" "" "$last_error"
    printf "[WARN] %-34s %s\n" "$name" "$last_error"
    return 0
  fi

  append_result "fail" "$name" "$used" "" "$last_error"
  printf "[FAIL] %-34s %s\n" "$name" "$last_error"
  return 1
}

check_file() {
  local name="$1"
  local required="$2"
  local file="$3"

  if [ -f "$file" ]; then
    append_result "ok" "$name" "file-check" "present" ""
    printf "[OK]   %-34s present\n" "$name"
    return 0
  fi

  if [ "$required" = "optional" ]; then
    append_result "optional-missing" "$name" "file-check" "" "File not found: $file"
    printf "[WARN] %-34s file not found\n" "$name"
    return 0
  fi

  append_result "fail" "$name" "file-check" "" "File not found: $file"
  printf "[FAIL] %-34s file not found\n" "$name"
  return 1
}

FAILURES=0

echo "Git Bash CLI verification"
echo "BASH_VERSION=$BASH_VERSION"
echo "SHELL=$SHELL"
echo
echo "First PATH entries:"
printf '%s\n' "$PATH" | tr ':' '\n' | head -n 20
echo

check "WinGet" required "winget --version" || FAILURES=$((FAILURES + 1))
check "Git" required "git --version" || FAILURES=$((FAILURES + 1))
check "Git Bash" required "bash --version" || FAILURES=$((FAILURES + 1))
check "PowerShell 7" required "pwsh --version" || FAILURES=$((FAILURES + 1))
check "Python" required "python --version" || FAILURES=$((FAILURES + 1))
check "Python launcher" optional "py --version" || true
check "Node.js" required "node --version" "\"$NODE_EXE\" --version" || FAILURES=$((FAILURES + 1))
check "npm" required "npm --version" "\"$NODE_EXE\" \"$NPM_CLI\" --version" || FAILURES=$((FAILURES + 1))
check "Rust cargo" required "cargo --version" || FAILURES=$((FAILURES + 1))
check "Rustup" required "rustup --version" || FAILURES=$((FAILURES + 1))

check "Atuin" required "atuin --version" || FAILURES=$((FAILURES + 1))
check "bat" required "bat --version" || FAILURES=$((FAILURES + 1))
check "btop" required "btop --version" "btop4win --version" || FAILURES=$((FAILURES + 1))
check "Docker CLI" required "docker --version" || FAILURES=$((FAILURES + 1))
check "eza" required "eza --version" || FAILURES=$((FAILURES + 1))
check "fd" required "fd --version" || FAILURES=$((FAILURES + 1))
check "fzf" required "fzf --version" || FAILURES=$((FAILURES + 1))
check "git-delta" required "delta --version" || FAILURES=$((FAILURES + 1))
check "Difftastic" required "difft --version" || FAILURES=$((FAILURES + 1))
check "direnv" required "direnv version" || FAILURES=$((FAILURES + 1))
check "GitHub Copilot CLI" required "copilot --version" || FAILURES=$((FAILURES + 1))
check "just" required "just --version" || FAILURES=$((FAILURES + 1))
check "lazygit" required "lazygit --version" || FAILURES=$((FAILURES + 1))
check "lnav" required "lnav -V" || FAILURES=$((FAILURES + 1))
check "lychee" required "lychee --version" || FAILURES=$((FAILURES + 1))
check "mise" required "mise --version" || FAILURES=$((FAILURES + 1))
check "MySQL Shell" required "mysqlsh --version" || FAILURES=$((FAILURES + 1))
check "mysql.exe classic client" optional "mysql --version" || true
check "Neovim" required "nvim --version" || FAILURES=$((FAILURES + 1))
check "pnpm" required "pnpm --version" "pnpm.cmd --version" || FAILURES=$((FAILURES + 1))
check "ripgrep" required "rg --version" || FAILURES=$((FAILURES + 1))
check "ripgrep-all" required "rga --version" || FAILURES=$((FAILURES + 1))
check "Semgrep" required "semgrep --version" || FAILURES=$((FAILURES + 1))
check "ShellCheck" required "shellcheck --version" || FAILURES=$((FAILURES + 1))
check "shfmt" required "shfmt --version" || FAILURES=$((FAILURES + 1))
check "Starship" required "starship --version" || FAILURES=$((FAILURES + 1))
check "tlrc" required "tlrc --version" || FAILURES=$((FAILURES + 1))
check "tldr wrapper" optional "tldr --version" || true
check "tmux" required "tmux -V" || FAILURES=$((FAILURES + 1))
check "watchexec" required "watchexec --version" || FAILURES=$((FAILURES + 1))
check "Yazi" required "yazi --version" || FAILURES=$((FAILURES + 1))
check "yq" required "yq --version" || FAILURES=$((FAILURES + 1))
check "zoxide" required "zoxide --version" || FAILURES=$((FAILURES + 1))
check "actionlint" required "actionlint --version" || FAILURES=$((FAILURES + 1))
check "bats-core" required "bats --version" || FAILURES=$((FAILURES + 1))
check "zsh" optional "zsh --version" || true

check "OpenCode" required \
  "\"$NODE_EXE\" \"$OPENCODE_JS\" --version" \
  "opencode.cmd --version" \
  "opencode --version" || FAILURES=$((FAILURES + 1))

check "ast-grep" required \
  "\"$AST_GREP_DIRECT\" --version" \
  "ast-grep.cmd --version" \
  "ast-grep --version" || FAILURES=$((FAILURES + 1))

check "sg" required \
  "\"$SG_DIRECT\" --version" \
  "sg.cmd --version" \
  "sg --version" || FAILURES=$((FAILURES + 1))

check "VS Code CLI" optional "code --version" || true
check "Stripe CLI" optional "stripe --version" || true

check_file "zsh-autosuggestions plugin" optional "/c/msys64/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
check_file "zsh-syntax-highlighting plugin" optional "/c/msys64/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

append_result "unsupported" "colima" "native Windows" "" "Colima is not a native Windows container runtime. Use Docker Desktop or WSL2."
printf "[WARN] %-34s unsupported on native Windows\n" "colima"

{
  echo "# Git Bash CLI Verification Report"
  echo
  echo "- Generated: $(date -Iseconds)"
  echo "- Bash: $BASH_VERSION"
  echo "- Failures: $FAILURES"
  echo
  echo "| Status | Tool | Used | Version / First output | Error |"
  echo "|---|---|---|---|---|"

  tail -n +2 "$TSV_REPORT" | while IFS=$'\t' read -r status tool used version error_text; do
    used="${used//|/\\|}"
    version="${version//|/\\|}"
    error_text="${error_text//|/\\|}"
    echo "| $status | $tool | \`$used\` | $version | $error_text |"
  done
} > "$MD_REPORT"

echo
echo "TSV report: $TSV_REPORT"
echo "Markdown report: $MD_REPORT"

if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi

exit 0