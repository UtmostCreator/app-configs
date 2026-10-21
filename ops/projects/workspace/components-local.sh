#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

ACTIVE_NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
if [[ "$ACTIVE_NODE_MAJOR" != "22" ]] && command -v mise >/dev/null 2>&1; then
  exec mise exec "$WS_NODE_RUNTIME" -- bash "$0" "$@"
fi

APP_NAME="ws-components-local"
STATE_DIR="$HOME/.local/state/$APP_NAME"
STATE_FILE="$STATE_DIR/state.env"
LOCKFILE_BACKUP="$STATE_DIR/web-frontend.package-lock.backup.json"

COMPONENTS_DIR="$WS_UI_COMPONENTS_DIR"
FRONTEND_DIR="$WS_FRONTEND_APP_DIR"

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  apply       Run an optional component test, pack ui-components, install the tarball into web-frontend
  refresh     Roll back any active local tarball install, then pack and reinstall the latest ui-components build
  watch       Apply the local tarball, then refresh it when component source files change
  rollback    Restore web-frontend from the saved lockfile backup and remove the local tarball install
  status      Show the saved state for the current local tarball workflow
  help        Show this help

Options for apply:
  --component-test <path>  Run npm test -- <path> in ui-components before packing
  --skip-test              Skip running a component test before packing
  --start-dev              Start web-frontend debug server after install
  --keep-tarball           Do not remove the generated tarball during rollback

Examples:
  $(basename "$0") apply --component-test src/components/__tests__/ExampleBlock.spec.js --start-dev
  $(basename "$0") refresh --component-test src/components/__tests__/ExampleBlock.spec.js
  $(basename "$0") watch
  $(basename "$0") rollback
EOF
}

fail() {
  echo "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "Required command not found: $command_name"
  fi
}

json_field() {
  local json_file="$1"
  local field_name="$2"

  node -e 'const fs = require("fs"); const [file, field] = process.argv.slice(1); const data = JSON.parse(fs.readFileSync(file, "utf8")); const value = data[field]; if (typeof value !== "string" || !value.length) process.exit(1); process.stdout.write(value);' "$json_file" "$field_name"
}

pack_filename_from_json() {
  node -e 'const fs = require("fs"); const data = JSON.parse(fs.readFileSync(0, "utf8")); const entry = Array.isArray(data) ? data[0] : data; if (!entry || typeof entry.filename !== "string" || !entry.filename.length) process.exit(1); process.stdout.write(entry.filename);'
}

save_state() {
  local package_name="$1"
  local tarball_path="$2"
  local keep_tarball="$3"
  local component_test_path="$4"
  local start_dev="$5"
  local lockfile_present="$6"

  ensure_state_dir

  {
    printf 'PACKAGE_NAME=%q\n' "$package_name"
    printf 'TARBALL_PATH=%q\n' "$tarball_path"
    printf 'KEEP_TARBALL=%q\n' "$keep_tarball"
    printf 'COMPONENT_TEST_PATH=%q\n' "$component_test_path"
    printf 'START_DEV=%q\n' "$start_dev"
    printf 'LOCKFILE_PRESENT=%q\n' "$lockfile_present"
    printf 'COMPONENTS_DIR=%q\n' "$COMPONENTS_DIR"
    printf 'FRONTEND_DIR=%q\n' "$FRONTEND_DIR"
  } > "$STATE_FILE"
}

load_state() {
  [[ -f "$STATE_FILE" ]] || fail "No saved state found. Run '$(basename "$0") apply' first."

  # shellcheck source=/dev/null
  source "$STATE_FILE"
}

run_component_test() {
  local component_test_path="$1"

  [[ -n "$component_test_path" ]] || return 0

  echo "Running component test in $COMPONENTS_DIR"
  (
    cd "$COMPONENTS_DIR"
    npm test -- "$component_test_path"
  )
}

