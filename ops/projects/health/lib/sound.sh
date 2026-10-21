#!/usr/bin/env bash
# sound.sh — audio cues for the backend health monitor.
#
# `source` this file from monitor.sh. It defines the sound backend
# (afplay/paplay) and exposes can_play_sound / play_sound. Behavior is identical
# to the original inline implementation.
#
# Reads/writes globals from the monitor: SOUND_DEBOUNCE_SECONDS, LAST_SOUND_TS.

sound_cmd=""
sound_ok=""
sound_fail=""

if command -v afplay >/dev/null 2>&1; then
  sound_cmd="afplay"
  sound_ok="/System/Library/Sounds/Ping.aiff"
  sound_fail="/System/Library/Sounds/Basso.aiff"
elif command -v paplay >/dev/null 2>&1; then
  sound_cmd="paplay"
  sound_ok="/usr/share/sounds/freedesktop/stereo/complete.oga"
  sound_fail="/usr/share/sounds/freedesktop/stereo/dialog-error.oga"
fi

now_epoch() {
  date +%s
}

can_play_sound() {
  local now
  now="$(now_epoch)"
  if (( now - LAST_SOUND_TS >= SOUND_DEBOUNCE_SECONDS )); then
    LAST_SOUND_TS="$now"
    return 0
  fi
  return 1
}

play_sound() {
  local level="$1"
  local file=""

  case "$level" in
    success) file="$sound_ok" ;;
    fail) file="$sound_fail" ;;
  esac

  if ! can_play_sound; then
    return 0
  fi

  if [[ -n "$sound_cmd" && -f "$file" ]]; then
    "$sound_cmd" "$file" >/dev/null 2>&1 &
  else
    printf '\a'
  fi
}
