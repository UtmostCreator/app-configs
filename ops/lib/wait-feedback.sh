#!/usr/bin/env bash
# shellcheck shell=bash
# Feedback for long waits (T-0050): a step that can take more than a couple of
# seconds says what it is doing and how long it can take BEFORE it starts, keeps
# a heartbeat going while it runs, and ends with a result line.
#
#   wait_run WHAT EXPECTED CMD [ARG...]
#
# Runs CMD in this shell (functions work, variables they set survive) with its
# stdout and stderr untouched, and returns CMD's exit status. CMD runs as the
# left side of `||` here, so errexit (set -e) is suppressed inside a wrapped
# function: it keeps going after a failing command, as in any `cmd || ...`.
# Everything wait_run
# prints goes to stderr, as plain lines (no carriage returns, no escapes), so
# stdout stays the command's own output and CI logs stay readable:
#
#   [wait] WHAT: starting, expected EXPECTED; a progress line follows every 30s
#   [wait] WHAT: still running, 1m00s elapsed
#   [wait] WHAT: done in 1m12s (exit 0)
#
# WAIT_HEARTBEAT_SECS sets the interval (default 30; anything but a positive
# integer means 30). The ticker is a background subshell tracked by PID: it is
# killed and reaped on every path out of wait_run, and it also stops by itself
# when the shell that called wait_run goes away (it checks that shell each
# second; a subshell caller counts, not just the top-level script), so a killed
# install leaves no ticker behind. Nothing here ever matches processes by name.
# WAIT_TICKER_PIDFILE (tests only) receives the ticker's PID.

_wait_fmt() {
  local s="$1"
  if ((s >= 60)); then printf '%dm%02ds' $((s / 60)) $((s % 60)); else printf '%ds' "$s"; fi
}

wait_run() {
  local what="$1" expected="$2" interval="${WAIT_HEARTBEAT_SECS:-30}" rc=0 tick start
  shift 2
  [[ "$interval" =~ ^[1-9][0-9]*$ ]] || interval=30
  # The shell running this call: $$ is the top-level script even inside a
  # subshell, and BASHPID needs bash 4. The substitution's subshell execs sh,
  # whose parent is the caller (bash 3.2 safe).
  local owner
  owner="$(exec sh -c 'echo "$PPID"' 2>/dev/null)" || owner=""
  [[ "$owner" =~ ^[0-9]+$ ]] || owner=$$   # no sh: the top-level shell is the best guess
  printf '[wait] %s: starting, expected %s; a progress line follows every %ss\n' "$what" "$expected" "$interval" >&2
  start=$SECONDS
  (
    parent=$owner
    next=$interval
    while kill -0 "$parent" 2>/dev/null; do
      # No sleep on PATH: stop ticking rather than spin.
      sleep 1 2>/dev/null || break
      elapsed=$((SECONDS - start))
      if ((elapsed >= next)); then
        printf '[wait] %s: still running, %s elapsed\n' "$what" "$(_wait_fmt "$elapsed")" >&2
        next=$((next + interval))
      fi
    done
  ) >/dev/null &
  tick=$!
  [[ -z "${WAIT_TICKER_PIDFILE:-}" ]] || printf '%s\n' "$tick" >"$WAIT_TICKER_PIDFILE"
  "$@" || rc=$?
  kill "$tick" 2>/dev/null || true
  wait "$tick" 2>/dev/null || true
  printf '[wait] %s: done in %s (exit %s)\n' "$what" "$(_wait_fmt $((SECONDS - start)))" "$rc" >&2
  return "$rc"
}
