#!/usr/bin/env bash
# shellcheck shell=bash
# What only ops/install.sh uses of the local install selection (T-0042):
# selection_write, selection_validate, the present-state table, the prompts and
# the preview. The facts it works from (profiles and groups, the evaluation of
# the installed and the proposed state, the installed generation) live in
# ops/lib/selection-facts.sh, which the read-only selection diff of
# ops/update-all.sh shares; the small argument builder every host build, switch
# and eval call site uses is ops/lib/selection.sh.
#
# Sourced by ops/install.sh only, after ops/lib/selection.sh and
# ops/lib/selection-facts.sh (it uses their functions and variables). A grep
# rule in tests/bash/install-selection.bats keeps every other script from
# sourcing it or calling its prompt, preview or write functions. It defines
# functions only. Prompts go to stderr, the preview to stdout. The preview is
# evaluation only (see selection-facts.sh): it builds nothing, so it leaves no
# ./result link and does not touch nix/flake.lock.

SEL_PRESENT_SHOWN=0

# ── input ───────────────────────────────────────────────────────────────────
#
# This file never reads the terminal. The prompts below call selection_read VAR
# PROMPT, which ops/install.sh (the one script that asks) defines: prompt on
# stderr, one line from stdin into VAR, return 1 at end of input.

# selection_write DIR PROFILE [group=true|false ...]
#
# Writes DIR/selection.toml through a temp file in DIR and mv. Only the deltas
# against PROFILE's committed defaults are written, so an answer equal to the
# default adds nothing, and a group or profile that is not declared is refused
# (return 1, nothing written, an existing file untouched).
selection_write() {
  local dir="$1" profile="$2" pair g v d lines="" tmp defaults
  shift 2
  selection_valid_profile "$profile" || { printf 'selection: unknown profile %s\n' "'$profile'" >&2; return 1; }
  defaults="$(selection_group_defaults "$profile")" || return 1
  for pair in "$@"; do
    [[ "$pair" == *=* ]] || { printf 'selection: expected group=true|false, got %s\n' "'$pair'" >&2; return 1; }
    g="${pair%%=*}"
    v="${pair#*=}"
    [[ "$v" == true || "$v" == false ]] || { printf 'selection: group %s must be true or false, got %s\n' "'$g'" "'$v'" >&2; return 1; }
    d="$(printf '%s\n' "$defaults" | awk -F'\t' -v g="$g" '$1 == g { print $2 }')"
    [[ -n "$d" ]] || { printf 'selection: unknown group %s\n' "'$g'" >&2; return 1; }
    if [[ "$v" != "$d" ]]; then lines+="$g = $v"$'\n'; fi
  done
  mkdir -p "$dir" || return 1
  tmp="$(mktemp "$dir/.selection.toml.XXXXXX")" || return 1
  {
    printf 'profile = "%s"\n' "$profile"
    if [[ -n "$lines" ]]; then printf '\n[groups]\n%s' "$lines"; fi
  } >"$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$dir/selection.toml" || { rm -f "$tmp"; return 1; }
}

# selection_validate: evaluates the local selection (SELECTION_ARGS) far enough
# to fail on an unknown key, group or profile. Return 1 with the Nix error on
# stderr; 2 when there is no nix to ask.
selection_validate() {
  command -v nix >/dev/null 2>&1 || return 2
  selection_args
  _sel_eval /dev/null "$SELECTION_WORK/validate.err" "$(_sel_attr_check)" "$(_sel_expr_check)" \
    || { _sel_show_err "$SELECTION_WORK/validate.err"; return 1; }
}

