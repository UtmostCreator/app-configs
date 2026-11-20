# Window backend: the one interface the window helpers (vicinae-toggle-app,
# vicinae-focus-tracker, vicinae-resize, vscode-recent-projects) use to reach
# the compositor. Sourced, never executed.
#
#   wb_list                        print the JSON array of windows
#                                  ({id, wm_class, title, has_focus, ...})
#   wb_focused                     print the focused window as a JSON object
#                                  ({id, x, y, width, height, ...})
#   wb_outputs                     print the backend's monitor layout
#   wb_focus <id>                  bring a window to the front
#   wb_hide <id>                   send a window to the background
#   wb_move_resize <id> <x> <y> <w> <h>
#
# Reads print to stdout and return non-zero (printing nothing) on failure;
# actions return the backend's exit status and leave output handling to the
# caller.
#
# Backend: $WINDOW_BACKEND if set (tests), else gnome, the only one. A backend
# is a window-backend-<name>.sh file defining wb_<name>_<function>.
#
# Loading. The installed helpers are single files: gui.nix inlines the backend
# file and this one ahead of the helper body, so nothing is sourced from a
# runtime path. Run straight from the repo (tests), a helper sources this file
# from its own directory, and this file sources its backend the same way. Each
# source is skipped when the functions already exist.

wb_backend="${WINDOW_BACKEND:-gnome}"
case "$wb_backend" in
  gnome) ;;
  *)
    echo "window-backend: unknown WINDOW_BACKEND '$wb_backend' (supported: gnome)" >&2
    exit 2
    ;;
esac

if ! declare -F "wb_${wb_backend}_list" >/dev/null; then
  wb_dir="${BASH_SOURCE[0]%/*}"
  [ "$wb_dir" != "${BASH_SOURCE[0]}" ] || wb_dir=.
  # shellcheck source=/dev/null
  . "$wb_dir/window-backend-$wb_backend.sh"
fi

wb_list() { "wb_${wb_backend}_list"; }
wb_focused() { "wb_${wb_backend}_focused"; }
wb_outputs() { "wb_${wb_backend}_outputs"; }
wb_focus() { "wb_${wb_backend}_focus" "$@"; }
wb_hide() { "wb_${wb_backend}_hide" "$@"; }
wb_move_resize() { "wb_${wb_backend}_move_resize" "$@"; }
