#!/usr/bin/env bash
# render.sh — terminal rendering for the backend health monitor.
#
# `source` this file from monitor.sh. It owns the alt-screen handling,
# status glyphs/labels, the header, and the full dashboard frame. Behavior is
# identical to the original inline implementation.
#
# Depends on globals/vars defined by the monitor: colour vars (RED/GREEN/...),
# USE_ALT_SCREEN, ALT_SCREEN_ACTIVE, SHOW_RAW_CHECKS, VERIFY_SCRIPT,
# INTERVAL_SECONDS, SOUND_DEBOUNCE_SECONDS, LAST_OVERALL_STATE, LAST_SECTION_SIG,
# and the helpers have_gum / play_sound / tmux_notice / desktop_notice.

is_tty() {
  [[ -t 1 ]]
}

term_lines() {
  if is_tty && command -v tput >/dev/null 2>&1; then
    tput lines 2>/dev/null || printf '40\n'
  else
    printf '40\n'
  fi
}

enter_alt_screen() {
  if [[ "$USE_ALT_SCREEN" != "1" || "$ALT_SCREEN_ACTIVE" == "1" ]]; then
    return 0
  fi
  if is_tty && command -v tput >/dev/null 2>&1; then
    tput smcup 2>/dev/null || true
    tput civis 2>/dev/null || true
    ALT_SCREEN_ACTIVE=1
  fi
}

leave_alt_screen() {
  if [[ "$ALT_SCREEN_ACTIVE" != "1" ]]; then
    return 0
  fi
  if is_tty && command -v tput >/dev/null 2>&1; then
    tput cnorm 2>/dev/null || true
    tput rmcup 2>/dev/null || true
  fi
  ALT_SCREEN_ACTIVE=0
}

cleanup_screen() {
  leave_alt_screen
}

status_circle() {
  local state="$1"
  local filled="$2"
  local icon color

  if [[ "$filled" == "1" ]]; then
    icon="●"
  else
    icon="○"
  fi

  case "$state" in
    ok|success)
      color="$GREEN"
      ;;
    warn)
      color="$YELLOW"
      ;;
    skip)
      color="$DIM"
      ;;
    *)
      color="$RED"
      ;;
  esac

  printf "%b%s%b" "$color" "$icon" "$RESET"
}

status_label() {
  case "$1" in
    ok|success) printf 'SUCCESS' ;;
    warn) printf 'WARN' ;;
    skip) printf 'SKIP' ;;
    *) printf 'FAIL' ;;
  esac
}

print_header() {
  if have_gum; then
    gum style --bold --border normal --padding '0 1' "backend Health Monitor"
  else
    printf "%bbackend Health Monitor%b\n" "$BOLD$CYAN" "$RESET"
  fi
  printf "verify: %s\n" "$VERIFY_SCRIPT"
  printf "interval: %ss\n" "$INTERVAL_SECONDS"
  printf "sound debounce: %ss\n\n" "$SOUND_DEBOUNCE_SECONDS"
}

