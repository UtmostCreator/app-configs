#!/usr/bin/env bash
# chezmoi modify_ script for VS Code's user settings.json
# (~/.config/Code/User on Linux, ~/Library/Application Support/Code/User on
# macOS; WSL2 ignores the path, see .chezmoiignore).
#
# VS Code rewrites this file itself (workspace trust, UI toggles, Settings
# Sync), so owning it as a full template made every such rewrite a chezmoi
# "edited since chezmoi wrote it" conflict that stopped sys-update. Here the
# current file arrives on stdin and the repo's keys are merged over it:
#
# - Repo values win for the keys in .chezmoitemplates/vscode/settings.{full,
#   minimal}.json (picked by the `minimal` data key). Objects merge
#   recursively, arrays and scalars are replaced. Everything else VS Code or
#   the user wrote is kept, in the order it is in.
# - A merge that changes nothing returns the input byte-for-byte, so VS Code's
#   own formatting and comments survive and a second run is a no-op.
# - No file yet: the repo template is written as is (comments included).
# - VS Code allows JSONC, so comments and trailing commas are read. A file
#   that still is not a JSON object, or a host without jq, gets the input back
#   unchanged with a warning on stderr: never wipe the user's settings.
#
# Removing a key from the repo does not remove it from the live file (the same
# policy as ~/.claude/settings.json): the script cannot tell a key the repo
# dropped from one the user set. Delete it there by hand.
set -euo pipefail

managed="$(cat <<'VSCODE_SETTINGS_JSONC'
{{ if .minimal -}}
{{ template "vscode/settings.minimal.json" . }}
{{- else -}}
{{ template "vscode/settings.full.json" . }}
{{- end }}
VSCODE_SETTINGS_JSONC
)"

target="VS Code settings.json"
warn() { printf 'chezmoi: %s: %s; left unchanged\n' "$target" "$1" >&2; }

current_file="$(mktemp)"
trap 'rm -f "$current_file"' EXIT
cat >"$current_file"

# JSONC -> JSON: drop // and /* */ comments outside strings, and commas that
# only precede a closing bracket. Malformed input stays malformed for jq.
jsonc_to_json() {
  LC_ALL=C awk '
    { s = s $0 "\n" }
    END {
      n = length(s); i = 1; instr = 0; comma = 0
      while (i <= n) {
        c = substr(s, i, 1)
        if (instr) {
          printf "%s", c
          if (c == "\\") { printf "%s", substr(s, i + 1, 1); i += 2; continue }
          if (c == "\"") instr = 0
          i++; continue
        }
        if (c == "/" && substr(s, i + 1, 1) == "/") {
          while (i <= n && substr(s, i, 1) != "\n") i++
          continue
        }
        if (c == "/" && substr(s, i + 1, 1) == "*") {
          j = index(substr(s, i + 2), "*/")
          if (j == 0) { printf "%s", "\001"; exit }
          i += j + 3; continue
        }
        if (c == " " || c == "\t" || c == "\r" || c == "\n") { printf "%s", c; i++; continue }
        if (c == ",") { if (comma) printf ","; comma = 1; i++; continue }
        if (comma && c != "}" && c != "]") printf ","
        comma = 0
        if (c == "\"") instr = 1
        printf "%s", c; i++
      }
      if (comma) printf ","
    }'
}

if ! grep -q '[^[:space:]]' "$current_file"; then
  printf '%s\n' "$managed"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found"
  cat "$current_file"
  exit 0
fi

if ! managed_json="$(jsonc_to_json <<<"$managed" | jq -ce 'if type == "object" then . else error("not an object") end' 2>/dev/null)"; then
  warn "the repo settings template is not valid JSONC"
  cat "$current_file"
  exit 0
fi

if ! current_json="$(jsonc_to_json <"$current_file" | jq -ce 'if type == "object" then . else error("not an object") end' 2>/dev/null)"; then
  warn "not a JSON(C) object"
  cat "$current_file"
  exit 0
fi

if jq -ne --argjson c "$current_json" --argjson m "$managed_json" '$c == ($c * $m)' >/dev/null; then
  cat "$current_file"
else
  jq -n --argjson c "$current_json" --argjson m "$managed_json" '$c * $m'
fi
