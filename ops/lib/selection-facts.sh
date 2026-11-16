#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # the SEL_* results are used by the files that source this one
# The facts of the install selection (T-0042, T-0043): the profile and group
# lookups, the evaluation of the current state and of the group members, the
# installed generation, and the helpers that compare them. Split from
# ops/lib/selection-preview.sh (the prompts, the preview and the write, which
# only ops/install.sh uses) so the read-only selection diff of
# ops/update-all.sh can use the same facts without loading any prompt code.
#
# Sourced by ops/install.sh, ops/update-all.sh (--selection-diff only),
# ops/lib/selection-preview.sh and ops/lib/selection-diff.sh, after
# ops/lib/selection.sh (it uses selection_args, selection_override_args and
# selection_dir from there). A grep rule in tests/bash/install-selection.bats
# keeps every other script from sourcing it or calling its functions. It
# defines functions and variables only and never reads the terminal.
#
# Context. The caller sets SELECTION_REPO_ROOT, SELECTION_HOST (HOST_PROFILE)
# and SELECTION_WORK, a private temp dir it removes on exit. Evaluation only:
# `nix eval` with import-from-derivation off, `nix-store -q --references` on the
# installed generation, `chezmoi status` and `brew list`. It builds nothing, so
# it leaves no ./result link. SEL_EVAL_EXTRA holds extra `nix eval` flags that
# only the selection diff sets (--no-write-lock-file); SEL_FACTS_TAG is the tag
# of the progress line on stderr.

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
# shellcheck source=ops/lib/chezmoi-source.sh
source "$_SEL_LIB_DIR/chezmoi-source.sh"
# shellcheck source=ops/lib/wait-feedback.sh
source "$_SEL_LIB_DIR/wait-feedback.sh"

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

