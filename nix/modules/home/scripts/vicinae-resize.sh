# Usage: vicinae-resize [WIDTH_PERCENT] [HEIGHT_PERCENT]   (default 75 100)
#
# Resizes the focused window to a percentage of the monitor it is on, centered
# horizontally, below GNOME's top panel on the primary monitor.
#
# Monitor geometry comes from Mutter's DisplayConfig (GetCurrentState, read as
# JSON via busctl), the same logical layout MoveResize works in. It follows
# resolution, scale and rotation changes; XWayland's xrandr does not.
#
# Intentionally NOT using `set -e`/`pipefail`: every step is guarded
# explicitly so a missing D-Bus service exits cleanly instead of aborting the
# keybinding. Tools come from PATH (pinned by the Nix wrapper in gui.nix;
# stubbed in tests/bash/vicinae-resize.bats).
set -u
pct_w="${1:-75}"
pct_h="${2:-100}"
top_margin="${VICINAE_RESIZE_TOP_MARGIN:-32}"

for v in "$pct_w" "$pct_h"; do
  if ! [[ "$v" =~ ^[0-9]+$ ]] || [ "$v" -lt 1 ] || [ "$v" -gt 100 ]; then
    echo "usage: vicinae-resize [WIDTH_PERCENT] [HEIGHT_PERCENT]   (1-100 each)" >&2
    exit 2
  fi
done

dest="org.gnome.Shell"
obj="/org/gnome/Shell/Extensions/Windows"
iface="org.gnome.Shell.Extensions.Windows"

gcall() {
  gdbus call --session --dest "$dest" \
    --object-path "$obj" --method "$iface.$1" "${@:2}"
}

# Graceful degradation: if the Vicinae extension D-Bus service is not on the
# bus (extension disabled or incompatible with the running GNOME), do nothing
# instead of erroring out the keybinding.
raw="$(busctl --user --json=short call "$dest" "$obj" "$iface" GetFocusedWindowSync 2>/dev/null)" || raw=""
json="$(printf '%s' "$raw" | jq -ce '.data[0] | fromjson | select(type == "object")' 2>/dev/null)" || json=""
if [ -z "$json" ]; then
  echo "vicinae-resize: window D-Bus service unavailable (is the Vicinae GNOME extension enabled?)" >&2
  exit 0
fi

id="$(printf '%s' "$json" | jq -r '.id // empty' 2>/dev/null)"
[ -n "$id" ] || { echo "vicinae-resize: no focused window" >&2; exit 0; }

state="$(busctl --user --json=short call org.gnome.Mutter.DisplayConfig \
  /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig GetCurrentState 2>/dev/null || true)"

# GetCurrentState: data[1] = physical monitors (each with its modes; the active
# one is flagged is-current), data[2] = logical monitors (x, y, scale,
# transform, primary, [connectors]), data[3]["layout-mode"]: 1 = logical
# (monitor size is mode / scale), 2 = physical (size is the mode itself).
# Odd transforms are 90/270-degree rotations, so width and height swap.
# The top panel lives on the primary monitor only; its height is in logical
# pixels, so it is scaled up in physical layout mode.
geometry="$(printf '%s' "$state" | jq -r \
  --argjson win "$json" --argjson pw "$pct_w" --argjson ph "$pct_h" --argjson top "$top_margin" '
  (.data[3]["layout-mode"].data // 1) as $layout
  | (.data[1] | map({key: .[0][0],
      value: ([.[1][] | select(.[6]["is-current"].data == true)][0])}) | from_entries) as $modes
  | [.data[2][] as $lm
      | $modes[$lm[5][0][0]] as $mode
      | select($mode != null)
      | (if ($lm[3] % 2) == 1 then [$mode[2], $mode[1]] else [$mode[1], $mode[2]] end) as $px
      | (if $layout == 1 then $lm[2] else 1 end) as $div
      | {x: $lm[0], y: $lm[1], w: ($px[0] / $div | round), h: ($px[1] / $div | round),
         primary: $lm[4],
         top: (if $lm[4] then ($top * (if $layout == 1 then 1 else $lm[2] end) | round) else 0 end)}]
  | ($win.x + ($win.width / 2 | floor)) as $cx
  | ($win.y + ($win.height / 2 | floor)) as $cy
  | ((map(select($cx >= .x and $cx < .x + .w and $cy >= .y and $cy < .y + .h)) + map(select(.primary)) + .)[0]) as $m
  | select($m != null)
  | ($m.h - $m.top) as $work_h
  | ($m.w * $pw / 100 | floor) as $nw
  | ($work_h * $ph / 100 | floor) as $nh
  | "\($m.x + (($m.w - $nw) / 2 | floor)) \($m.y + $m.top + (($work_h - $nh) / 2 | floor)) \($nw) \($nh)"
' 2>/dev/null)"

read -r new_x new_y new_w new_h <<<"$geometry"
if [ -z "${new_h:-}" ]; then
  echo "vicinae-resize: could not read monitor geometry from Mutter DisplayConfig" >&2
  exit 0
fi

gcall MoveResize "$id" "$new_x" "$new_y" "$new_w" "$new_h" >/dev/null 2>&1 || true
