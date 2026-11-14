#!/usr/bin/env bash
# Repeatable audit: the checks that used to be manual bug-hunting, one command.
#
#   bash ops/audit.sh [--ci] [--deep] [--live] [--allow-missing-restsift]
#   mise run audit | audit:ci | audit:deep | audit:live
#
#   --ci    ops/ci.sh: validate-config, lint:shell, the bats suite (arg, path,
#           managed-writer and single-owner contracts included), nix flake
#           check, host evaluation. The deterministic gate.
#   --deep  restsift (`res`), local only: arch check gated at error, refactor
#           scan (FAIL on a CRITICAL target, priority >= 90), duplicate rate
#           (WARN above 3%), `verify shell` over every tracked shell script
#           (FAIL on ShellCheck errors), advisory git-history signals.
#           Everything restsift writes goes to a temp dir; the worktree must be
#           unchanged at the end.
#   --live  this machine, read-only: chezmoi drift, failed user units,
#           nix-profile vs Home Manager conflicts, last sys-update run, a dirty
#           main checkout, stale codebase-memory projects.
#   (none)  all three; --deep and --live degrade to WARN when their tools are
#           missing.
#
# Each line is PASS, WARN or FAIL; the summary counts them. Exit 1 on any FAIL,
# 2 on a bad argument. WARN never changes the exit status.
#
# Tunables: AUDIT_CRITICAL_PRIORITY (90), AUDIT_DUPE_WARN_PCT (3),
# AUDIT_HOTSPOT_FIX_RATIO (0.5), AUDIT_HOTSPOT_MIN_TOUCHES (5),
# AUDIT_SYSUPDATE_MAX_AGE_DAYS (14).
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: bash ops/audit.sh [--ci] [--deep] [--live] [--allow-missing-restsift] [-h|--help]
  --ci      run ops/ci.sh (the deterministic gate)
  --deep    restsift arch/refactor/dupes/shell/history checks (needs `res`)
  --live    read-only checks of this machine (chezmoi, systemd, nix profile,
            last sys-update, main checkout, codebase-memory index)
  (none)    all three; --deep/--live degrade to WARN when their tools are missing
  --allow-missing-restsift   with --deep: a missing `res` is a WARN, not a FAIL
Prints PASS/WARN/FAIL lines and a summary; exits 1 on any FAIL, 2 on a bad argument.
USAGE
}

want_ci=0 want_deep=0 want_live=0 allow_missing=0 explicit=0
for a in "$@"; do
  case "$a" in
    -h | --help) usage; exit 0 ;;
    --ci) want_ci=1; explicit=1 ;;
    --deep) want_deep=1; explicit=1 ;;
    --live) want_live=1; explicit=1 ;;
    --allow-missing-restsift) allow_missing=1 ;;
    *) printf 'audit: unknown argument: %s\n' "$a" >&2; usage >&2; exit 2 ;;
  esac
done
if ((!explicit)); then want_ci=1 want_deep=1 want_live=1; fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
# shellcheck source=ops/lib/profile-conflicts.sh
source "$ROOT/ops/lib/profile-conflicts.sh"
# shellcheck source=ops/lib/state-lock.sh
source "$ROOT/ops/lib/state-lock.sh"

n_pass=0 n_warn=0 n_fail=0
pass() { n_pass=$((n_pass + 1)); printf 'PASS  %s\n' "$*"; }
warn() { n_warn=$((n_warn + 1)); printf 'WARN  %s\n' "$*"; }
fail() { n_fail=$((n_fail + 1)); printf 'FAIL  %s\n' "$*"; }
section() { printf '\n== %s ==\n' "$*"; }
indent() { sed 's/^/        /'; }
have() { command -v "$1" >/dev/null 2>&1; }

AUDIT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/audit.XXXXXX")"
trap 'rm -rf "$AUDIT_TMP"' EXIT
# Nothing restsift (or anything else here) writes may land in the repository.
export AI_LOG_DIR="$AUDIT_TMP/ai-logs"
mkdir -p "$AI_LOG_DIR"
export TMPDIR="$AUDIT_TMP"

