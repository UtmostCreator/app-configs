# GNOME backend for window-backend.sh (sourced, or inlined by gui.nix).
#
# Talks to the Vicinae GNOME extension over D-Bus
# (org.gnome.Shell.Extensions.Windows) and to Mutter's DisplayConfig. Reads go
# through busctl: its JSON envelope preserves quotes, apostrophes, backslashes
# and newlines in window titles, where stripping a gdbus GVariant wrapper leaves
# escapes behind and can turn a valid window list into a parse error. Writes go
# through gdbus.
#
# Tools come from PATH unless WB_BUSCTL, WB_JQ or WB_GDBUS name them.
# Exit status of a read: 0 = printed, 1 = the D-Bus call failed, 2 = the reply
# was not the expected JSON.

wb_gnome_dest="org.gnome.Shell"
wb_gnome_obj="/org/gnome/Shell/Extensions/Windows"
wb_gnome_iface="org.gnome.Shell.Extensions.Windows"

# wb_gnome_read <method> <json-type>: call a method that returns one JSON
# string and print the decoded value when it has the given type.
wb_gnome_read() {
  local raw
  raw="$("${WB_BUSCTL:-busctl}" --user --json=short call \
    "$wb_gnome_dest" "$wb_gnome_obj" "$wb_gnome_iface" "$1" 2>/dev/null)" || return 1
  printf '%s' "$raw" \
    | "${WB_JQ:-jq}" -ce ".data[0] | fromjson | select(type == \"$2\")" 2>/dev/null || return 2
}

wb_gnome_call() {
  "${WB_GDBUS:-gdbus}" call --session --dest "$wb_gnome_dest" \
    --object-path "$wb_gnome_obj" --method "$wb_gnome_iface.$1" "${@:2}"
}

wb_gnome_list() { wb_gnome_read List array; }
wb_gnome_focused() { wb_gnome_read GetFocusedWindowSync object; }
wb_gnome_focus() { wb_gnome_call Activate "$1"; }
wb_gnome_hide() { wb_gnome_call Minimize "$1"; }
wb_gnome_move_resize() { wb_gnome_call MoveResize "$1" "$2" "$3" "$4" "$5"; }

wb_gnome_outputs() {
  "${WB_BUSCTL:-busctl}" --user --json=short call org.gnome.Mutter.DisplayConfig \
    /org/gnome/Mutter/DisplayConfig org.gnome.Mutter.DisplayConfig GetCurrentState 2>/dev/null
}