# _sel_groups_of_file FILE: "group<TAB>true|false" for each [groups] line of a
# TOML file (a profile under nix/profiles or a local selection.toml).
_sel_groups_of_file() {
  awk '
    { sub(/#.*/, "") }
    /^[[:space:]]*\[[A-Za-z0-9_.-]+\][[:space:]]*$/ { gsub(/\[|\]|[[:space:]]/, ""); in_groups = ($0 == "groups"); next }
    in_groups && /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*$/ {
      gsub(/[[:space:]]/, ""); split($0, kv, "="); print kv[1] "\t" kv[2]
    }' "$1"
}

# selection_group_defaults PROFILE: "group<TAB>true|false" for each [groups] line.
selection_group_defaults() {
  local file
  file="$(_sel_repo)/nix/profiles/$1.toml"
  [[ -f "$file" ]] || return 1
  _sel_groups_of_file "$file"
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

# ── evaluation ──────────────────────────────────────────────────────────────

# The evaluated shapes, all plain text so no jq is needed on a first install:
#   state    P<TAB>profile / G<TAB>group<TAB>true|false / K<TAB>package outPath /
#            F<TAB>home.file target<TAB>source / C<TAB>homebrew cask
#   members  H<TAB>host profile / N<TAB>group / G<TAB>group<TAB>outPath /
#            A<TAB>outPath of the personal-only packages /
#            X<TAB>group<TAB>cask a group gates (macOS only: casks with the
#            group on minus casks with it off)
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
_SEL_MEMBERS_BODY='mac: ck: cfgOf: mkMod: base: let force = v: { _type = "override"; priority = 10; content = v; }; names = builtins.filter (g: mac || g != "macInput") (builtins.attrNames (cfgOf base).myConfig.groups); ext = profile: groups: base.extendModules { modules = [ (mkMod { myConfig.profile = force profile; myConfig.groups = builtins.mapAttrs (_: v: force v) groups; }) ]; }; allOn = builtins.listToAttrs (map (g: { name = g; value = true; }) names); pk = e: map toString (cfgOf e).home.packages; on = pk (ext "work" allOn); minus = a: b: builtins.filter (p: !(builtins.elem p b)) a; members = g: minus on (pk (ext "work" (allOn // { ${g} = false; }))); in builtins.concatStringsSep "\n" ([ ("H\t" + (cfgOf base).myConfig.profile) ] ++ map (g: "N\t" + g) names ++ builtins.concatMap (g: map (p: "G\t" + g + "\t" + p) (members g)) names ++ map (p: "A\t" + p) (minus (pk (ext "personal" allOn)) on) ++ builtins.concatMap (g: map (c: "X\t" + g + "\t" + c) (minus (ck (ext "work" allOn)) (ck (ext "work" (allOn // { ${g} = false; }))))) names) + "\n"'
_SEL_MEMBERS_HM="let gen = $_SEL_MEMBERS_BODY; in d: gen false (_: [ ]) (e: e.config) (m: m) d"
_SEL_MEMBERS_DARWIN="let gen = $_SEL_MEMBERS_BODY; in d: let u = builtins.head (builtins.attrNames d.config.home-manager.users); in gen true (e: map (x: x.name) e.config.homebrew.casks) (e: e.config.home-manager.users.\${u}) (m: { home-manager.users.\${u} = m; }) d"

# The cheapest evaluation that forces the whole selection: the profile option's
# condition reads the thunk with every validation throw, and deepSeq on the
# groups forces each group's value, so a wrong type (media = "no") fails here
# and not at the switch.
_SEL_CHECK_HM='m: builtins.deepSeq m.groups m.profile'
_SEL_CHECK_DARWIN='us: let m = (builtins.head (builtins.attrValues us)).myConfig; in builtins.deepSeq m.groups m.profile'

# Extra `nix eval` flags and the tag of the progress line. Only the selection
# diff sets the first (--no-write-lock-file, so a stale lock is never written);
# install keeps its flags.
SEL_EVAL_EXTRA=()
SEL_FACTS_TAG="install"

_sel_flake() { printf '%s/nix' "$(_sel_repo)"; }

# _sel_eval OUT ERR ATTR APPLY: evaluates with the selection in SELECTION_ARGS,
# like every other host evaluation (the committed default when it is empty).
_sel_eval() {
  nix eval --option allow-import-from-derivation false --raw "$(_sel_flake)#$3" ${SELECTION_ARGS[@]+"${SELECTION_ARGS[@]}"} ${SEL_EVAL_EXTRA[@]+"${SEL_EVAL_EXTRA[@]}"} --apply "$4" >"$1" 2>"$2"
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

# The Home Manager flake output for SELECTION_HOST (wsl on NixOS is wsl-nixos):
# hm_attr in ops/lib/hm-switch.sh is the one implementation. It prints nothing
# and fails for wsl when the NixOS probe cannot answer, so the evaluation that
# uses this attribute fails instead of looking at the wrong output.
_sel_hm_attr() {
  # shellcheck source=ops/lib/hm-switch.sh
  declare -F hm_attr >/dev/null 2>&1 || source "$_SEL_LIB_DIR/hm-switch.sh"
  hm_attr "$SELECTION_HOST"
}
_sel_attr_state() { if [[ "$SELECTION_HOST" == macos ]]; then echo darwinConfigurations.macos.config; else echo "homeConfigurations.$(_sel_hm_attr).config"; fi; }
_sel_attr_members() { if [[ "$SELECTION_HOST" == macos ]]; then echo darwinConfigurations.macos; else echo "homeConfigurations.$(_sel_hm_attr)"; fi; }
_sel_attr_check() { if [[ "$SELECTION_HOST" == macos ]]; then echo darwinConfigurations.macos.config.home-manager.users; else echo "homeConfigurations.$(_sel_hm_attr).config.myConfig"; fi; }
_sel_expr_state() { if [[ "$SELECTION_HOST" == macos ]]; then printf '%s' "$_SEL_STATE_DARWIN"; else printf '%s' "$_SEL_STATE_HM"; fi; }
_sel_expr_members() { if [[ "$SELECTION_HOST" == macos ]]; then printf '%s' "$_SEL_MEMBERS_DARWIN"; else printf '%s' "$_SEL_MEMBERS_HM"; fi; }
_sel_expr_check() { if [[ "$SELECTION_HOST" == macos ]]; then printf '%s' "$_SEL_CHECK_DARWIN"; else printf '%s' "$_SEL_CHECK_HM"; fi; }

# _sel_show_err FILE: the Nix error, to stderr. Nix prints warnings and trace
# frames first and the message that names the key last, so the end is kept.
_sel_show_err() {
  if [[ -s "$1" ]]; then grep -v '^warning:' "$1" | tail -n 25 >&2; else printf 'error: the evaluation failed without a message\n' >&2; fi
}

# ── facts: the installed generation (I), the current selection (C), members ──

SEL_I_STATE=""      # none (no generation yet) | ok | unknown
SEL_I_GEN=""        # the generation's store path
SEL_C_INVALID=0     # 1 when the local selection could not be evaluated
SEL_HAVE_FACTS=0
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

# _sel_eval_facts: the evaluations of selection_facts (the slow part), run under
# wait_run so the wait is announced and has a heartbeat. Needs $lenient from the caller.
_sel_eval_facts() {
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
  wait_run "$SEL_FACTS_TAG: evaluating the install state (read-only, nothing is built)" \
    "10-120 seconds (the first evaluation of a fresh checkout is the slow one)" _sel_eval_facts || return 1
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

# _sel_cask_members_of GROUP: the casks the group gates (macOS), one per line.
_sel_cask_members_of() {
  awk -F '\t' -v g="$1" '$1 == "X" && $2 == g { print $3 }' "$SELECTION_WORK/m.tsv" | LC_ALL=C sort -u
}

# _sel_brew_casks: loads the installed casks into casks-installed.txt once and
# sets SEL_BREW to ok, or to unknown when brew is missing or fails.
SEL_BREW=""
_sel_brew_casks() {
  if [[ -n "$SEL_BREW" ]]; then return 0; fi
  if command -v brew >/dev/null 2>&1 && brew list --cask -1 2>/dev/null | LC_ALL=C sort -u >"$SELECTION_WORK/casks-installed.txt"; then
    SEL_BREW=ok
  else
    SEL_BREW=unknown
  fi
}

# _sel_sets: fills SEL_SETS with the groups, then @personal, the order the
# present-state table and the outcome list use. _sel_set_label SET: the name
# printed for it ("personal apps" for @personal).
SEL_SETS=()
_sel_sets() {
  local g
  SEL_SETS=()
  for g in "${SEL_GROUPS[@]+"${SEL_GROUPS[@]}"}"; do SEL_SETS+=("$g"); done
  SEL_SETS+=("@personal")
}
_sel_set_label() {
  if [[ "$1" == @personal ]]; then printf 'personal apps'; else printf '%s' "$1"; fi
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

_sel_state_files() { awk -F '\t' '$1 == "F" { print $2 "\t" $3 }' "$1" | LC_ALL=C sort -u; }

# _sel_chezmoi_status: `chezmoi status` of the repo into SELECTION_WORK/chezmoi.out
# (stderr into chezmoi.err). Sets SEL_CHEZMOI to ok, or to unavailable with the
# reason in SEL_CHEZMOI_WHY (chezmoi missing, or the first line of its error).
# Read-only: status never writes chezmoi's state (T-0043 spike).
SEL_CHEZMOI=""
SEL_CHEZMOI_WHY=""
SEL_CHEZMOI_SOURCE_ARG=""
# _sel_chezmoi_is_configured_source: true when the repo being diffed is the
# source directory chezmoi itself is configured with (`chezmoi source-path`,
# compared by resolved path against <repo>/<.chezmoiroot>). Templates render
# .chezmoi.sourceDir, so only the configured spelling matches what apply wrote.
_sel_chezmoi_is_configured_source() {
  chezmoi_source_set "$(_sel_repo)"
  [[ "${#CHEZMOI_SOURCE_ARGS[@]}" -eq 0 ]]
}
_sel_chezmoi_status() {
  local err="$SELECTION_WORK/chezmoi.err" first
  local -a src=()
  SEL_CHEZMOI=ok
  SEL_CHEZMOI_WHY=""
  SEL_CHEZMOI_SOURCE_ARG="--source=$(_sel_repo)"
  if ! command -v chezmoi >/dev/null 2>&1; then
    SEL_CHEZMOI=unavailable
    SEL_CHEZMOI_WHY="chezmoi not installed"
    return 0
  fi
  # The configured checkout is diffed the way `chezmoi apply` sees it (no
  # --source); any other tree (a worktree, a test repo) is diffed by path.
  if _sel_chezmoi_is_configured_source; then SEL_CHEZMOI_SOURCE_ARG=""; else src=("$SEL_CHEZMOI_SOURCE_ARG"); fi
  if ! chezmoi ${src[@]+"${src[@]}"} status --no-tty </dev/null >"$SELECTION_WORK/chezmoi.out" 2>"$err"; then
    first="$(head -n1 "$err")"
    SEL_CHEZMOI=unavailable
    SEL_CHEZMOI_WHY="${first:-chezmoi status failed}"
  fi
  return 0
}