CRITICAL_PRIORITY="${AUDIT_CRITICAL_PRIORITY:-90}"
DUPE_WARN_PCT="${AUDIT_DUPE_WARN_PCT:-3}"
HOTSPOT_FIX_RATIO="${AUDIT_HOTSPOT_FIX_RATIO:-0.5}"
HOTSPOT_MIN_TOUCHES="${AUDIT_HOTSPOT_MIN_TOUCHES:-5}"
SYSUPDATE_MAX_AGE_DAYS="${AUDIT_SYSUPDATE_MAX_AGE_DAYS:-14}"

in_git() { git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; }
# Everything git can see that differs from a clean checkout, ignored files
# included, so a tool that drops a cache directory is noticed.
tree_state() { git -C "$ROOT" status --porcelain=v1 --ignored 2>/dev/null; }

# ---------------------------------------------------------------- ci
audit_ci() {
  section "ci"
  if bash "$ROOT/ops/ci.sh"; then
    pass "ci: ops/ci.sh passed"
  else
    fail "ci: ops/ci.sh failed (run: bash ops/ci.sh)"
  fi
}

# ---------------------------------------------------------------- deep
missing_tool() { # missing_tool SECTION TOOL HINT
  local level=warn
  # An explicit --deep wants the real thing; the bare default degrades.
  if ((explicit && !allow_missing)); then level=fail; fi
  "$level" "$1: $2 not found. $3"
}

# list_shell_scripts: tracked *.sh plus extensionless ~/.local/bin helpers with
# a shell shebang (the set ops/lint-shell.sh checks), NUL-separated.
list_shell_scripts() {
  local f
  git -C "$ROOT" ls-files -z -- '*.sh'
  while IFS= read -r -d '' f; do
    [[ "$f" == *.tmpl || "$f" == *.sh ]] && continue
    head -n1 "$ROOT/$f" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b' && printf '%s\0' "$f"
  done < <(git -C "$ROOT" ls-files -z -- 'home/dot_local/bin/executable_*')
}

deep_arch() {
  local out
  if out="$(res arch check --grade source --loc --fragmentation --subdirs-warn-at 12 --depth-warn-at 6 \
    --fail-on-findings --fail-grade error 2>&1)"; then
    pass "arch: res arch check passed at error grade (policy .directory-size.env)"
  else
    fail "arch: res arch check found error-grade structure problems"
    printf '%s\n' "$out" | tail -n 12 | indent
  fi
}

deep_refactor() {
  local out top critical
  if ! out="$(res refactor scan --json --detail ranked --no-report --quiet 2>"$AUDIT_TMP/scan.err")" \
    || ! jq -e '.ranking' >/dev/null 2>&1 <<<"$out"; then
    fail "refactor: res refactor scan did not produce a ranking ($(head -n1 "$AUDIT_TMP/scan.err" 2>/dev/null))"
    return
  fi
  top="$(jq -r '.ranking[:5][] | "\(.priority)\t\(.severity)\t\(.path)"' <<<"$out")"
  critical="$(jq -r --argjson c "$CRITICAL_PRIORITY" '[.ranking[] | select(.priority >= $c)] | length' <<<"$out")"
  if ((critical > 0)); then
    fail "refactor: $critical target(s) at priority >= $CRITICAL_PRIORITY (CRITICAL)"
  else
    pass "refactor: no target at priority >= $CRITICAL_PRIORITY"
  fi
  if [[ -n "$top" ]]; then
    printf '        top 5 by priority:\n'
    printf '%s\n' "$top" | awk -F'\t' '{printf "          %3s  %-8s %s\n", $1, $2, $3}'
  fi
}