backup_lockfile() {
  ensure_state_dir

  if [[ -f "$FRONTEND_DIR/package-lock.json" ]]; then
    cp "$FRONTEND_DIR/package-lock.json" "$LOCKFILE_BACKUP"
    echo "Saved web-frontend lockfile backup to $LOCKFILE_BACKUP"
    printf '1\n'
    return 0
  fi

  rm -f "$LOCKFILE_BACKUP"
  printf '0\n'
}

install_tarball() {
  local tarball_path="$1"

  echo "Installing $tarball_path into $FRONTEND_DIR"
  (
    cd "$FRONTEND_DIR"
    npm install --no-save "$tarball_path"
  )
}

start_frontend_debug() {
  echo "Restarting web-frontend debug server"
  bash "$WS_SCRIPT_FRONTEND_DEBUG" restart
}

stop_frontend_debug() {
  echo "Stopping web-frontend debug server before dependency changes"
  bash "$WS_SCRIPT_FRONTEND_DEBUG" stop
}

apply_workflow() {
  local component_test_path=""
  local should_run_test="1"
  local should_start_dev="0"
  local keep_tarball="0"
  local package_name=""
  local tarball_filename=""
  local tarball_path=""
  local pack_output=""
  local lockfile_present="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --component-test)
        [[ $# -ge 2 ]] || fail "Missing value for --component-test"
        component_test_path="$2"
        shift 2
        ;;
      --skip-test)
        should_run_test="0"
        shift
        ;;
      --start-dev)
        should_start_dev="1"
        shift
        ;;
      --keep-tarball)
        keep_tarball="1"
        shift
        ;;
      help|-h|--help)
        usage
        return 0
        ;;
      *)
        fail "Unknown option for apply: $1"
        ;;
    esac
  done

  [[ ! -f "$STATE_FILE" ]] || fail "Existing workflow state found at $STATE_FILE. Run rollback before applying again."

  require_command npm
  require_command node

  [[ -d "$COMPONENTS_DIR" ]] || fail "Components directory not found: $COMPONENTS_DIR"
  [[ -d "$FRONTEND_DIR" ]] || fail "Frontend directory not found: $FRONTEND_DIR"

  # Avoid changing node_modules while Frontend/Vite is running to prevent IPC crashes.
  stop_frontend_debug

  if [[ "$should_run_test" == "1" && -n "$component_test_path" ]]; then
    run_component_test "$component_test_path"
  fi

  package_name="$(json_field "$COMPONENTS_DIR/package.json" name)"
  pack_output="$(cd "$COMPONENTS_DIR" && npm pack --json)"
  tarball_filename="$(printf '%s\n' "$pack_output" | pack_filename_from_json)"
  tarball_path="$COMPONENTS_DIR/$tarball_filename"

  [[ -f "$tarball_path" ]] || fail "Tarball was not created: $tarball_path"

  lockfile_present="$(backup_lockfile)"
  save_state "$package_name" "$tarball_path" "$keep_tarball" "$component_test_path" "$should_start_dev" "$lockfile_present"
  install_tarball "$tarball_path"

  echo "Installed local package tarball: $tarball_path"
  echo "Rollback with: $(basename "$0") rollback"

  if [[ "$should_start_dev" == "1" ]]; then
    start_frontend_debug
  fi
}

rollback_workflow() {
  local package_name=""
  local tarball_path=""
  local keep_tarball="0"
  local lockfile_present="0"

  require_command npm

  load_state

  package_name="$PACKAGE_NAME"
  tarball_path="$TARBALL_PATH"
  keep_tarball="${KEEP_TARBALL:-0}"
  lockfile_present="${LOCKFILE_PRESENT:-0}"

  # Rollback also mutates node_modules/package-lock.json.
  stop_frontend_debug

  echo "Removing local package install for $package_name"
  rm -rf "$FRONTEND_DIR/node_modules/$package_name"

  if [[ "$lockfile_present" == "1" && -f "$LOCKFILE_BACKUP" ]]; then
    cp "$LOCKFILE_BACKUP" "$FRONTEND_DIR/package-lock.json"
    echo "Restored package-lock.json from backup"
  fi

  echo "Reinstalling frontend dependencies"
  if [[ -f "$FRONTEND_DIR/package-lock.json" ]]; then
    (
      cd "$FRONTEND_DIR"
      npm ci
    )
  else
    (
      cd "$FRONTEND_DIR"
      npm install --no-package-lock
    )
  fi

  if [[ "$keep_tarball" != "1" && -f "$tarball_path" ]]; then
    rm -f "$tarball_path"
    echo "Removed tarball $tarball_path"
  fi

  rm -f "$LOCKFILE_BACKUP" "$STATE_FILE"
  echo "Rollback complete"
}

