set -euo pipefail

# Tools. The Nix wrapper (nix/modules/home/gui.nix) sets these to absolute
# store paths, so the installed script calls the same binaries as before and
# the PATH that VS Code inherits is left alone. Unset (as in the tests), they
# fall back to the command name on PATH.
python3_bin="${VRP_PYTHON3:-python3}"
code_bin="${VRP_CODE:-code}"
basename_bin="${VRP_BASENAME:-basename}"
busctl_bin="${VRP_BUSCTL:-busctl}"
jq_bin="${VRP_JQ:-jq}"
gdbus_bin="${VRP_GDBUS:-gdbus}"

# Extract recent folders (newest first, de-duplicated) from VS Code's
# state DBs, then let the user pick one via Vicinae's dmenu popup.
selected="$(
  "$python3_bin" - <<'PY' | vicinae dmenu --navigation-title "VS Code" --placeholder "Open recent project…"
from pathlib import Path
import json
import sqlite3
import urllib.parse

home = Path.home()

# Read order = priority; first DB that yields an entry wins for ordering.
dbs = [
    home / ".config/Code/User/globalStorage/state.vscdb",
    home / ".config/Code - Insiders/User/globalStorage/state.vscdb",
    home / ".config/VSCodium/User/globalStorage/state.vscdb",
    home / ".vscode-shared/sharedStorage/state.vscdb",
    home / ".vscode-insiders-shared/sharedStorage/state.vscdb",
    home / ".vscodium-shared/sharedStorage/state.vscdb",
]

def file_uri_to_path(uri):
    if not uri or not uri.startswith("file://"):
        return None
    return urllib.parse.unquote(urllib.parse.urlparse(uri).path)

seen = set()

for db in dbs:
    if not db.exists():
        continue
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        rows = con.execute(
            "SELECT value FROM ItemTable "
            "WHERE key = 'history.recentlyOpenedPathsList'"
        ).fetchall()
        con.close()
    except Exception:
        continue

    for (value,) in rows:
        try:
            data = json.loads(value)
        except Exception:
            continue
        for entry in data.get("entries", []):
            path = None
            if "folderUri" in entry:
                path = file_uri_to_path(entry.get("folderUri"))
            elif "workspace" in entry:
                path = file_uri_to_path(entry["workspace"].get("configPath"))
            if path and path not in seen and Path(path).exists():
                seen.add(path)
                print(path)
PY
)"

# No selection (popup dismissed) -> do nothing.
[ -n "${selected:-}" ] || exit 0

# Open the folder. `code` reuses the existing VS Code instance and opens
# the folder INTO it, but on GNOME Wayland it does NOT raise/focus the
# window when VS Code was already running in the background. So we open
# the folder, then explicitly focus a VS Code window via the same
# Vicinae/Windows D-Bus API used by vicinae-toggle-app.
# Failures are surfaced (stderr + exit status), not swallowed: a failed
# open must not look like success. `code` output stays quiet on success.
if ! code_out="$("$code_bin" "$selected" 2>&1)"; then
  echo "vscode-recent-projects: 'code $selected' failed: $code_out" >&2
  exit 1
fi

dest="org.gnome.Shell"
obj="/org/gnome/Shell/Extensions/Windows"
iface="org.gnome.Shell.Extensions.Windows"
wm_class="code"
# VS Code window titles embed the folder name, e.g.
# "file - app-configs - Visual Studio Code". Match the selected project's
# basename so we focus the RIGHT window when several projects are open.
proj_name="$("$basename_bin" "$selected")"

# `code` may need a moment to (re)attach the folder to a window before a
# window of class `code` is listable/activatable. Poll briefly.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  raw="$("$busctl_bin" --user --json=short call "$dest" "$obj" "$iface" List 2>/dev/null)" || raw=""
  json="$(printf '%s' "$raw" | "$jq_bin" -ce '.data[0] | fromjson | select(type == "array")' 2>/dev/null)" || { sleep 0.3; continue; }
  # Prefer the `code` window whose title contains the project name; else a
  # focused `code` window; else the first `code` window.
  # shellcheck disable=SC2016  # $c and $n are jq variables, not shell ones
  win_id="$(printf '%s' "$json" | "$jq_bin" -r --arg c "$wm_class" --arg n "$proj_name" '
    [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
    | ( (map(select((.title // "") | contains($n))) | .[0].id)
        // (map(select(.has_focus == true)) | .[0].id)
        // .[0].id ) // empty' 2>/dev/null)"
  if [ -n "$win_id" ]; then
    "$gdbus_bin" call --session --dest "$dest" \
      --object-path "$obj" --method "$iface.Activate" "$win_id" \
      >/dev/null 2>&1 || true
    exit 0
  fi
  sleep 0.3
done
# D-Bus unavailable or no window yet -> `code` already did the open; exit
# cleanly so the hotkey never wedges.
exit 0

