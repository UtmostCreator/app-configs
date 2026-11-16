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
#           main checkout, stale codebase-memory projects, oversized temp and
#           agent scratch space (APP_CONFIGS_AUDIT_TMP_WARN_GB, default 20;
#           APP_CONFIGS_AUDIT_TMP_FS_WARN_PCT, default 90; warn only, never deletes).
#   (none)  all three; --deep and --live degrade to WARN when their tools are
#           missing.
#
# Each line is PASS, WARN or FAIL; the summary counts them. Exit 1 on any FAIL,
# 2 on a bad argument. WARN never changes the exit status.
#
# Tunables: AUDIT_CRITICAL_PRIORITY (90), AUDIT_DUPE_WARN_PCT (3),
# AUDIT_HOTSPOT_FIX_RATIO (0.5), AUDIT_HOTSPOT_MIN_TOUCHES (5),
# AUDIT_SYSUPDATE_MAX_AGE_DAYS (14).
# Scratch check (--live): APP_CONFIGS_AUDIT_TMP_WARN_GB (20, a policy default,
# whole GB), APP_CONFIGS_AUDIT_TMP_WARN_KB (overrides the GB limit; for tests),
# APP_CONFIGS_AUDIT_TMP_FS_WARN_PCT (90), APP_CONFIGS_AUDIT_AGENT_SCRATCH
# (default /tmp/claude-<uid>), APP_CONFIGS_AUDIT_TMP_DU_TIMEOUT (30 seconds).
set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: bash ops/audit.sh [--ci] [--deep] [--live] [--allow-missing-restsift] [-h|--help]
  --ci      run ops/ci.sh (the deterministic gate)
  --deep    restsift arch/refactor/dupes/shell/history checks (needs `res`)
  --live    read-only checks of this machine (chezmoi, systemd, nix profile,
            last sys-update, main checkout, codebase-memory index,
            temp and agent scratch size)
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
# shellcheck source=ops/lib/hm-switch.sh
source "$ROOT/ops/lib/hm-switch.sh"
# shellcheck source=ops/lib/selection.sh
source "$ROOT/ops/lib/selection.sh"
# shellcheck source=ops/lib/state-lock.sh
source "$ROOT/ops/lib/state-lock.sh"
# shellcheck source=ops/lib/chezmoi-source.sh
source "$ROOT/ops/lib/chezmoi-source.sh"

n_pass=0 n_warn=0 n_fail=0
pass() { n_pass=$((n_pass + 1)); printf 'PASS  %s\n' "$*"; }
warn() { n_warn=$((n_warn + 1)); printf 'WARN  %s\n' "$*"; }
fail() { n_fail=$((n_fail + 1)); printf 'FAIL  %s\n' "$*"; }
section() { printf '\n== %s ==\n' "$*"; }
indent() { sed 's/^/        /'; }
have() { command -v "$1" >/dev/null 2>&1; }

