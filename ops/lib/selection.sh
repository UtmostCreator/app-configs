#!/usr/bin/env bash
# shellcheck shell=bash
# The one place that turns the local install selection (T-0042) into Nix
# arguments. Sourced by hm-switch.sh, install.sh, bootstrap.sh, update-all.sh
# and audit.sh; every host build, switch and eval call site passes
# SELECTION_ARGS, so a selection is never applied by one script and dropped by
# the next.
#
#   selection_dir    prints the directory that may hold selection.toml
#   selection_args   fills SELECTION_ARGS (empty when there is no local file)
#   selection_args_text   prints " <args>" for messages, or nothing
#
# Below the argument builder sits what only ops/install.sh uses (a grep rule in
# tests/bash/install-selection.bats keeps every other script away from it):
# selection_write, selection_facts, selection_present_state, selection_propose,
# selection_preview and the prompts. They define functions only. The preview
# code of ops/update-version-report.sh is loaded inside selection_facts, so
# hm-switch.sh, bootstrap.sh and audit.sh never load it.
#
# SELECTION_ARGS is `--override-input selection path:<absolute dir>` only when
# <dir>/selection.toml exists. The override implies --no-write-lock-file, so
# nix/flake.lock is not touched. Pass it as
#   ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"}
# (an empty array is an unbound variable under set -u before bash 4.4).
#
# The path is percent-encoded for the URL (space, ?, # and %), so a directory
# name with those characters is neither misparsed nor taken for another path.
# Those four characters are the only ones encoded: a directory name holding other
# shell-special characters (quote, $, backtick, ;) is printed as is, so the
# printed form is not guaranteed safe to paste into a shell.
# The directory is made absolute here, before any sudo: sudo may change HOME,
# and a relative path would mean something else inside the build.
# Validators, CI and `nix flake check` do not source this file: they evaluate
# the committed default selection.
#
# Test override: APP_CONFIGS_SELECTION_DIR (taken as given). Otherwise the
# directory is built from XDG_CONFIG_HOME or $HOME, so on WSL2 it is under the
# Linux $HOME. An XDG_CONFIG_HOME on a Windows drive (/mnt/<letter>) is ignored
# with a note on stderr and $HOME/.config is used instead.

SELECTION_ARGS=()
SELECTION_OVERRIDE=()
SELECTION_DIR=""