refresh_workflow() {
  if [[ -f "$STATE_FILE" ]]; then
    echo "Existing local package state found. Rolling back before reinstalling."
    rollback_workflow
  fi

  apply_workflow "$@"
}

watch_workflow() {
  require_command node

  [[ -d "$COMPONENTS_DIR" ]] || fail "Components directory not found: $COMPONENTS_DIR"
  [[ -d "$FRONTEND_DIR" ]] || fail "Frontend directory not found: $FRONTEND_DIR"

  echo "Starting local UI package watch. Each source change repacks the dependency and restarts web-frontend."
  echo "Watching: $COMPONENTS_DIR"
  echo "Press Ctrl-C to stop. Roll back with: $(basename "$0") rollback"

  refresh_workflow --skip-test --start-dev

  COMPONENTS_DIR="$COMPONENTS_DIR" SELF_PATH="$0" node --input-type=module <<'NODE'
import { spawn } from 'node:child_process'
import { watch } from 'node:fs'
import path from 'node:path'

const componentsDir = process.env.COMPONENTS_DIR
const scriptPath = process.env.SELF_PATH
const ignoredDirectories = new Set(['.git', 'node_modules', 'dist', 'coverage'])
let refreshTimer
let refreshing = false
let refreshQueued = false

function refresh() {
  if (refreshing) {
    refreshQueued = true
    return
  }

  refreshing = true
  console.log(`\n[${new Date().toLocaleTimeString()}] Component change detected; refreshing local package.`)
  const child = spawn('bash', [scriptPath, 'refresh', '--skip-test', '--start-dev'], {
    stdio: 'inherit'
  })

  child.on('exit', (code) => {
    refreshing = false
    if (code !== 0) {
      console.error(`Local package refresh failed with exit code ${code}. Watching for the next change.`)
    }
    if (refreshQueued) {
      refreshQueued = false
      refresh()
    }
  })
}

watch(componentsDir, { recursive: true }, (eventType, filename) => {
  if (!filename) return
  const relativePath = filename.toString()
  if (relativePath.split(path.sep).some((part) => ignoredDirectories.has(part))) return
  if (relativePath.endsWith('.tgz')) return

  clearTimeout(refreshTimer)
  refreshTimer = setTimeout(refresh, 400)
})
NODE
}

show_status() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "No active local ui package workflow state found"
    echo "Components dir: $COMPONENTS_DIR"
    echo "Frontend dir: $FRONTEND_DIR"
    return 0
  fi

  load_state

  cat <<EOF
Active workflow state found:
  package: $PACKAGE_NAME
  tarball: $TARBALL_PATH
  keep tarball: ${KEEP_TARBALL:-0}
  component test: ${COMPONENT_TEST_PATH:-}
  start dev: ${START_DEV:-0}
  frontend dir: ${FRONTEND_DIR:-$WS_FRONTEND_APP_DIR}
EOF
}

command_name="${1:-help}"

case "$command_name" in
  apply)
    shift
    apply_workflow "$@"
    ;;
  refresh)
    shift
    refresh_workflow "$@"
    ;;
  watch)
    shift
    [[ $# -eq 0 ]] || fail "watch does not accept options"
    watch_workflow
    ;;
  rollback)
    shift
    rollback_workflow "$@"
    ;;
  status)
    shift
    show_status "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac