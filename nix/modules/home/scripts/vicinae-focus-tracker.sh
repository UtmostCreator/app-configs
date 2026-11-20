set -u

# Window backend (wb_* functions, see window-backend.sh). The installed script
# has it inlined above this text by gui.nix; run from the repo, source it from
# this directory.
if ! declare -F wb_list >/dev/null; then
  wb_dir="${BASH_SOURCE[0]%/*}"
  [ "$wb_dir" != "${BASH_SOURCE[0]}" ] || wb_dir=.
  # shellcheck source=/dev/null
  . "$wb_dir/window-backend.sh"
fi

state_dir="${XDG_RUNTIME_DIR:-/tmp}/vicinae-toggle-app"
mkdir -p "$state_dir" 2>/dev/null || true

while :; do
  if json="$(wb_list)"; then
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