selection_dir() {
  local base
  if [[ -n "${APP_CONFIGS_SELECTION_DIR:-}" ]]; then
    printf '%s\n' "$APP_CONFIGS_SELECTION_DIR"
    return 0
  fi
  base="${XDG_CONFIG_HOME:-$HOME/.config}"
  case "$base" in
    /mnt/[a-zA-Z] | /mnt/[a-zA-Z]/*)
      # WSL2: a Windows drive mount is not where a Linux selection lives (slow,
      # no Unix permissions, shared with Windows tools). Use the Linux $HOME.
      printf 'selection: ignoring XDG_CONFIG_HOME=%s (a Windows drive under /mnt); using %s/.config\n' "$base" "$HOME" >&2
      base="$HOME/.config"
      ;;
  esac
  printf '%s\n' "$base/app-configs/selection"
}

# selection_url_path PATH: PATH with the characters that break a Nix `path:` URL
# percent-encoded. `%` first, so the others are not encoded twice.
selection_url_path() {
  local p="$1" pct='%' hash='#' q='?' space=' '
  p="${p//"$pct"/%25}"
  p="${p//"$space"/%20}"
  p="${p//"$q"/%3F}"
  p="${p//"$hash"/%23}"
  printf '%s' "$p"
}

# selection_override_args DIR: fills SELECTION_OVERRIDE for the selection in DIR
# (empty when DIR has no selection.toml). The one builder of the flag, used for
# the local selection and for the proposed one the preview evaluates.
selection_override_args() {
  local dir="$1" abs
  SELECTION_OVERRIDE=()
  [[ -f "$dir/selection.toml" ]] || return 0
  abs="$(cd "$dir" 2>/dev/null && pwd -P)" || return 0
  SELECTION_OVERRIDE=(--override-input selection "path:$(selection_url_path "$abs")")
}

# selection_override_text DIR: the flag as it would be passed once DIR holds a
# selection (for a dry run that writes nothing); DIR is used as given.
selection_override_text() {
  printf -- '--override-input selection path:%s' "$(selection_url_path "$1")"
}

selection_args() {
  SELECTION_ARGS=()
  SELECTION_DIR="$(selection_dir)"
  selection_override_args "$SELECTION_DIR"
  if ((${#SELECTION_OVERRIDE[@]})); then SELECTION_ARGS=("${SELECTION_OVERRIDE[@]}"); fi
}

selection_args_text() {
  if ((${#SELECTION_ARGS[@]})); then
    printf ' %s' "${SELECTION_ARGS[*]}"
  fi
}

# ── What only ops/install.sh uses: write, prompts and the preview (T-0042 T5) ──
#
# Context. ops/install.sh sets SELECTION_REPO_ROOT, SELECTION_HOST (HOST_PROFILE)
# and SELECTION_WORK, a private temp dir it removes on exit (its CLEANUP trap).
# Prompts go to stderr, the preview to stdout. The preview is evaluation only:
# `nix eval` with import-from-derivation off, `nix-store -q --references` on the
# installed generation, `chezmoi status` and `brew list`. It builds nothing, so
# it leaves no ./result link and does not touch nix/flake.lock.

SELECTION_REPO_ROOT=""
SELECTION_HOST=""
SELECTION_WORK=""
# Package-name prefixes the comparison ignores. dummy-xdg-mime-dirs is in
# home.packages but home-path does not reference it, so it would show up as an
# addition in every comparison against an installed generation.
SELECTION_PKG_NOISE=(dummy-xdg-mime-dirs)
# HM files shown per section before "and N more".
SELECTION_LIST_MAX=30

_SEL_LIB_DIR="${BASH_SOURCE[0]%/*}"

# This code runs under /bin/bash 3.2 on a fresh Mac (install.sh): no bash 4 array
# builtins, associative arrays or case-modifying expansions; empty arrays are
# expanded as ${a[@]+"${a[@]}"}; $'..' is never used inside ${..}.
_SEL_TAB=$'\t'
_SEL_NL=$'\n'

# _sel_split NAME TEXT: the lines of TEXT, one array element each, into NAME
# (the array of the calling function when it declares one). Parameter expansion
# only: no bash 4 builtin and no read.
_sel_split() {
  local __sel_name="$1" __sel_rest="$2" __sel_line
  eval "$__sel_name=()"
  while [[ -n "$__sel_rest" ]]; do
    __sel_line="${__sel_rest%%"$_SEL_NL"*}"
    if [[ "$__sel_rest" == *"$_SEL_NL"* ]]; then __sel_rest="${__sel_rest#*"$_SEL_NL"}"; else __sel_rest=""; fi
    eval "$__sel_name+=(\"\$__sel_line\")"
  done
}

_sel_repo() {
  if [[ -n "$SELECTION_REPO_ROOT" ]]; then printf '%s' "$SELECTION_REPO_ROOT"; else (cd "$_SEL_LIB_DIR/../.." && pwd); fi
}

# ── profiles and groups, from nix/profiles/<profile>.toml ───────────────────

selection_profiles() {
  local f
  for f in "$(_sel_repo)"/nix/profiles/*.toml; do
    [[ -f "$f" ]] || continue
    f="${f##*/}"
    printf '%s\n' "${f%.toml}"
  done
}

selection_valid_profile() {
  local profiles=() p
  _sel_split profiles "$(selection_profiles)"
  for p in "${profiles[@]+"${profiles[@]}"}"; do
    if [[ "$p" == "$1" ]]; then return 0; fi
  done
  return 1
}