deep_dupes() {
  local out rate
  if ! out="$(res refactor-scan dupes --json --no-report --quiet 2>/dev/null)" \
    || ! rate="$(jq -er '.content.dupes.rate | select(type == "number")' <<<"$out" 2>/dev/null)"; then
    fail "dupes: res refactor-scan dupes did not report a rate"
    return
  fi
  if awk -v r="$rate" -v t="$DUPE_WARN_PCT" 'BEGIN { exit !(r > t) }'; then
    warn "dupes: duplicate rate ${rate}% is above ${DUPE_WARN_PCT}%"
  else
    pass "dupes: duplicate rate ${rate}% (limit ${DUPE_WARN_PCT}%)"
  fi
}

deep_shell() {
  local files=() f out bad warnings
  while IFS= read -r -d '' f; do files+=("$f"); done < <(list_shell_scripts)
  if ((${#files[@]} == 0)); then
    fail "shell: no tracked shell scripts found (a scan of nothing is not a pass)"
    return
  fi
  # res exits non-zero for any finding (format included); read the JSON.
  out="$(res verify shell --json "${files[@]}" 2>/dev/null)"
  if ! jq -e '.files' >/dev/null 2>&1 <<<"$out"; then
    fail "shell: res verify shell produced no per-file result"
    return
  fi
  # Syntax errors, and ShellCheck findings at error level. SC2148 (no shebang)
  # is expected in nix/modules/home/scripts/*.sh: Nix wraps them.
  bad="$(jq -r '
    .files[] | .path as $p | .checks[]
    | select((.check == "syntax" and .status == "failed") or (.check == "shellcheck" and .status == "failed"))
    | if .check == "syntax" then "\($p): syntax error"
      else ((.output // "") | [scan("SC([0-9]+) \\(error\\)") | .[0]]
            | map(select(. != "2148" or ($p | test("^nix/modules/home/scripts/[^/]+\\.sh$") | not)))
            | unique | select(length > 0) | "\($p): ShellCheck error SC" + join(", SC")) end' <<<"$out")"
  warnings="$(jq -r '[.files[].checks[] | select(.check == "shellcheck" and .status == "failed")] | length' <<<"$out")"
  if [[ -n "$bad" ]]; then
    fail "shell: $(printf '%s\n' "$bad" | wc -l | tr -d ' ') file(s) with syntax or ShellCheck error findings"
    printf '%s\n' "$bad" | indent
  else
    pass "shell: ${#files[@]} scripts, no syntax or error-level ShellCheck findings ($warnings with warning-level findings, advisory)"
  fi
}

# history_base: merge-base with origin/main, else HEAD~20.
history_base() {
  local b
  b="$(git -C "$ROOT" merge-base origin/main HEAD 2>/dev/null)" && [[ -n "$b" ]] && { printf '%s\n' "$b"; return; }
  git -C "$ROOT" rev-parse --verify -q 'HEAD~20' 2>/dev/null
}

deep_history() {
  local base out lines
  if ! in_git; then warn "history: not a git checkout; skipped"; return; fi
  base="$(history_base)"
  if [[ -z "$base" ]]; then
    warn "history: no origin/main merge-base and fewer than 21 commits; missing-companions skipped"
  else
    if out="$(res git history missing-companions "$base...HEAD" --json 2>/dev/null)" && jq -e '.result.companions' >/dev/null 2>&1 <<<"$out"; then
      lines="$(jq -r '[.result.companions[] | select(.status == "live")
        | "\(.path)  (usually changes with \([.associations[].changed_file] | unique | (.[:3] | join(", ")) + (if length > 3 then " +\(length - 3) more" else "" end)))"] | .[:8][]' <<<"$out")"
      if [[ -n "$lines" ]]; then
        warn "history: files that usually change together with this branch but did not (advisory)"
        printf '%s\n' "$lines" | indent
      else
        pass "history: no missing companions for ${base:0:9}...HEAD"
      fi
    else
      warn "history: res git history missing-companions failed"
    fi
  fi
  if out="$(res git history rework --json 2>/dev/null)" && jq -e '.result.files' >/dev/null 2>&1 <<<"$out"; then
    lines="$(jq -r '[.result.files[] | select(.status == "live")] | .[:5][]
      | "\(.path)  \(.adjusted.touches) touches, \((.adjusted.windows["7d"].rework_rate // 0) * 100 | floor)% reworked within 7 days"' <<<"$out")"
    if [[ -n "$lines" ]]; then
      warn "rework: top 5 live files by rework (advisory)"
      printf '%s\n' "$lines" | indent
    else
      pass "rework: no live file with rework history"
    fi
  else
    warn "rework: res git history rework failed"
  fi
  if out="$(res git history hotspots --json 2>/dev/null)" && jq -e '.result.files' >/dev/null 2>&1 <<<"$out"; then
    lines="$(jq -r --argjson r "$HOTSPOT_FIX_RATIO" --argjson m "$HOTSPOT_MIN_TOUCHES" '
      [.result.files[] | select(.status == "live" and .adjusted.touches >= $m and .adjusted.fix_touch_ratio >= $r)]
      | sort_by(-.adjusted.fix_touch_ratio) | .[:8][]
      | "\(.path)  \((.adjusted.fix_touch_ratio * 100) | floor)% of \(.adjusted.touches) touches were fixes"' <<<"$out")"
    if [[ -n "$lines" ]]; then
      warn "hotspots: live files with fix ratio >= $(awk -v r="$HOTSPOT_FIX_RATIO" 'BEGIN { printf "%d", r * 100 }')% over at least $HOTSPOT_MIN_TOUCHES touches (advisory)"
      printf '%s\n' "$lines" | indent
    else
      pass "hotspots: no live file with a fix ratio >= ${HOTSPOT_FIX_RATIO}"
    fi
  else
    warn "hotspots: res git history hotspots failed"
  fi
}

audit_deep() {
  section "deep (restsift)"
  if ! have res; then
    missing_tool "deep" "restsift (res)" "Install: add restsift to your PATH (https://github.com/UtmostCreator/restsift) and re-run; or pass --allow-missing-restsift."
    return
  fi
  if ! have jq; then fail "deep: jq not found (needed to read restsift JSON)"; return; fi
  local before after
  in_git && before="$(tree_state)"
  deep_arch
  deep_refactor
  deep_dupes
  deep_shell
  deep_history
  if in_git; then
    after="$(tree_state)"
    if [[ "$before" == "$after" ]]; then
      pass "worktree: unchanged by the restsift checks"
    else
      fail "worktree: the restsift checks changed the repository (AI_LOG_DIR=$AI_LOG_DIR)"
      diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | indent
    fi
  fi
}

# ---------------------------------------------------------------- live
live_chezmoi() {
  if ! have chezmoi; then warn "chezmoi: not installed; drift not checked"; return; fi
  local status_out edited=() target source dest pending
  if ! status_out="$(chezmoi status 2>&1)"; then
    warn "chezmoi: chezmoi status failed: $(head -n1 <<<"$status_out")"
    return
  fi
  # Same test as ops/update-all.sh: first column M = the target was edited
  # since chezmoi wrote it. A target owned by a modify_ script never prompts.
  mapfile -t edited < <(awk 'substr($0,1,1)=="M" && substr($0,2,1)!=" " {print substr($0,4)}' <<<"$status_out")
  local conflicts=()
  if ((${#edited[@]})); then
    dest="$(chezmoi target-path 2>/dev/null || true)"
    for target in "${edited[@]}"; do
      source="$(chezmoi source-path "${dest:-$HOME}/$target" 2>/dev/null || true)"
      [[ "${source##*/}" == modify_* ]] && continue
      conflicts+=("$target")
    done
  fi
  pending="$(grep -c . <<<"$status_out" || true)"
  if ((${#conflicts[@]})); then
    fail "chezmoi: ${#conflicts[@]} managed file(s) edited by hand (sys-update refuses to run): ${conflicts[*]}"
    printf '        port the edit into the repo source, or: chezmoi diff\n'
  elif ((pending > 0)); then
    warn "chezmoi: $pending pending change(s) (chezmoi diff; sys-update applies them)"
  else
    pass "chezmoi: managed files in sync"
  fi
}

live_systemd() {
  if [[ "$(uname -s)" != Linux ]]; then pass "systemd: n/a on $(uname -s)"; return; fi
  if ! have systemctl; then warn "systemd: systemctl not found; user units not checked"; return; fi
  local out units
  if ! out="$(systemctl --user --failed --no-legend --plain 2>&1)"; then
    warn "systemd: cannot query the user manager: $(head -n1 <<<"$out")"
    return
  fi
  units="$(awk 'NF {print $1}' <<<"$out" | paste -sd' ' -)"
  if [[ -n "$units" ]]; then
    fail "systemd: failed user unit(s): $units (systemctl --user status <unit>)"
  else
    pass "systemd: no failed user units"
  fi
}

# host_profile: HOST_PROFILE, else ops/detect-host.sh.
host_profile() { printf '%s\n' "${HOST_PROFILE:-$(bash "$ROOT/ops/detect-host.sh" 2>/dev/null)}"; }

live_nix_profile() {
  local host manifest out conflicts
  host="$(host_profile)"
  case "$host" in
    linux-desktop | linux-cli | wsl) ;;
    macos) pass "nix-profile: n/a on macOS (nix-darwin, no Home Manager profile)"; return ;;
    *) warn "nix-profile: unknown host profile '$host'; conflicts not checked"; return ;;
  esac
  manifest="${HM_PROFILE_MANIFEST:-$HOME/.nix-profile/manifest.json}"
  if ! have jq || ! have nix; then warn "nix-profile: needs jq and nix; conflicts not checked"; return; fi
  if [[ ! -f "$manifest" ]]; then pass "nix-profile: no profile manifest, nothing hand-installed"; return; fi
  # Evaluate, do not build: when the activation package is already in the
  # store (sys-update built it) the check is free, otherwise skip it.
  if ! out="$(nix eval --raw "path:$ROOT/nix#homeConfigurations.$host.activationPackage.outPath" 2>/dev/null)" || [[ -z "$out" ]]; then
    warn "nix-profile: could not evaluate the $host activation package; conflicts not checked"
    return
  fi
  if [[ ! -d "$out/home-path" ]]; then
    warn "nix-profile: the $host activation package is not built yet; run: nix build --no-link \"path:$ROOT/nix#homeConfigurations.$host.activationPackage\" then re-run"
    return
  fi
  conflicts="$(profile_hm_conflicts "$manifest" "$out/home-path")"
  if [[ -n "$conflicts" ]]; then
    fail "nix-profile: hand-installed package(s) collide with Home Manager: $(awk -F'\t' '{printf "%s ships %s; ", $1, $2}' <<<"$conflicts")"
    printf '        fix: nix profile remove %s\n' "$(cut -f1 <<<"$conflicts" | sort -u | paste -sd' ' -)"
  else
    pass "nix-profile: no collision between hand-installed packages and Home Manager"
  fi
}

live_sysupdate() {
  local dir meta last status code mtime age
  dir="$(sys_update_state_dir)"
  last="$dir/last-run"
  if [[ -f "$last" ]]; then meta="$(head -n1 "$last")"; fi
  if [[ -z "${meta:-}" || ! -f "$meta" ]]; then
    meta="$(find "$dir/runs" -maxdepth 1 -name '*.meta' -type f 2>/dev/null | sort | tail -n1)"
  fi
  if [[ -z "$meta" || ! -f "$meta" ]]; then
    warn "sys-update: no run recorded in $dir"
    return
  fi
  status="$(grep '^status=' "$meta" | tail -n1 | cut -d= -f2-)"
  code="$(grep '^exit_code=' "$meta" | tail -n1 | cut -d= -f2-)"
  mtime="$(stat -c %Y "$meta" 2>/dev/null || stat -f %m "$meta" 2>/dev/null || echo 0)"
  age=$(( ($(date +%s) - mtime) / 86400 ))
  if [[ "$status" == "done" && "${code:-0}" == 0 ]]; then
    if ((age > SYSUPDATE_MAX_AGE_DAYS)); then
      warn "sys-update: last run succeeded ${age} days ago ($(basename "$meta" .meta)); run: sys-update"
    else
      pass "sys-update: last run succeeded ${age} day(s) ago ($(basename "$meta" .meta))"
    fi
  elif [[ "$status" == "started" ]]; then
    fail "sys-update: last run never finished ($(basename "$meta" .meta)); see $(grep '^log=' "$meta" | cut -d= -f2-)"
  else
    fail "sys-update: last run ${status:-unknown} with exit code ${code:-?} ($(basename "$meta" .meta)); see $(grep '^log=' "$meta" | cut -d= -f2-)"
  fi
}

live_main_checkout() {
  local common main dirty n
  if ! in_git; then warn "checkout: not a git checkout"; return; fi
  common="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  main="${common%/.git}"
  [[ -d "$main" ]] || main="$ROOT"
  dirty="$(git -C "$main" status --porcelain 2>/dev/null)"
  if [[ -n "$dirty" ]]; then
    n="$(grep -c . <<<"$dirty")"
    warn "checkout: $main has $n uncommitted change(s); sys-update refuses a dirty worktree"
    printf '%s\n' "$dirty" | head -n 10 | indent
    ((n > 10)) && printf '        ... and %d more\n' $((n - 10))
  else
    pass "checkout: $main is clean"
  fi
}

live_cbm_index() {
  local out text stale=() name root
  if ! have codebase-memory-mcp; then warn "cbm: codebase-memory-mcp not installed; index not checked"; return; fi
  if ! have jq; then warn "cbm: jq not found; index not checked"; return; fi
  if ! out="$(codebase-memory-mcp cli --quiet --json list_projects 2>/dev/null)" \
    || ! text="$(jq -er '.content[0].text' <<<"$out" 2>/dev/null)"; then
    warn "cbm: could not list projects"
    return
  fi
  # Lines: "  <name> <root_path> <branch>".
  while read -r name root _; do
    [[ -n "$name" && "$root" == /* ]] || continue
    if [[ "$root" == /tmp/* || "$root" == /var/folders/* || "$root" == /private/tmp/* || ! -d "$root" ]]; then
      stale+=("$name"$'\t'"$root")
    fi
  done < <(grep -E '^  [^ ]+ /' <<<"$text")
  if ((${#stale[@]})); then
    warn "cbm: ${#stale[@]} indexed project(s) live under /tmp or no longer exist"
    local s i=0
    for s in "${stale[@]}"; do
      ((++i > 10)) && break
      printf '        codebase-memory-mcp cli delete_project --project %q   # %s\n' "${s%%$'\t'*}" "${s#*$'\t'}"
    done
    ((${#stale[@]} > 10)) && printf '        ... and %d more\n' $((${#stale[@]} - 10))
  else
    pass "cbm: every indexed project root exists outside /tmp"
  fi
}

audit_live() {
  section "live (this machine, read-only)"
  local before after
  in_git && before="$(tree_state)"
  live_chezmoi
  live_systemd
  live_nix_profile
  live_sysupdate
  live_main_checkout
  live_cbm_index
  if in_git; then
    after="$(tree_state)"
    if [[ "$before" == "$after" ]]; then
      pass "worktree: unchanged by the live checks"
    else
      fail "worktree: the live checks changed the repository"
      diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | indent
    fi
  fi
}

# ---------------------------------------------------------------- run
((want_ci)) && audit_ci
((want_deep)) && audit_deep
((want_live)) && audit_live

section "summary"
printf 'PASS %d  WARN %d  FAIL %d\n' "$n_pass" "$n_warn" "$n_fail"
((n_fail == 0))
