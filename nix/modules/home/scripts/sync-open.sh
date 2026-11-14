# sync-open: ensure the Syncthing user service is running, wait for its Web UI,
# then open it. Tools come from PATH (pinned by the Nix wrapper in gui.nix).
#
# The wait has ONE overall deadline (SYNC_OPEN_TIMEOUT seconds, default 15),
# covering every curl attempt and sleep. If the UI is not ready by then this
# exits 1 WITHOUT calling xdg-open, so no "connection refused" tab is opened.
set -euo pipefail

url="${SYNC_OPEN_URL:-http://127.0.0.1:8384/}"
timeout_s="${SYNC_OPEN_TIMEOUT:-15}"
case "$timeout_s" in
  '' | *[!0-9]*)
    echo "sync-open: SYNC_OPEN_TIMEOUT must be a whole number of seconds" >&2
    exit 2
    ;;
esac
# Force base 10 so a leading zero ("08") is not read as invalid octal.
timeout_s=$((10#$timeout_s))

# Start the service if it is not already active (idempotent).
if ! systemctl --user is-active --quiet syncthing.service; then
  systemctl --user start syncthing.service
fi

deadline=$((SECONDS + timeout_s))
while :; do
  # --max-time 1 keeps a single attempt well inside the deadline. Any HTTP
  # response counts as ready (a login-protected UI answers 401/403); only a
  # connection failure/timeout yields "000".
  code="$(curl -sS --max-time 1 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [ -n "$code" ] && [ "$code" != "000" ]; then
    exec xdg-open "$url"
  fi
  [ "$SECONDS" -lt "$deadline" ] || break
  sleep 0.5
done

echo "sync-open: Web UI at $url not ready after ${timeout_s}s; not opening it" >&2
exit 1
