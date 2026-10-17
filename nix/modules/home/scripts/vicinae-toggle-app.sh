set -u
app_id="${1:-}"
wm_class="${2:-$app_id}"
if [ -z "$app_id" ]; then
  echo "usage: vicinae-toggle-app <app_id> [wm_class]" >&2
  exit 2
fi

dest="org.gnome.Shell"
obj="/org/gnome/Shell/Extensions/Windows"
iface="org.gnome.Shell.Extensions.Windows"

gcall() {
  gdbus call --session --dest "$dest" \
    --object-path "$obj" --method "$iface.$1" "${@:2}"
}

launch() {
  vicinae app launch "$app_id" && exit 0
  if [ "$app_id" = "com.mitchellh.ghostty" ]; then
    exec ghostty --gtk-single-instance=true
  fi
  if [ "$app_id" = "brave-browser" ]; then
    exec brave
  fi
  exit 1
}

# Per-wm_class MRU state. Lives in the runtime dir (tmpfs, cleared on
# logout) so stale window ids never survive a session. One file per app,
# keyed by a sanitized wm_class, holding just the last-used window id.
state_dir="${XDG_RUNTIME_DIR:-/tmp}/vicinae-toggle-app"
mkdir -p "$state_dir" 2>/dev/null || true
mru_key="$(printf '%s' "$wm_class" | tr '[:upper:]' '[:lower:]' | sed 's#[^A-Za-z0-9._-]#_#g')"
mru_file="$state_dir/$mru_key"

mru_read() {
  [ -f "$mru_file" ] && cat "$mru_file" 2>/dev/null || true
}
mru_write() {
  printf '%s' "$1" > "$mru_file" 2>/dev/null || true
}

# busctl's JSON envelope preserves quotes, apostrophes, backslashes and
# newlines in titles. Stripping a gdbus GVariant wrapper leaves escapes behind
# and can turn a valid window list into a parse error that looks like no windows.
raw="$(busctl --user --json=short call "$dest" "$obj" "$iface" List 2>/dev/null)" || {
  echo "vicinae-toggle-app: cannot list windows (is the Vicinae GNOME extension enabled?)" >&2
  exit 1
}
json="$(printf '%s' "$raw" | jq -ce '.data[0] | fromjson | select(type == "array")' 2>/dev/null)" || {
  echo "vicinae-toggle-app: invalid window list" >&2
  exit 1
}

# Case-insensitive match on wm_class. jq emits one window id per query
# (or empty):
#   focused_id = the app's currently-foreground window, if any
#   any_id     = the first matching window (fallback target)
#   ids        = newline-separated list of ALL matching window ids, used
#                to validate a remembered MRU id is still alive
focused_id="$(printf '%s' "$json" | jq -r --arg c "$wm_class" '
  [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
  | (map(select(.has_focus == true)) | .[0].id) // empty' 2>/dev/null)"

any_id="$(printf '%s' "$json" | jq -r --arg c "$wm_class" '
  [ .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) ]
  | (.[0].id) // empty' 2>/dev/null)"

ids="$(printf '%s' "$json" | jq -r --arg c "$wm_class" '
  .[] | select((.wm_class // "" | ascii_downcase) == ($c | ascii_downcase)) | .id' 2>/dev/null)"

# Record MRU: whenever a window of this app is focused (about to be
# hidden or already in front), remember it as the one to restore next.
if [ -n "$focused_id" ]; then
  mru_write "$focused_id"
fi

if [ -n "$focused_id" ]; then
  # App is in the foreground -> send it to the background. The MRU is
  # already recorded above, so re-pressing later returns to THIS window.
  gcall Minimize "$focused_id" >/dev/null 2>&1 || true
  exit 0
elif [ -n "$any_id" ]; then
  # App is running but not focused -> bring forward the most-recently-used
  # window if it still exists, otherwise the first matching window. This
  # keeps multi-window apps (e.g. two VS Code projects) stable on the last
  # project you used instead of jumping to whichever is first in the list.
  target_id="$any_id"
  mru_id="$(mru_read)"
  if [ -n "$mru_id" ] && printf '%s\n' "$ids" | grep -qxF "$mru_id"; then
    target_id="$mru_id"
  fi
  if gcall Activate "$target_id" >/dev/null 2>&1; then
    mru_write "$target_id"
    exit 0
  fi
  # A failed activation does not mean the app needs another window.
  echo "vicinae-toggle-app: could not activate window $target_id" >&2
  exit 1
else
  # Not running -> launch a fresh instance.
  launch
fi