# selection_present_state: installed n/m per group, against the installed
# generation. Only a first install (no generation) uses `command -v`, and then
# only as an annotation, never as a count.
selection_present_state() {
  local label g n m inst names found path members=() casks=() cask_note
  ((SEL_HAVE_FACTS)) || return 0
  SEL_PRESENT_SHOWN=1
  _sel_pnames "$SELECTION_WORK/i-pkgs.tsv" >"$SELECTION_WORK/i-names.txt"
  printf 'Present state (installed packages by group)\n'
  _sel_sets
  for g in "${SEL_SETS[@]+"${SEL_SETS[@]}"}"; do
    label="$(_sel_set_label "$g")"
    _sel_split members "$(_sel_members_of "$g")"
    m=${#members[@]}
    if [[ "$SEL_I_STATE" == unknown ]]; then
      printf '  %-14s installed unknown/%s (the installed generation could not be read)\n' "$label" "$m"
      continue
    fi
    inst=0
    names=()
    for n in "${members[@]+"${members[@]}"}"; do
      if _sel_in_file "$n" "$SELECTION_WORK/i-names.txt"; then inst=$((inst + 1)); names+=("$n"); fi
    done
    # macOS: the casks a group gates count against `brew list --cask`.
    cask_note=""
    if [[ "$SELECTION_HOST" == macos ]]; then
      _sel_split casks "$(_sel_cask_members_of "$g")"
      if ((${#casks[@]})); then
        _sel_brew_casks
        if [[ "$SEL_BREW" == ok ]]; then
          m=$((m + ${#casks[@]}))
          for n in "${casks[@]}"; do
            if _sel_in_file "$n" "$SELECTION_WORK/casks-installed.txt"; then inst=$((inst + 1)); names+=("$n"); fi
          done
        else
          cask_note="casks $(_sel_join "${casks[@]}") (cask state unknown)"
        fi
      fi
    fi
    if [[ -n "$cask_note" && "$m" -eq 0 ]]; then
      printf '  %-14s %s\n' "$label" "$cask_note"
      continue
    fi
    if ((${#names[@]})); then
      printf '  %-14s installed %s/%s %s%s\n' "$label" "$inst" "$m" "$(_sel_join "${names[@]}")" "${cask_note:+; $cask_note}"
    else
      printf '  %-14s installed %s/%s%s\n' "$label" "$inst" "$m" "${cask_note:+; $cask_note}"
    fi
    if [[ "$SEL_I_STATE" == none ]]; then
      for n in "${members[@]+"${members[@]}"}"; do
        found=0
        path="$(command -v "$n" 2>/dev/null)" && found=1
        if ((found)); then printf '    %s: on PATH, not from Home Manager: %s\n' "$n" "$path"; fi
      done
    fi
  done
  return 0
}

# selection_propose PROFILE [group=true|false ...]
#
# Writes the proposed selection into SELECTION_WORK/proposed through
# selection_write and evaluates it with the same argument builder as the local
# selection. Returns 1 with the Nix error on stderr.
selection_propose() {
  local dir="$SELECTION_WORK/proposed"
  rm -rf "$dir"
  selection_write "$dir" "$@" || return 1
  selection_override_args "$dir"
  _sel_eval_for proposed "$SELECTION_WORK/p.tsv" "$SELECTION_WORK/p.err" "$(_sel_attr_state)" "$(_sel_expr_state)" \
    || { _sel_show_err "$SELECTION_WORK/p.err"; return 1; }
  _sel_state_packages "$SELECTION_WORK/p.tsv" >"$SELECTION_WORK/p-pkgs.tsv"
}

# ── the preview ─────────────────────────────────────────────────────────────

_sel_snapshot() { if [[ -n "$1" ]]; then printf '%s' "$1"; else printf '%s' "$UVR_EMPTY_SET"; fi; }

_sel_pkg_section() { # _sel_pkg_section HEADER BEFORE-FILE AFTER-FILE
  printf '%s\n' "$1"
  render_package_delta "Home Manager" "$(_sel_snapshot "$(cat "$2")")" "$(_sel_snapshot "$(cat "$3")")"
}

_sel_files_section() { # _sel_files_section HEADER MODE A B
  local row kind target n=0 total rows=()
  printf '%s\n' "$1"
  total="$(_sel_files_delta "$2" "$3" "$4" | grep -c . || true)"
  if ((total == 0)); then printf '    no changes\n'; return 0; fi
  _sel_split rows "$(_sel_files_delta "$2" "$3" "$4")"
  for row in "${rows[@]+"${rows[@]}"}"; do
    kind="${row%%"$_SEL_TAB"*}"
    target="${row#*"$_SEL_TAB"}"
    if ((n < SELECTION_LIST_MAX)); then printf '    %-8s %s%s\n' "$kind" "$target" "$(_sel_unit_note "$target")"; fi
    n=$((n + 1))
  done
  if ((total > SELECTION_LIST_MAX)); then printf '    and %s more\n' "$((total - SELECTION_LIST_MAX))"; fi
}

_sel_chezmoi_section() {
  local out line col n=0 added=0 modified=0 removed=0 scripts=0 total=0 label lines=()
  label="chezmoi files: pending repo changes"
  if [[ "$SELECTION_HOST" != macos ]]; then label+=" (the selection does not change chezmoi on Linux)"; fi
  printf '%s\n' "$label"
  out="$SELECTION_WORK/chezmoi.out"
  _sel_chezmoi_status
  if [[ "$SEL_CHEZMOI" != ok ]]; then
    printf '    unavailable (%s); after install: chezmoi diff\n' "$SEL_CHEZMOI_WHY"
    return 0
  fi
  _sel_split lines "$(cat "$out")"
  for line in "${lines[@]+"${lines[@]}"}"; do
    col="${line:1:1}"
    case "$col" in
      A) added=$((added + 1)) ;;
      M) modified=$((modified + 1)) ;;
      D) removed=$((removed + 1)) ;;
      R) scripts=$((scripts + 1)) ;;
      *) continue ;;
    esac
    total=$((total + 1))
  done
  if ((total == 0)); then printf '    no changes\n'; else
    printf '    added %s, modified %s, removed %s, scripts %s (%s paths)\n' "$added" "$modified" "$removed" "$scripts" "$total"
    for line in "${lines[@]+"${lines[@]}"}"; do
      col="${line:1:1}"
      case "$col" in A | M | D | R) ;; *) continue ;; esac
      if ((n < 20)); then printf '      %s %s\n' "$col" "${line:3}"; fi
      n=$((n + 1))
    done
    if ((total > 20)); then printf '      and %s more\n' "$((total - 20))"; fi
  fi
  printf '    full diff: chezmoi %sdiff\n' "${SEL_CHEZMOI_SOURCE_ARG:+$SEL_CHEZMOI_SOURCE_ARG }"
}

_sel_casks_section() {
  local installed="$SELECTION_WORK/casks-installed.txt" c unmanaged=0 have_c have_p casks=()
  printf 'macOS casks\n'
  _sel_brew_casks
  if [[ "$SEL_BREW" != ok ]]; then
    printf '    cask state unknown (brew not available)\n'
    return 0
  fi
  awk -F '\t' '$1 == "C" { print $2 }' "$SELECTION_WORK/c.tsv" | LC_ALL=C sort -u >"$SELECTION_WORK/casks-c.txt"
  if [[ -f "$SELECTION_WORK/p.tsv" && "$SEL_WITH_PROPOSAL" == 1 ]]; then
    awk -F '\t' '$1 == "C" { print $2 }' "$SELECTION_WORK/p.tsv" | LC_ALL=C sort -u >"$SELECTION_WORK/casks-p.txt"
  else
    cp "$SELECTION_WORK/casks-c.txt" "$SELECTION_WORK/casks-p.txt"
  fi
  _sel_split casks "$(cat "$SELECTION_WORK/casks-p.txt")"
  for c in "${casks[@]+"${casks[@]}"}"; do
    [[ -n "$c" ]] || continue
    if ! _sel_in_file "$c" "$installed"; then printf '    %s: add (installed at the next switch)\n' "$c"; fi
  done
  _sel_split casks "$(cat "$SELECTION_WORK/casks-c.txt")"
  for c in "${casks[@]+"${casks[@]}"}"; do
    [[ -n "$c" ]] || continue
    if ! _sel_in_file "$c" "$SELECTION_WORK/casks-p.txt" && _sel_in_file "$c" "$installed"; then
      printf '    %s: stays installed (Homebrew cleanup = none); remove by hand: brew uninstall --cask %s\n' "$c" "$c"
    fi
  done
  _sel_split casks "$(cat "$installed")"
  for c in "${casks[@]+"${casks[@]}"}"; do
    [[ -n "$c" ]] || continue
    have_c=0; have_p=0
    if _sel_in_file "$c" "$SELECTION_WORK/casks-c.txt"; then have_c=1; fi
    if _sel_in_file "$c" "$SELECTION_WORK/casks-p.txt"; then have_p=1; fi
    if ((have_c == 0 && have_p == 0)); then unmanaged=$((unmanaged + 1)); fi
  done
  printf '    unmanaged installed casks: %s\n' "$unmanaged"
}

# _sel_outcome_section: keep / add / remove / stays off per group, from the
# installed generation (I) and the proposed state (P).
_sel_outcome_section() {
  local g label n keep off parts adds rems names=() casks=() stays cask_note c in_i in_p
  printf 'Outcome by group (installed -> proposed)\n'
  if [[ "$SEL_I_STATE" == unknown ]]; then
    printf '    unknown: the installed generation could not be read, so keep, add and remove cannot be told\n'
    return 0
  fi
  _sel_pnames "$SELECTION_WORK/i-pkgs.tsv" >"$SELECTION_WORK/i-names.txt"
  _sel_pnames "$SELECTION_WORK/p-pkgs.tsv" >"$SELECTION_WORK/p-names.txt"
  _sel_sets
  for g in "${SEL_SETS[@]+"${SEL_SETS[@]}"}"; do
    label="$(_sel_set_label "$g")"
    keep=0; off=0; adds=(); rems=()
    _sel_split names "$(_sel_members_of "$g")"
    for n in "${names[@]+"${names[@]}"}"; do
      [[ -n "$n" ]] || continue
      local in_i=0 in_p=0
      if _sel_in_file "$n" "$SELECTION_WORK/i-names.txt"; then in_i=1; fi
      if _sel_in_file "$n" "$SELECTION_WORK/p-names.txt"; then in_p=1; fi
      if ((in_i && in_p)); then keep=$((keep + 1))
      elif ((in_p)); then adds+=("$n")
      elif ((in_i)); then rems+=("$n")
      else off=$((off + 1)); fi
    done
    # macOS: the casks the group gates. A cask that leaves the list stays installed.
    stays=(); cask_note=""
    if [[ "$SELECTION_HOST" == macos ]]; then
      _sel_split casks "$(_sel_cask_members_of "$g")"
      if ((${#casks[@]})); then
        _sel_brew_casks
        if [[ "$SEL_BREW" == ok ]]; then
          awk -F '\t' '$1 == "C" { print $2 }' "$SELECTION_WORK/p.tsv" | LC_ALL=C sort -u >"$SELECTION_WORK/casks-p.txt"
          for c in "${casks[@]}"; do
            in_i=0; in_p=0
            if _sel_in_file "$c" "$SELECTION_WORK/casks-installed.txt"; then in_i=1; fi
            if _sel_in_file "$c" "$SELECTION_WORK/casks-p.txt"; then in_p=1; fi
            if ((in_i && in_p)); then keep=$((keep + 1))
            elif ((in_p)); then adds+=("$c")
            elif ((in_i)); then stays+=("$c")
            else off=$((off + 1)); fi
          done
        else
          cask_note="casks $(_sel_join "${casks[@]}") (cask state unknown)"
        fi
      fi
    fi
    parts=""
    if ((keep)); then parts+="keep $keep"; fi
    if ((${#adds[@]})); then parts+="${parts:+; }add ${#adds[@]}: $(_sel_join "${adds[@]}")"; fi
    if ((${#rems[@]})); then parts+="${parts:+; }remove ${#rems[@]}: $(_sel_join "${rems[@]}")"; fi
    if ((${#stays[@]})); then parts+="${parts:+; }stays installed ${#stays[@]}: $(_sel_join "${stays[@]}")"; fi
    if ((off)); then parts+="${parts:+; }stays off $off"; fi
    if [[ -n "$cask_note" ]]; then parts+="${parts:+; }$cask_note"; fi
    printf '  %-14s %s\n' "$label" "${parts:-no members}"
  done
}

# _sel_current_section CUR_PROF CUR_OVER: the installed generation and the
# current selection, one line each.
_sel_current_section() {
  local npk sel_file
  sel_file="$(selection_dir)/selection.toml"
  npk="$(grep -c . "$SELECTION_WORK/i-pkgs.tsv" || true)"
  printf '\n'
  case "$SEL_I_STATE" in
    ok) printf 'Installed generation: %s (%s packages); ' "$SEL_I_GEN" "$npk" ;;
    none) printf 'No Home Manager generation yet (first install); ' ;;
    *) printf 'Installed generation: unknown (it could not be read); ' ;;
  esac
  if [[ -f "$sel_file" && "$SEL_C_INVALID" == 0 ]]; then
    printf 'current selection: %s (profile %s%s)\n' "$sel_file" "$1" "${2:+, overrides: $2}"
  elif [[ "$SEL_C_INVALID" == 1 ]]; then
    printf 'current selection: %s is invalid, using the committed default (profile %s)\n' "$sel_file" "$1"
  else
    printf 'current selection: none (committed default, profile %s)\n' "$1"
  fi
  printf '\n'
}

# _sel_proposal_section CUR_PROF CUR_OVER: the proposed profile and overrides,
# the outcome by group and the package comparison, from your selection.
_sel_proposal_section() {
  local new_prof new_over
  new_prof="$(_sel_state_profile "$SELECTION_WORK/p.tsv")"
  new_over="$(_sel_overrides "$SELECTION_WORK/p.tsv")"
  printf 'Preview (nothing applied): profile %s -> %s; overrides: %s\n' "$1" "$new_prof" "${new_over:-none}"
  if ((SEL_REPLACE)) && [[ -n "$2" ]]; then
    printf '  This replaces your existing group overrides (%s); they are dropped.\n' "$2"
  fi
  printf '\n'
  _sel_outcome_section
  printf '\n'
  if [[ "$SEL_I_STATE" == none ]]; then
    # Nothing is installed, so the selection removes nothing; what gets
    # installed is the pending-changes block below and the outcome above.
    printf 'Packages, from your selection\n    nothing is installed yet, so the selection removes nothing (see Outcome by group)\n'
  else
    _sel_pkg_section 'Packages, from your selection' "$SELECTION_WORK/c-pkgs.tsv" "$SELECTION_WORK/p-pkgs.tsv"
  fi
  printf '\n'
}

# selection_preview [proposal]
#
# Prints the whole preview to stdout; "proposal" (after selection_propose) adds
# the blocks that compare the current selection with the proposed one. With no
# proposal only the present state and the pending repo changes are shown. Reads
# the files selection_facts and selection_propose wrote; runs no evaluation, so
# nothing printed can be followed by a failure. SEL_REPLACE=1 (--profile) adds
# the line saying existing group overrides are dropped.
SEL_WITH_PROPOSAL=0
SEL_REPLACE=0
selection_preview() {
  local cur_prof cur_over
  SEL_WITH_PROPOSAL=0
  [[ "${1:-}" == proposal ]] && SEL_WITH_PROPOSAL=1
  ((SEL_HAVE_FACTS)) || return 1
  cur_prof="$(_sel_state_profile "$SELECTION_WORK/c.tsv")"
  cur_over="$(_sel_overrides "$SELECTION_WORK/c.tsv")"
  _sel_current_section "$cur_prof" "$cur_over"
  if ((SEL_PRESENT_SHOWN == 0)); then selection_present_state; printf '\n'; fi
  if ((SEL_WITH_PROPOSAL)); then _sel_proposal_section "$cur_prof" "$cur_over"; fi
  if [[ "$SEL_I_STATE" == unknown ]]; then
    printf 'Packages, pending changes (repo, or a selection not yet applied)\n    unknown (the installed generation could not be read)\n'
  else
    _sel_pkg_section 'Packages, pending changes (repo, or a selection not yet applied)' "$SELECTION_WORK/i-pkgs.tsv" "$SELECTION_WORK/c-pkgs.tsv"
  fi
  printf '\n'
  _sel_state_files "$SELECTION_WORK/c.tsv" >"$SELECTION_WORK/c-files.tsv"
  if ((SEL_WITH_PROPOSAL)); then
    _sel_state_files "$SELECTION_WORK/p.tsv" >"$SELECTION_WORK/p-files.tsv"
    _sel_files_section 'Home Manager files and services, from your selection' exact "$SELECTION_WORK/c-files.tsv" "$SELECTION_WORK/p-files.tsv"
    printf '\n'
  fi
  if [[ "$SEL_I_STATE" == unknown ]]; then
    printf 'Home Manager files and services, pending changes (repo, or a selection not yet applied)\n    unknown (the installed generation could not be read)\n'
  else
    _sel_files_section 'Home Manager files and services, pending changes (repo, or a selection not yet applied)' tree "$SELECTION_WORK/i-files.tsv" "$SELECTION_WORK/c-files.tsv"
  fi
  printf '\n'
  _sel_chezmoi_section
  if [[ "$SELECTION_HOST" == macos ]]; then printf '\n'; _sel_casks_section; fi
  if ((SEL_WITH_PROPOSAL)); then
    # shellcheck disable=SC2016  # a literal $HOME in the message
    printf '\nNote: deselected packages leave PATH at the next switch; files in $HOME and app data stay.\n'
  fi
  printf '\n'
}

# ── the interactive flow ────────────────────────────────────────────────────

SEL_CUR_PROFILE=""
SEL_CUR_NAMES=()
SEL_CUR_VALUES=()
SEL_ANS_PROFILE=""
SEL_ANS_GROUPS=()   # "group=true|false", in group order

_sel_cur_value() { # group -> true|false the prompt starts from, or nothing
  local i
  for i in "${!SEL_CUR_NAMES[@]}"; do
    if [[ "${SEL_CUR_NAMES[$i]}" == "$1" ]]; then printf '%s' "${SEL_CUR_VALUES[$i]}"; return 0; fi
  done
}

# selection_prompt_init: the answers the first pass starts from. Without a local
# selection (or with a valid one) that is the current effective selection; when
# the local file is invalid it is the host's default profile.
selection_prompt_init() {
  local row rows=()
  SEL_CUR_NAMES=(); SEL_CUR_VALUES=()
  if ((SEL_HAVE_FACTS)); then
    SEL_CUR_PROFILE="$(_sel_state_profile "$SELECTION_WORK/c.tsv")"
    _sel_split rows "$(_sel_state_groups "$SELECTION_WORK/c.tsv")"
    for row in "${rows[@]+"${rows[@]}"}"; do SEL_CUR_NAMES+=("${row%%"$_SEL_TAB"*}"); SEL_CUR_VALUES+=("${row#*"$_SEL_TAB"}"); done
  else
    SEL_CUR_PROFILE="$SEL_HOST_PROFILE"
  fi
}

_sel_group_label() { # group -> "group (names)" with a few members
  local names=() n out
  if ((SEL_HAVE_FACTS)); then
    _sel_split names "$(_sel_members_of "$1")"
    if [[ "$SELECTION_HOST" == macos ]]; then
      local casks=() c
      _sel_split casks "$(_sel_cask_members_of "$1")"
      for c in "${casks[@]+"${casks[@]}"}"; do names+=("$c"); done
    fi
  fi
  if ((${#names[@]} == 0)); then printf '%s' "$1"; return 0; fi
  if ((${#names[@]} > 6)); then
    out="$(_sel_join "${names[@]:0:6}") and $((${#names[@]} - 6)) more"
  else
    out="$(_sel_join "${names[@]}")"
  fi
  printf '%s (%s)' "$1" "$out"
}

# _sel_ask_profile: sets SEL_ANS_PROFILE. Returns 1 on quit or end of input.
_sel_ask_profile() {
  local list="" p ans profiles=()
  _sel_split profiles "$(selection_profiles)"
  for p in "${profiles[@]+"${profiles[@]}"}"; do list+="${list:+, }$p"; done
  while true; do
    selection_read ans "Profile ($list; q quits) [$SEL_CUR_PROFILE]: " || return 1
    case "$ans" in
      "") SEL_ANS_PROFILE="$SEL_CUR_PROFILE"; return 0 ;;
      q | Q | quit) return 1 ;;
    esac
    if selection_valid_profile "$ans"; then SEL_ANS_PROFILE="$ans"; return 0; fi
    printf 'Unknown profile %s; choose one of: %s\n' "'$ans'" "$list" >&2
  done
}

# _sel_ask_groups: fills SEL_ANS_GROUPS for SEL_ANS_PROFILE. Each group starts
# from the current value when the profile is the current one, else from the
# profile's committed default.
_sel_ask_groups() {
  local groups=() g def ans hint v row rows=()
  SEL_ANS_GROUPS=()
  if ((${#SEL_GROUPS[@]})); then groups=("${SEL_GROUPS[@]}"); else
    _sel_split rows "$(selection_group_defaults "$SEL_ANS_PROFILE")"
    for row in "${rows[@]+"${rows[@]}"}"; do groups+=("${row%%"$_SEL_TAB"*}"); done
  fi
  for g in "${groups[@]+"${groups[@]}"}"; do
    def="$(selection_group_defaults "$SEL_ANS_PROFILE" | awk -F '\t' -v g="$g" '$1 == g { print $2 }')"
    if [[ "$SEL_ANS_PROFILE" == "$SEL_CUR_PROFILE" ]]; then
      v="$(_sel_cur_value "$g")"
      if [[ -n "$v" ]]; then def="$v"; fi
    fi
    def="${def:-true}"
    if [[ "$def" == true ]]; then hint='[Y/n]'; else hint='[y/N]'; fi
    while true; do
      selection_read ans "  Install group $(_sel_group_label "$g")? $hint: " || return 1
      case "$ans" in
        "") v="$def" ;;
        y | Y | yes | YES) v=true ;;
        n | N | no | NO) v=false ;;
        q | Q | quit) return 1 ;;
        *) printf 'Please answer y, n or q.\n' >&2; continue ;;
      esac
      break
    done
    SEL_ANS_GROUPS+=("$g=$v")
  done
}

# selection_prompt_loop
#
# Present state (once), then profile and group prompts, the preview, and the
# choice [a]pply / [c]hange / [q]uit. Returns 0 on apply with SEL_ANS_PROFILE and
# SEL_ANS_GROUPS set, 3 on quit or end of input, 1 when the proposed selection
# cannot be evaluated. "c" starts the prompts again with the answers pre-filled.
selection_prompt_loop() {
  local ans
  if ((SEL_HAVE_FACTS)); then selection_present_state; printf '\n'; fi
  selection_prompt_init
  while true; do
    _sel_ask_profile || return 3
    _sel_ask_groups || return 3
    if ((SEL_HAVE_FACTS)); then
      selection_propose "$SEL_ANS_PROFILE" ${SEL_ANS_GROUPS[@]+"${SEL_ANS_GROUPS[@]}"} || return 1
      selection_preview proposal
    else
      printf 'preview unavailable: nix not installed\n'
    fi
    while true; do
      selection_read ans '[a]pply  [c]hange selection  [q]uit: ' || return 3
      case "$ans" in
        a | A | apply) return 0 ;;
        q | Q | quit) return 3 ;;
        c | C | change) break ;;
        *) ;;
      esac
    done
    # The answers just given are the new starting point.
    SEL_CUR_PROFILE="$SEL_ANS_PROFILE"
    SEL_CUR_NAMES=(); SEL_CUR_VALUES=()
    local pair
    for pair in ${SEL_ANS_GROUPS[@]+"${SEL_ANS_GROUPS[@]}"}; do SEL_CUR_NAMES+=("${pair%%=*}"); SEL_CUR_VALUES+=("${pair#*=}"); done
  done
}