render_dashboard() {
  local data="$1"
  local filled="$2"
  local ts overall_state overall_label cause affected root_issues fix_plan checks sections endpoints section_sig
  local overall_circle i line group frame current_group

  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  overall_state="$(jq -r '.overall.status' <<<"$data")"
  overall_label="$(jq -r '.overall.label' <<<"$data")"
  cause="$(jq -r '.overall.cause' <<<"$data")"
  affected="$(jq -r '.overall.affected | if length == 0 then "none" else join(" · ") end' <<<"$data")"
  root_issues="$(jq -r '.root_issues[]? // empty' <<<"$data")"
  fix_plan="$(jq -r '.fix_plan[]? // empty' <<<"$data")"
  checks="$(jq -c '.checks[]' <<<"$data")"
  sections="$(jq -c '.sections[]' <<<"$data")"
  endpoints="$(jq -c '.endpoints[]' <<<"$data")"
  section_sig="$(jq -r '[.sections[] | "\(.name)=\(.status)"] | join("|")' <<<"$data")"
  overall_circle="$(status_circle "$overall_state" "$filled")"

  frame="$({
    print_header
    printf "%s %b%s%b  %s\n" "$overall_circle" "$BOLD" "$overall_label" "$RESET" "$ts"
    printf "\n${BOLD}STATUS:${RESET}   %s %s\n" "$overall_circle" "$overall_label"
    printf "${BOLD}CAUSE:${RESET}    %s\n" "$cause"
    printf "${BOLD}AFFECTED:${RESET} %s\n" "$affected"

    printf "\n${BOLD}${CYAN}Root Issues${RESET}\n"
    if [[ -n "$root_issues" ]]; then
      printf '%s\n' "$root_issues" | awk '{print NR ". " $0}'
    else
      printf "1. none\n"
    fi

    printf "\n${BOLD}${CYAN}Fix Plan${RESET}\n"
    if [[ -n "$fix_plan" ]]; then
      printf '%s\n' "$fix_plan" | awk '!seen[$0]++ {print NR ". " $0}'
    else
      printf "1. none\n"
    fi

    if [[ "$SHOW_RAW_CHECKS" == "1" ]]; then
      printf "\n${BOLD}${CYAN}Live Checks${RESET}\n\n"
      group=""
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        current_group="$(jq -r '.group' <<<"$line")"
        if [[ "$current_group" != "$group" ]]; then
          group="$current_group"
          printf "─── %s\n" "$group"
        fi
        printf "  %s %b%-7s%b  %-38s %s\n" \
          "$(status_circle "$(jq -r '.status' <<<"$line")" "$filled")" \
          "$([[ "$(jq -r '.status' <<<"$line")" == "ok" ]] && printf '%b' "$GREEN" || [[ "$(jq -r '.status' <<<"$line")" == "warn" ]] && printf '%b' "$YELLOW" || [[ "$(jq -r '.status' <<<"$line")" == "skip" ]] && printf '%b' "$DIM" || printf '%b' "$RED")" \
          "$(status_label "$(jq -r '.status' <<<"$line")")" \
          "$RESET" \
          "$(jq -r '.name' <<<"$line")" \
          "$(jq -r '.message' <<<"$line")"
        if [[ -n "$(jq -r '.fix' <<<"$line")" ]]; then
          printf "    → run: %s\n" "$(jq -r '.fix' <<<"$line")"
        fi
      done <<<"$checks"
    fi

    printf "\n${BOLD}${CYAN}Project Status${RESET}\n"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      printf "  %s %-12s %s\n" \
        "$(status_circle "$(jq -r '.status' <<<"$line")" "$filled")" \
        "$(status_label "$(jq -r '.status' <<<"$line")")" \
        "$(jq -r '.name' <<<"$line")"
    done <<<"$sections"

    printf "\n${BOLD}${CYAN}Endpoints${RESET}\n"
    printf "%-12s %-7s %s\n" "Service" "Status" "Notes"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      printf "%-12s %-7s %s\n" \
        "$(jq -r '.name | sub(" endpoint$"; "")' <<<"$line")" \
        "$(case "$(jq -r '.status' <<<"$line")" in ok|success) printf '✅ OK' ;; warn) printf '⚠️ WARN' ;; fail) printf '❌ FAIL' ;; *) printf '⏳ WAIT' ;; esac)" \
        "$(jq -r '.notes' <<<"$line")"
    done <<<"$endpoints"

    printf "\n${BOLD}${CYAN}Overall${RESET}\n"
    printf "  %s %s\n" "$overall_circle" "$overall_label"
    printf "\n${DIM}Press Ctrl+C to stop monitor.${RESET}\n"
  })"

  enter_alt_screen
  if is_tty && command -v tput >/dev/null 2>&1; then
    tput cup 0 0 2>/dev/null || printf '\033[H'
    tput ed 2>/dev/null || printf '\033[J'
  else
    printf '\033[H\033[J'
  fi
  printf '%s' "$frame"

  if [[ "$overall_state" != "$LAST_OVERALL_STATE" || "$section_sig" != "${LAST_SECTION_SIG:-}" ]]; then
    if [[ "$overall_state" == "ok" ]]; then
      play_sound success
      tmux_notice "SUCCESS" "backend health is up and running"
      desktop_notice "backend Health" "UP AND RUNNING"
    else
      play_sound fail
      tmux_notice "FAIL" "backend health is halted"
      desktop_notice "backend Health" "HALTED"
    fi
    LAST_OVERALL_STATE="$overall_state"
    LAST_SECTION_SIG="$section_sig"
  fi
}
