#!/usr/bin/env bash
# Install the curated VS Code extension set shipped by this repository.
# Idempotent: already-installed extensions are skipped.

set -euo pipefail

MODE="apply"
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    -h|--help)
      sed -n '2,34p' "$0"
      exit 0
      ;;
    *) printf '[vscode-extensions:error] unknown arg: %s\n' "$arg" >&2; exit 1 ;;
  esac
done

log() { printf '[vscode-extensions:%s] %s\n' "$MODE" "$*"; }

find_code() {
  if command -v code >/dev/null 2>&1; then
    command -v code
    return 0
  fi

  # macOS Homebrew cask installs the CLI here even when shell PATH has not been
  # refreshed yet. Keep this as a fallback so bootstrap/install can run directly
  # after nix-darwin applies the cask.
  local macos_code="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  if [[ -x "$macos_code" ]]; then
    printf '%s\n' "$macos_code"
    return 0
  fi

  return 1
}

extensions=(
  alefragnani.bookmarks
  amiralizadeh9480.laravel-extra-intellisense
  anan.jetbrains-darcula-theme
  austenc.tailwind-docs
  bmewburn.vscode-intelephense-client
  bradlc.vscode-tailwindcss
  christian-kohler.npm-intellisense
  christian-kohler.path-intellisense
  codingyu.laravel-goto-view
  davidanson.vscode-markdownlint
  dbaeumer.vscode-eslint
  devsense.phptools-vscode
  docker.docker
  dotenv.dotenv-vscode
  eamodio.gitlens
  ecmel.vscode-html-css
  editorconfig.editorconfig
  esbenp.prettier-vscode
  formulahendry.auto-close-tag
  github.vscode-github-actions
  github.vscode-pull-request-github
  gruntfuggly.todo-tree
  hbenl.vscode-test-explorer
  htmlhint.vscode-htmlhint
  humao.rest-client
  k--kato.intellij-idea-keybindings
  mechatroner.rainbow-csv
  mehedidracula.php-namespace-resolver
  mhutchie.git-graph
  ms-azuretools.vscode-containers
  ms-azuretools.vscode-docker
  ms-playwright.playwright
  ms-vscode-remote.remote-containers
  ms-vscode-remote.remote-wsl
  ms-vscode.test-adapter-converter
  ms-vscode.vscode-typescript-next
  naumovs.color-highlight
  neilbrayfield.php-docblocker
  nuxtr.nuxtr-vscode
  open-southeners.laravel-pint
  pkief.material-icon-theme
  pranaygp.vscode-css-peek
  recca0120.vscode-phpunit
  redhat.vscode-yaml
  ryannaddy.laravel-artisan
  shufo.vscode-blade-formatter
  sonarsource.sonarlint-vscode
  streetsidesoftware.code-spell-checker
  stylelint.vscode-stylelint
  usernamehw.errorlens
  vue.volar
  xdebug.php-debug
)

if ! code_bin="$(find_code)"; then
  log "code CLI not found; skipping VS Code extension install"
  exit 0
fi

log "code CLI: $code_bin"

installed="$("$code_bin" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
missing=()
for extension in "${extensions[@]}"; do
  if ! grep -Fxq "${extension,,}" <<<"$installed"; then
    missing+=("$extension")
  fi
done

if (( ${#missing[@]} == 0 )); then
  log "all ${#extensions[@]} curated extensions already installed"
  exit 0
fi

if [[ "$MODE" == "dry-run" ]]; then
  log "would install ${#missing[@]} missing extensions:"
  printf '  %s\n' "${missing[@]}"
  exit 0
fi

for extension in "${missing[@]}"; do
  log "installing $extension"
  "$code_bin" --install-extension "$extension"
done

log "installed ${#missing[@]} missing extensions"