ORIG_TMPDIR="${TMPDIR:-/tmp}" # the caller's temp dir, for live_scratch (TMPDIR is redirected below)
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
SCRATCH_WARN_GB="${APP_CONFIGS_AUDIT_TMP_WARN_GB:-20}"
SCRATCH_WARN_KB="${APP_CONFIGS_AUDIT_TMP_WARN_KB:-}" # test-friendly override of the GB threshold
SCRATCH_FS_WARN_PCT="${APP_CONFIGS_AUDIT_TMP_FS_WARN_PCT:-90}"
SCRATCH_AGENT_DIR="${APP_CONFIGS_AUDIT_AGENT_SCRATCH:-/tmp/claude-$(id -u 2>/dev/null || echo 0)}"
SCRATCH_DU_TIMEOUT="${APP_CONFIGS_AUDIT_TMP_DU_TIMEOUT:-30}"
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
  chezmoi_source_set "$ROOT"
  if ! status_out="$(chezmoi ${CHEZMOI_SOURCE_ARGS[@]+"${CHEZMOI_SOURCE_ARGS[@]}"} status 2>&1)"; then
    warn "chezmoi: chezmoi status failed: $(head -n1 <<<"$status_out")"
    return
  fi
  # Same test as ops/update-all.sh: first column M = the target was edited
  # since chezmoi wrote it. A target owned by a modify_ script never prompts.
  mapfile -t edited < <(awk 'substr($0,1,1)=="M" && substr($0,2,1)!=" " {print substr($0,4)}' <<<"$status_out")
  local conflicts=()
  if ((${#edited[@]})); then
    dest="$(chezmoi ${CHEZMOI_SOURCE_ARGS[@]+"${CHEZMOI_SOURCE_ARGS[@]}"} target-path 2>/dev/null || true)"
    for target in "${edited[@]}"; do
      source="$(chezmoi ${CHEZMOI_SOURCE_ARGS[@]+"${CHEZMOI_SOURCE_ARGS[@]}"} source-path "${dest:-$HOME}/$target" 2>/dev/null || true)"
      [[ "${source##*/}" == modify_* ]] && continue
      conflicts+=("$target")
    done
  fi
  pending="$(grep -c . <<<"$status_out" || true)"
  if ((${#conflicts[@]})); then
    fail "chezmoi: ${#conflicts[@]} managed file(s) edited by hand (sys-update refuses to run): ${conflicts[*]}"
    printf '        port the edit into the repo source, or: chezmoi %sdiff\n' "$(chezmoi_source_hint)"
  elif ((pending > 0)); then
    warn "chezmoi: $pending pending change(s) (chezmoi $(chezmoi_source_hint)diff; sys-update applies them)"
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
  local host attr manifest out conflicts
  host="$(host_profile)"
  case "$host" in
    linux-desktop | linux-cli | wsl) ;;
    macos) pass "nix-profile: n/a on macOS (nix-darwin, no Home Manager profile)"; return ;;
    *) warn "nix-profile: unknown host profile '$host'; conflicts not checked"; return ;;
  esac
  manifest="${HM_PROFILE_MANIFEST:-$HOME/.nix-profile/manifest.json}"
  # The flake output for this host (wsl on NixOS is wsl-nixos).
  attr="$(hm_attr "$host")" || { warn "nix-profile: cannot choose the Home Manager output for host $host; conflicts not checked"; return; }
  if ! have jq || ! have nix; then warn "nix-profile: needs jq and nix; conflicts not checked"; return; fi
  if [[ ! -f "$manifest" ]]; then pass "nix-profile: no profile manifest, nothing hand-installed"; return; fi
  # Evaluate, do not build: when the activation package is already in the
  # store (sys-update built it) the check is free, otherwise skip it.
  selection_args
  if ! out="$(nix eval --raw "path:$ROOT/nix#homeConfigurations.$attr.activationPackage.outPath" ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"} 2>/dev/null)" || [[ -z "$out" ]]; then
    warn "nix-profile: could not evaluate the $host activation package; conflicts not checked"
    return
  fi
  if [[ ! -d "$out/home-path" ]]; then
    warn "nix-profile: the $host activation package is not built yet; run: nix build --no-link \"path:$ROOT/nix#homeConfigurations.$attr.activationPackage\"$(selection_args_text) then re-run"
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

# Human size from KiB.
fmt_kb() {
  awk -v k="$1" 'BEGIN { if (k >= 1048576) printf "%.1f GB", k / 1048576; else if (k >= 1024) printf "%d MB", k / 1024; else printf "%d KB", k }'
}

# Detection only: never deletes. One `du -x` (one filesystem) per canonical
# target under `timeout`; permission errors are ignored, the sizes read still
# count. On a timeout the partial output is used as a lower bound; a timeout
# is never a PASS.
live_scratch() {
  local limit_kb t u keep skip out rc total partial pct top n note real audit_real
  local targets=()
  if ! have du; then warn "scratch: du not found; temp and agent scratch growth not checked"; return; fi
  if [[ -n "$SCRATCH_WARN_KB" ]]; then
    [[ "$SCRATCH_WARN_KB" =~ ^(0|[1-9][0-9]*)$ ]] || { warn "scratch: APP_CONFIGS_AUDIT_TMP_WARN_KB is not a whole number; temp growth not checked"; return; }
    limit_kb="$SCRATCH_WARN_KB"
  else
    [[ "$SCRATCH_WARN_GB" =~ ^(0|[1-9][0-9]*)$ ]] || { warn "scratch: APP_CONFIGS_AUDIT_TMP_WARN_GB is not a whole number; temp growth not checked"; return; }
    limit_kb=$((SCRATCH_WARN_GB * 1024 * 1024))
  fi
  [[ "$SCRATCH_FS_WARN_PCT" =~ ^(0|[1-9][0-9]*)$ ]] || SCRATCH_FS_WARN_PCT=90
  audit_real="$(cd -- "$AUDIT_TMP" 2>/dev/null && pwd -P)"
  # Targets are canonical (symlinks resolved). One inside another is counted
  # once, under the outer one, whichever order they come in.
  for t in "$ORIG_TMPDIR" "$SCRATCH_AGENT_DIR"; do
    real="$(cd -- "$t" 2>/dev/null && pwd -P)" || continue
    skip=0 keep=()
    for u in "${targets[@]}"; do
      if [[ "$real" == "$u" || "$real" == "${u%/}"/* ]]; then skip=1; keep+=("$u")
      elif [[ "$u" != "${real%/}"/* ]]; then keep+=("$u")
      fi
    done
    targets=("${keep[@]}")
    ((skip)) || targets+=("$real")
  done
  for t in "${targets[@]}"; do
    have timeout || { warn "scratch: timeout not found; $t not measured"; continue; }
    rc=0
    out="$(timeout "$SCRATCH_DU_TIMEOUT" du -x -k --max-depth=1 -- "$t" 2>/dev/null)" || rc=$?
    top="$(awk -F'\t' -v t="$t" -v a="$audit_real" '$2 != t && $2 != a && $1 ~ /^[0-9]+$/ { print }' <<<"$out" | sort -rn | head -n 5)"
    if ((rc == 124)); then
      partial="$(awk -F'\t' -v t="$t" '$2 != t && $1 ~ /^[0-9]+$/ { s += $1 } END { print s + 0 }' <<<"$out")"
      if ((partial > limit_kb)); then
        warn "scratch: $t holds at least $(fmt_kb "$partial") (du timed out after ${SCRATCH_DU_TIMEOUT}s), above $(fmt_kb "$limit_kb") limit; cleanup is a separate, owner-approved step (this audit never deletes)"
        scratch_top "$t" "$top"
      else
        warn "scratch: $t size unknown, at least $(fmt_kb "$partial") measured (du timed out after ${SCRATCH_DU_TIMEOUT}s; limit $(fmt_kb "$limit_kb"))"
        scratch_top "$t" "$top"
      fi
      continue
    fi
    total="$(awk -v t="$t" -F'\t' '$2 == t { print $1 }' <<<"$out" | tail -n1)"
    if [[ ! "$total" =~ ^[0-9]+$ ]]; then warn "scratch: could not measure $t"; continue; fi
    note=""
    ((rc != 0)) && note=" (partial: some entries unreadable)"
    if ((total > limit_kb)); then
      warn "scratch: $t holds $(fmt_kb "$total")$note, above $(fmt_kb "$limit_kb") limit; cleanup is a separate, owner-approved step (this audit never deletes)"
      scratch_top "$t" "$top"
    else
      pass "scratch: $t holds $(fmt_kb "$total")$note (limit $(fmt_kb "$limit_kb"))"
    fi
  done
  # Free space of the filesystem holding the temp dir (no other disk check exists here).
  if have df && [[ -d "$ORIG_TMPDIR" ]]; then
    pct="$(df -P -- "$ORIG_TMPDIR" 2>/dev/null | awk 'NR == 2 { gsub("%", "", $5); print $5 }')"
    if [[ "$pct" =~ ^(0|[1-9][0-9]*)$ ]] && ((pct >= SCRATCH_FS_WARN_PCT)); then
      warn "scratch: filesystem holding $ORIG_TMPDIR is ${pct}% used (warn at ${SCRATCH_FS_WARN_PCT}%)"
    fi
  fi
}

scratch_top() { # scratch_top TARGET "KB<TAB>PATH lines"
  local n u
  while IFS=$'\t' read -r n u; do
    [[ -n "$u" ]] && printf '        %10s  %s\n' "$(fmt_kb "$n")" "$u"
  done <<<"$2"
  printf '        inspect: du -sh %q/* | sort -h\n' "$1"
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
  live_scratch
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
