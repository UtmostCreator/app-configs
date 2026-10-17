set -u

dest="org.gnome.Shell"
obj="/org/gnome/Shell/Extensions/Windows"
iface="org.gnome.Shell.Extensions.Windows"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/vicinae-toggle-app"
mkdir -p "$state_dir" 2>/dev/null || true

while :; do
  raw="$(busctl --user --json=short call "$dest" "$obj" "$iface" List 2>/dev/null)" || raw=""
  if json="$(printf '%s' "$raw" | jq -ce '.data[0] | fromjson | select(type == "array")' 2>/dev/null)"; then
    focused="$(printf '%s' "$json" | jq -r '
      .[] | select(.has_focus == true) | [(.wm_class // ""), (.id | tostring)] | @tsv
    ' 2>/dev/null | head -1)"
    if [ -n "$focused" ]; then
      wm_class="$(printf '%s' "$focused" | cut -f1)"
      id="$(printf '%s' "$focused" | cut -f2)"
      if [ -n "$wm_class" ] && [ -n "$id" ]; then
        key="$(printf '%s' "$wm_class" | tr '[:upper:]' '[:lower:]' | sed 's#[^A-Za-z0-9._-]#_#g')"
        printf '%s' "$id" > "$state_dir/$key" 2>/dev/null || true
      fi
    fi
  fi
  sleep 0.25
done