# selection_group_defaults PROFILE: "group<TAB>true|false" for each [groups] line.
selection_group_defaults() {
  local file
  file="$(_sel_repo)/nix/profiles/$1.toml"
  [[ -f "$file" ]] || return 1
  awk '
    { sub(/#.*/, "") }
    /^[[:space:]]*\[[A-Za-z0-9_.-]+\][[:space:]]*$/ { gsub(/\[|\]|[[:space:]]/, ""); in_groups = ($0 == "groups"); next }
    in_groups && /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*$/ {
      gsub(/[[:space:]]/, ""); split($0, kv, "="); print kv[1] "\t" kv[2]
    }' "$file"
}

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

# selection_profile_of FILE: the profile named in a selection file, double or
# single quoted; "default" when it names none (an empty file is valid and means
# the host's committed profile).
selection_profile_of() {
  local p
  p="$(sed -nE "s/^[[:space:]]*profile[[:space:]]*=[[:space:]]*[\"']([^\"']*)[\"'].*/\\1/p" "$1" 2>/dev/null | head -n1)"
  printf '%s' "${p:-default}"
}

# ── the Home Manager profile of the installed generation ────────────────────

# selection_hm_profile: prints the Home Manager profile link, or returns 1 when
# neither profile directory exists. This mirrors the resolution at the top of
# ops/update-all.sh (HM_PROFILE_DIR); a follow-up should make update-all use
# this function so the two cannot drift.
selection_hm_profile() {
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles" alt
  if [[ ! -d "$dir" ]]; then
    alt="${NIX_STATE_DIR:-/nix/var/nix}/profiles/per-user/${USER:-$(id -un)}"
    if [[ -d "$alt" ]]; then dir="$alt"; else return 1; fi
  fi
  printf '%s\n' "$dir/home-manager"
}

# ── input ───────────────────────────────────────────────────────────────────
#
# This file never reads the terminal. The prompts below call selection_read VAR
# PROMPT, which ops/install.sh (the one script that asks) defines: prompt on
# stderr, one line from stdin into VAR, return 1 at end of input.

# ── evaluation ──────────────────────────────────────────────────────────────

# The evaluated shapes, all plain text so no jq is needed on a first install:
#   state    P<TAB>profile / G<TAB>group<TAB>true|false / K<TAB>package outPath /
#            F<TAB>home.file target<TAB>source / C<TAB>homebrew cask
#   members  H<TAB>host profile / N<TAB>group / G<TAB>group<TAB>outPath /
#            A<TAB>outPath of the personal-only packages
# Neither builds anything: outPath is computed, not realised.
# shellcheck disable=SC2016  # Nix source: ${g} and \t are for Nix, not the shell
_SEL_STATE_BODY='h: mac: casks: builtins.concatStringsSep "\n" ([ ("P\t" + h.myConfig.profile) ] ++ map (g: "G\t" + g + "\t" + (if h.myConfig.groups.${g} then "true" else "false")) (builtins.filter (g: mac || g != "macInput") (builtins.attrNames h.myConfig.groups)) ++ map (p: "K\t" + toString p) h.home.packages ++ map (f: "F\t" + f.target + "\t" + toString f.source) (builtins.filter (f: f.enable) (builtins.attrValues h.home.file)) ++ map (n: "C\t" + n) casks) + "\n"'
_SEL_STATE_HM="let body = $_SEL_STATE_BODY; in c: body c false []"
_SEL_STATE_DARWIN="let body = $_SEL_STATE_BODY; in c: let u = builtins.head (builtins.attrNames c.home-manager.users); in body c.home-manager.users.\${u} true (map (x: x.name) c.homebrew.casks)"

# The macInput group gates macOS casks only, so a Linux host does not list it:
# the state and members expressions take a `mac` flag (false for Home Manager
# hosts, true for the darwin system) and drop macInput from the group names when
# it is false. The option itself exists on every host (a selection file may set it).
#
# Members of each group: all groups on (profile work) minus that group off; the
# personal-only set: all groups on, profile personal minus work. Each evaluation
# extends the host configuration with the groups and the profile forced, so a
# local selection cannot change the answer.
# shellcheck disable=SC2016  # Nix source
_SEL_MEMBERS_BODY='mac: cfgOf: mkMod: base: let force = v: { _type = "override"; priority = 10; content = v; }; names = builtins.filter (g: mac || g != "macInput") (builtins.attrNames (cfgOf base).myConfig.groups); ext = profile: groups: base.extendModules { modules = [ (mkMod { myConfig.profile = force profile; myConfig.groups = builtins.mapAttrs (_: v: force v) groups; }) ]; }; allOn = builtins.listToAttrs (map (g: { name = g; value = true; }) names); pk = e: map toString (cfgOf e).home.packages; on = pk (ext "work" allOn); minus = a: b: builtins.filter (p: !(builtins.elem p b)) a; members = g: minus on (pk (ext "work" (allOn // { ${g} = false; }))); in builtins.concatStringsSep "\n" ([ ("H\t" + (cfgOf base).myConfig.profile) ] ++ map (g: "N\t" + g) names ++ builtins.concatMap (g: map (p: "G\t" + g + "\t" + p) (members g)) names ++ map (p: "A\t" + p) (minus (pk (ext "personal" allOn)) on)) + "\n"'
_SEL_MEMBERS_HM="let gen = $_SEL_MEMBERS_BODY; in d: gen false (e: e.config) (m: m) d"
_SEL_MEMBERS_DARWIN="let gen = $_SEL_MEMBERS_BODY; in d: let u = builtins.head (builtins.attrNames d.config.home-manager.users); in gen true (e: e.config.home-manager.users.\${u}) (m: { home-manager.users.\${u} = m; }) d"

# The cheapest evaluation that forces the whole selection: the profile option's
# condition reads the thunk with every validation throw, and deepSeq on the
# groups forces each group's value, so a wrong type (media = "no") fails here
# and not at the switch.
_SEL_CHECK_HM='m: builtins.deepSeq m.groups m.profile'
_SEL_CHECK_DARWIN='us: let m = (builtins.head (builtins.attrValues us)).myConfig; in builtins.deepSeq m.groups m.profile'

_sel_flake() { printf '%s/nix' "$(_sel_repo)"; }

# _sel_eval OUT ERR ATTR APPLY: evaluates with the selection in SELECTION_ARGS,
# like every other host evaluation (the committed default when it is empty).
_sel_eval() {
  nix eval --option allow-import-from-derivation false --raw "$(_sel_flake)#$3" ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"} --apply "$4" >"$1" 2>"$2"
}

# _sel_eval_for KIND OUT ERR ATTR APPLY: _sel_eval with another selection in
# SELECTION_ARGS for the one call. KIND committed: none (the group members must
# not depend on the local file). KIND proposed: the proposal in SELECTION_OVERRIDE.
_sel_eval_for() {
  local kind="$1" keep=() i rc=0
  shift
  for i in "${!SELECTION_ARGS[@]}"; do keep+=("${SELECTION_ARGS[$i]}"); done
  SELECTION_ARGS=()
  if [[ "$kind" == proposed ]]; then
    for i in "${!SELECTION_OVERRIDE[@]}"; do SELECTION_ARGS+=("${SELECTION_OVERRIDE[$i]}"); done
  fi
  _sel_eval "$@" || rc=$?
  SELECTION_ARGS=()
  for i in "${!keep[@]}"; do SELECTION_ARGS+=("${keep[$i]}"); done
  return "$rc"
}

_sel_attr_state() { if [[ "$SELECTION_HOST" == macos ]]; then echo darwinConfigurations.macos.config; else echo "homeConfigurations.$SELECTION_HOST.config"; fi; }
_sel_attr_members() { if [[ "$SELECTION_HOST" == macos ]]; then echo darwinConfigurations.macos; else echo "homeConfigurations.$SELECTION_HOST"; fi; }
_sel_attr_check() { if [[ "$SELECTION_HOST" == macos ]]; then echo darwinConfigurations.macos.config.home-manager.users; else echo "homeConfigurations.$SELECTION_HOST.config.myConfig"; fi; }
_sel_expr_state() { if [[ "$SELECTION_HOST" == macos ]]; then printf '%s' "$_SEL_STATE_DARWIN"; else printf '%s' "$_SEL_STATE_HM"; fi; }
_sel_expr_members() { if [[ "$SELECTION_HOST" == macos ]]; then printf '%s' "$_SEL_MEMBERS_DARWIN"; else printf '%s' "$_SEL_MEMBERS_HM"; fi; }
_sel_expr_check() { if [[ "$SELECTION_HOST" == macos ]]; then printf '%s' "$_SEL_CHECK_DARWIN"; else printf '%s' "$_SEL_CHECK_HM"; fi; }

# _sel_show_err FILE: the Nix error, to stderr. Nix prints warnings and trace
# frames first and the message that names the key last, so the end is kept.
_sel_show_err() {
  if [[ -s "$1" ]]; then grep -v '^warning:' "$1" | tail -n 25 >&2; else printf 'error: the evaluation failed without a message\n' >&2; fi
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

# ── facts: the installed generation (I), the current selection (C), members ──

SEL_I_STATE=""      # none (no generation yet) | ok | unknown
SEL_I_GEN=""        # the generation's store path
SEL_C_INVALID=0     # 1 when the local selection could not be evaluated
SEL_HAVE_FACTS=0
SEL_PRESENT_SHOWN=0
SEL_HOST_PROFILE="work"
SEL_GROUPS=()

_sel_drop_noise() {
  local n re=""
  for n in "${SELECTION_PKG_NOISE[@]}"; do re+="${re:+|}$n"; done
  awk -F '\t' -v re="^($re)" '$1 !~ re'
}

# _sel_state_packages FILE: "pname<TAB>version" of the state's packages.
_sel_state_packages() {
  awk -F '\t' '$1 == "K" { print $2 }' "$1" | nix_packages_from_paths | _sel_drop_noise
}

# _sel_state_profile FILE; _sel_state_groups FILE ("group<TAB>value")
_sel_state_profile() { awk -F '\t' '$1 == "P" { print $2; exit }' "$1"; }
_sel_state_groups() { awk -F '\t' '$1 == "G" { print $2 "\t" $3 }' "$1"; }

# _sel_overrides FILE: "media=off go=off" - the groups whose value in the state
# differs from the committed default of the state's profile.
_sel_overrides() {
  local prof
  prof="$(_sel_state_profile "$1")"
  [[ -n "$prof" ]] || return 0
  awk -F '\t' '
    NR == FNR { d[$1] = $2; next }
    ($1 in d) && $2 != d[$1] { printf "%s%s=%s", sep, $1, ($2 == "true" ? "on" : "off"); sep = " " }
  ' <(selection_group_defaults "$prof") <(_sel_state_groups "$1")
}

# The files the installed generation links into $HOME: "target<TAB>source".
_sel_installed_files() {
  local root="$1/home-files" links=() p
  [[ -d "$root" ]] || return 1
  root="$(cd "$root" && pwd -P)" || return 1
  _sel_split links "$(find "$root" -type l | LC_ALL=C sort)"
  for p in "${links[@]+"${links[@]}"}"; do
    printf '%s\t%s\n' "${p#"$root"/}" "$(readlink "$p")"
  done
}

_sel_read_installed() {
  local link gen pkgs
  SEL_I_STATE=unknown
  SEL_I_GEN=""
  : >"$SELECTION_WORK/i-files.tsv"
  : >"$SELECTION_WORK/i-pkgs.tsv"
  if ! link="$(selection_hm_profile)" || [[ ! -e "$link" && ! -L "$link" ]]; then
    SEL_I_STATE=none
    return 0
  fi
  gen="$(readlink -f "$link" 2>/dev/null)" || return 0
  [[ -n "$gen" ]] || return 0
  pkgs="$(nix_toplevel_packages "$gen" 2>/dev/null | _sel_drop_noise)" || return 0
  printf '%s' "$pkgs" >"$SELECTION_WORK/i-pkgs.tsv"
  [[ -z "$pkgs" ]] || printf '\n' >>"$SELECTION_WORK/i-pkgs.tsv"
  _sel_installed_files "$gen" >"$SELECTION_WORK/i-files.tsv" || return 0
  SEL_I_GEN="$gen"
  SEL_I_STATE=ok
}

# selection_facts [lenient]
#
# Evaluates, into files under SELECTION_WORK and before anything is printed:
# the group members (committed default, whatever the local file says), the
# current selection C (SELECTION_ARGS), and reads the installed generation I.
# Returns 0; 1 when an evaluation failed (the Nix error is on stderr); 2 when no
# preview is possible (nix or the report helper is missing; the reason is on
# stdout). With "lenient" an invalid local selection is reported and C falls
# back to the committed default (--profile and --reconfigure repair a file).
selection_facts() {
  local lenient="${1:-}" repo
  repo="$(_sel_repo)"
  SEL_HAVE_FACTS=0
  if ! command -v nix >/dev/null 2>&1; then
    printf 'preview unavailable: nix not installed\n'
    return 2
  fi
  if [[ ! -f "$repo/ops/update-version-report.sh" ]]; then
    printf 'preview unavailable: ops/update-version-report.sh is missing\n'
    return 2
  fi
  # shellcheck source=ops/update-version-report.sh
  source "$repo/ops/update-version-report.sh"
  selection_args
  printf '[install] evaluating the install state (read-only, nothing is built)...\n' >&2
  _sel_eval_for committed "$SELECTION_WORK/m.tsv" "$SELECTION_WORK/m.err" "$(_sel_attr_members)" "$(_sel_expr_members)" \
    || { _sel_show_err "$SELECTION_WORK/m.err"; return 1; }
  SEL_C_INVALID=0
  if ! _sel_eval "$SELECTION_WORK/c.tsv" "$SELECTION_WORK/c.err" "$(_sel_attr_state)" "$(_sel_expr_state)"; then
    if [[ "$lenient" == lenient && ${#SELECTION_ARGS[@]} -gt 0 ]]; then
      printf 'The current selection is invalid; comparing with the committed default instead:\n' >&2
      _sel_show_err "$SELECTION_WORK/c.err"
      SEL_C_INVALID=1
      _sel_eval_for committed "$SELECTION_WORK/c.tsv" "$SELECTION_WORK/c.err" "$(_sel_attr_state)" "$(_sel_expr_state)" \
        || { _sel_show_err "$SELECTION_WORK/c.err"; return 1; }
    else
      _sel_show_err "$SELECTION_WORK/c.err"
      return 1
    fi
  fi
  SEL_HOST_PROFILE="$(awk -F '\t' '$1 == "H" { print $2; exit }' "$SELECTION_WORK/m.tsv")"
  SEL_HOST_PROFILE="${SEL_HOST_PROFILE:-work}"
  SEL_GROUPS=()
  _sel_split SEL_GROUPS "$(awk -F '\t' '$1 == "N" { print $2 }' "$SELECTION_WORK/m.tsv")"
  _sel_state_packages "$SELECTION_WORK/c.tsv" >"$SELECTION_WORK/c-pkgs.tsv"
  _sel_read_installed
  SEL_HAVE_FACTS=1
}

# _sel_members_of GROUP|@personal: package names, one per line.
_sel_members_of() {
  if [[ "$1" == @personal ]]; then
    awk -F '\t' '$1 == "A" { print $2 }' "$SELECTION_WORK/m.tsv"
  else
    awk -F '\t' -v g="$1" '$1 == "G" && $2 == g { print $3 }' "$SELECTION_WORK/m.tsv"
  fi | nix_packages_from_paths | _sel_drop_noise | cut -f1 | LC_ALL=C sort -u
}

_sel_in_file() { grep -Fxq -- "$1" "$2"; }

_sel_join() { local IFS=' '; printf '%s' "$*"; }

# _sel_pnames FILE: the package names of a "pname<TAB>version" file.
_sel_pnames() { cut -f1 "$1" | LC_ALL=C sort -u; }

# selection_present_state: installed n/m per group, against the installed
# generation. Only a first install (no generation) uses `command -v`, and then
# only as an annotation, never as a count.
selection_present_state() {
  local label g n m inst names found path members=() sets=()
  ((SEL_HAVE_FACTS)) || return 0
  SEL_PRESENT_SHOWN=1
  _sel_pnames "$SELECTION_WORK/i-pkgs.tsv" >"$SELECTION_WORK/i-names.txt"
  printf 'Present state (installed packages by group)\n'
  sets=()
  for g in "${SEL_GROUPS[@]+"${SEL_GROUPS[@]}"}"; do sets+=("$g"); done
  sets+=("@personal")
  for g in "${sets[@]+"${sets[@]}"}"; do
    label="$g"
    if [[ "$g" == @personal ]]; then label="personal apps"; fi
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
    if ((${#names[@]})); then
      printf '  %-14s installed %s/%s %s\n' "$label" "$inst" "$m" "$(_sel_join "${names[@]}")"
    else
      printf '  %-14s installed %s/%s\n' "$label" "$inst" "$m"
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

_sel_unit_note() {
  case "$1" in
    *systemd/user/*.service | *systemd/user/*.timer) printf ' (user unit)' ;;
  esac
}

# _sel_files_delta MODE A B: "added|removed|changed<TAB>target", sorted. Files
# are "target<TAB>source". MODE exact compares two evaluated sets. MODE tree
# compares a listing of symlinks (A, the installed generation) with an evaluated
# set (B): a target that is a directory in B counts as present when A holds
# entries below it, because Home Manager links such directories file by file.
_sel_files_delta() {
  awk -F '\t' -v mode="$1" -v fa="$2" '
    FILENAME == fa { A[$1] = $2; next }
    { B[$1] = $2 }
    END {
      for (t in B) {
        if (t in A) { if (A[t] != B[t]) print "changed\t" t; continue }
        if (mode == "tree") { hit = 0; for (a in A) if (index(a, t "/") == 1) { hit = 1; break }; if (hit) continue }
        print "added\t" t
      }
      for (t in A) {
        if (t in B) continue
        if (mode == "tree") { hit = 0; for (b in B) if (index(t, b "/") == 1) { hit = 1; break }; if (hit) continue }
        print "removed\t" t
      }
    }' "$2" "$3" | LC_ALL=C sort -t $'\t' -k2,2 -k1,1
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

_sel_state_files() { awk -F '\t' '$1 == "F" { print $2 "\t" $3 }' "$1" | LC_ALL=C sort -u; }

_sel_chezmoi_section() {
  local repo out err first line col n=0 added=0 modified=0 removed=0 scripts=0 total=0 label lines=()
  repo="$(_sel_repo)"
  label="chezmoi files: pending repo changes"
  if [[ "$SELECTION_HOST" != macos ]]; then label+=" (the selection does not change chezmoi on Linux)"; fi
  printf '%s\n' "$label"
  out="$SELECTION_WORK/chezmoi.out"
  err="$SELECTION_WORK/chezmoi.err"
  if ! command -v chezmoi >/dev/null 2>&1; then
    printf '    unavailable (chezmoi not installed); after install: chezmoi diff\n'
    return 0
  fi
  if ! chezmoi --source="$repo" status --no-tty </dev/null >"$out" 2>"$err"; then
    first="$(head -n1 "$err")"
    printf '    unavailable (%s); after install: chezmoi diff\n' "${first:-chezmoi status failed}"
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
  printf '    full diff: chezmoi --source=%s diff\n' "$repo"
}

_sel_casks_section() {
  local installed="$SELECTION_WORK/casks-installed.txt" c unmanaged=0 have_c have_p casks=()
  printf 'macOS casks\n'
  if ! command -v brew >/dev/null 2>&1 || ! brew list --cask -1 2>/dev/null | LC_ALL=C sort -u >"$installed"; then
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
  local g label n keep off parts sets=() adds rems names=()
  printf 'Outcome by group (installed -> proposed)\n'
  if [[ "$SEL_I_STATE" == unknown ]]; then
    printf '    unknown: the installed generation could not be read, so keep, add and remove cannot be told\n'
    return 0
  fi
  _sel_pnames "$SELECTION_WORK/i-pkgs.tsv" >"$SELECTION_WORK/i-names.txt"
  _sel_pnames "$SELECTION_WORK/p-pkgs.tsv" >"$SELECTION_WORK/p-names.txt"
  sets=()
  for g in "${SEL_GROUPS[@]+"${SEL_GROUPS[@]}"}"; do sets+=("$g"); done
  sets+=("@personal")
  for g in "${sets[@]+"${sets[@]}"}"; do
    label="$g"
    if [[ "$g" == @personal ]]; then label="personal apps"; fi
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
    parts=""
    if ((keep)); then parts+="keep $keep"; fi
    if ((${#adds[@]})); then parts+="${parts:+; }add ${#adds[@]}: $(_sel_join "${adds[@]}")"; fi
    if ((${#rems[@]})); then parts+="${parts:+; }remove ${#rems[@]}: $(_sel_join "${rems[@]}")"; fi
    if ((off)); then parts+="${parts:+; }stays off $off"; fi
    printf '  %-14s %s\n' "$label" "${parts:-no members}"
  done
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
  local cur_prof new_prof cur_over new_over npk sel_file
  SEL_WITH_PROPOSAL=0
  [[ "${1:-}" == proposal ]] && SEL_WITH_PROPOSAL=1
  ((SEL_HAVE_FACTS)) || return 1
  sel_file="$(selection_dir)/selection.toml"
  cur_prof="$(_sel_state_profile "$SELECTION_WORK/c.tsv")"
  cur_over="$(_sel_overrides "$SELECTION_WORK/c.tsv")"
  npk="$(grep -c . "$SELECTION_WORK/i-pkgs.tsv" || true)"
  printf '\n'
  case "$SEL_I_STATE" in
    ok) printf 'Installed generation: %s (%s packages); ' "$SEL_I_GEN" "$npk" ;;
    none) printf 'No Home Manager generation yet (first install); ' ;;
    *) printf 'Installed generation: unknown (it could not be read); ' ;;
  esac
  if [[ -f "$sel_file" && "$SEL_C_INVALID" == 0 ]]; then
    printf 'current selection: %s (profile %s%s)\n' "$sel_file" "$cur_prof" "${cur_over:+, overrides: $cur_over}"
  elif [[ "$SEL_C_INVALID" == 1 ]]; then
    printf 'current selection: %s is invalid, using the committed default (profile %s)\n' "$sel_file" "$cur_prof"
  else
    printf 'current selection: none (committed default, profile %s)\n' "$cur_prof"
  fi
  printf '\n'
  if ((SEL_PRESENT_SHOWN == 0)); then selection_present_state; printf '\n'; fi
  if ((SEL_WITH_PROPOSAL)); then
    new_prof="$(_sel_state_profile "$SELECTION_WORK/p.tsv")"
    new_over="$(_sel_overrides "$SELECTION_WORK/p.tsv")"
    printf 'Preview (nothing applied): profile %s -> %s; overrides: %s\n' "$cur_prof" "$new_prof" "${new_over:-none}"
    if ((SEL_REPLACE)) && [[ -n "$cur_over" ]]; then
      printf '  This replaces your existing group overrides (%s); they are dropped.\n' "$cur_over"
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
  fi
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
