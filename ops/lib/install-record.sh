#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034  # the IR_* results are used by the files that source this one
# The applied-state record (T-0043): what was last applied to this machine, so
# `sys-update --selection-diff` can say why something is pending (the selection
# changed, the repo changed, or the generation moved outside sys-update).
#
# Sourced by ops/update-all.sh and ops/install.sh, after ops/lib/selection.sh
# (it uses selection_dir). Functions only; it never reads input and runs under
# /bin/bash 3.2 on a fresh Mac (no bash 4 builtins, no associative arrays).
#
#   install_record_write WRITER HOST KIND GEN REPO_ROOT   after a successful apply
#   install_record_read [CURRENT_GENERATION]              prints ok|absent|invalid|stale
#
# Path: ${APP_CONFIGS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/app-configs}/installed.meta
# Machine-local state, never committed. Exact key=value lines, LF endings, this
# fixed order, each key once, no others:
#   schema_version=1
#   written_by=sys-update|install
#   written_at=<UTC, YYYY-MM-DDTHH:MM:SSZ>
#   run_id=<id>|none            (INSTALL_RECORD_RUN_ID, set by sys-update)
#   host=<host profile>
#   generation_kind=home-manager|darwin-system
#   generation=<readlink -f of the profile after the switch>
#   repo_rev=<40 hex>|unknown
#   repo_dirty=yes|no|unknown   (git status --porcelain -- nix home)
#   selection_file=present|absent
#   selection_sha256=<64 hex>|none   (the hash of the file bytes, never the content)
#
# The write is atomic (umask 077, mktemp in the target directory, mv -f) and
# only ever runs after a successful apply (and verify, in sys-update). A failed
# write warns and returns 1; the caller never fails the apply for it.
# Reading it is pure: it writes nothing.
#
# The reader's result is also left in IR_* (IR_WRITTEN_BY, IR_WRITTEN_AT,
# IR_RUN_ID, IR_HOST, IR_GENERATION_KIND, IR_GENERATION, IR_REPO_REV,
# IR_REPO_DIRTY, IR_SELECTION_FILE, IR_SELECTION_SHA256) when it is ok or stale.

IR_SCHEMA_VERSION=""
IR_WRITTEN_BY=""
IR_WRITTEN_AT=""
IR_RUN_ID=""
IR_HOST=""
IR_GENERATION_KIND=""
IR_GENERATION=""
IR_REPO_REV=""
IR_REPO_DIRTY=""
IR_SELECTION_FILE=""
IR_SELECTION_SHA256=""

install_record_path() {
  printf '%s/installed.meta' "${APP_CONFIGS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/app-configs}"
}

# install_record_sha256 FILE: the sha256 of the file bytes. FILE goes in on
# stdin: given as an argument, sha256sum prefixes a backslash to the hash when
# the name holds one.
install_record_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum <"$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 <"$1" | cut -d' ' -f1
  else return 1; fi
}

# install_record_repo_facts REPO_ROOT: prints "<rev> <dirty>" (unknown when git
# cannot say). --no-optional-locks keeps git from refreshing the index.
install_record_repo_facts() {
  local rev dirty=unknown porcelain
  rev="$(git --no-optional-locks -C "$1" rev-parse HEAD 2>/dev/null)" || rev=unknown
  case "$rev" in
    *[!0-9a-f]* | "") rev=unknown ;;
  esac
  if [[ "${#rev}" -ne 40 ]]; then rev=unknown; fi
  if porcelain="$(git --no-optional-locks -C "$1" status --porcelain -- nix home 2>/dev/null)"; then
    if [[ -n "$porcelain" ]]; then dirty=yes; else dirty=no; fi
  fi
  printf '%s %s' "$rev" "$dirty"
}

# install_record_write WRITER HOST KIND GEN REPO_ROOT
# GEN is the profile link (or system link); its readlink -f goes into the record.
install_record_write() {
  local writer="$1" host="$2" kind="$3" gen="$4" root="$5" gen_real run_id facts rev dirty sel sel_state sel_sha dir target tmp
  case "$writer" in sys-update | install) ;; *) printf 'applied-state record: unknown writer %s\n' "'$writer'" >&2; return 1 ;; esac
  case "$kind" in home-manager | darwin-system) ;; *) printf 'applied-state record: unknown generation kind %s\n' "'$kind'" >&2; return 1 ;; esac
  case "$host" in "" | *[!A-Za-z0-9._-]*) printf 'applied-state record: bad host %s\n' "'$host'" >&2; return 1 ;; esac
  gen_real="$(readlink -f -- "$gen" 2>/dev/null)" || gen_real=""
  if [[ -z "$gen_real" || "$gen_real" != /* || ! -e "$gen_real" ]]; then
    printf 'applied-state record: cannot resolve the generation %s; not written\n' "'$gen'" >&2
    return 1
  fi
  run_id="${INSTALL_RECORD_RUN_ID:-none}"
  case "$run_id" in "" | *[!A-Za-z0-9._:-]*) run_id=none ;; esac
  facts="$(install_record_repo_facts "$root")"
  rev="${facts%% *}"
  dirty="${facts#* }"
  sel="$(selection_dir)/selection.toml"
  sel_state=absent
  sel_sha=none
  if [[ -f "$sel" ]]; then
    sel_state=present
    sel_sha="$(install_record_sha256 "$sel")" || sel_sha=""
    if [[ -z "$sel_sha" ]]; then
      printf 'applied-state record: cannot hash the selection file; not written\n' >&2
      return 1
    fi
  fi
  target="$(install_record_path)"
  dir="${target%/*}"
  (umask 077; mkdir -p "$dir") 2>/dev/null || { printf 'applied-state record: cannot create %s; not written\n' "$dir" >&2; return 1; }
  tmp="$(umask 077; mktemp "$dir/.installed.meta.XXXXXX" 2>/dev/null)" || { printf 'applied-state record: cannot write in %s; not written\n' "$dir" >&2; return 1; }
  {
    printf 'schema_version=1\n'
    printf 'written_by=%s\n' "$writer"
    printf 'written_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'run_id=%s\n' "$run_id"
    printf 'host=%s\n' "$host"
    printf 'generation_kind=%s\n' "$kind"
    printf 'generation=%s\n' "$gen_real"
    printf 'repo_rev=%s\n' "$rev"
    printf 'repo_dirty=%s\n' "$dirty"
    printf 'selection_file=%s\n' "$sel_state"
    printf 'selection_sha256=%s\n' "$sel_sha"
  } >"$tmp" 2>/dev/null || { rm -f "$tmp"; printf 'applied-state record: cannot write %s; not written\n' "$tmp" >&2; return 1; }
  mv -f "$tmp" "$target" 2>/dev/null || { rm -f "$tmp"; printf 'applied-state record: cannot replace %s; not written\n' "$target" >&2; return 1; }
}

# _ir_valid FILE: prints ok or invalid. The whole file must be the eleven keys
# above in that order, with a valid value each; awk only (the patterns avoid
# {n} intervals, which older awks lack).
_ir_valid() {
  awk '
    BEGIN {
      split("schema_version written_by written_at run_id host generation_kind generation repo_rev repo_dirty selection_file selection_sha256", K, " ")
      n = 11; bad = 0
    }
    {
      if (NR > n) { bad = 1; next }
      if ($0 ~ /\r/) { bad = 1; next }
      i = index($0, "=")
      if (i == 0) { bad = 1; next }
      key = substr($0, 1, i - 1); val = substr($0, i + 1)
      if (key != K[NR]) { bad = 1; next }
      V[key] = val
      if (key == "schema_version" && val != "1") bad = 1
      else if (key == "written_by" && val != "sys-update" && val != "install") bad = 1
      else if (key == "written_at" && val !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) bad = 1
      else if (key == "run_id" && (val == "" || val ~ /[^A-Za-z0-9._:-]/)) bad = 1
      else if (key == "host" && (val == "" || val ~ /[^A-Za-z0-9._-]/)) bad = 1
      else if (key == "generation_kind" && val != "home-manager" && val != "darwin-system") bad = 1
      else if (key == "generation" && (val !~ /^\// || val ~ /[[:cntrl:]]/)) bad = 1
      else if (key == "repo_rev" && val != "unknown" && (length(val) != 40 || val ~ /[^0-9a-f]/)) bad = 1
      else if (key == "repo_dirty" && val != "yes" && val != "no" && val != "unknown") bad = 1
      else if (key == "selection_file" && val != "present" && val != "absent") bad = 1
      else if (key == "selection_sha256" && val != "none" && (length(val) != 64 || val ~ /[^0-9a-f]/)) bad = 1
    }
    END {
      if (NR != n) bad = 1
      if (!bad) {
        if (V["selection_file"] == "present" && V["selection_sha256"] == "none") bad = 1
        if (V["selection_file"] == "absent" && V["selection_sha256"] != "none") bad = 1
      }
      print bad ? "invalid" : "ok"
    }' "$1"
}

_ir_field() { sed -n "s/^$2=//p" "$1" | tail -n 1; }

# install_record_read [CURRENT_GENERATION]: prints the state of the record and
# leaves it in IR_STATE (a caller that needs IR_* must not run it in $(...)).
#   absent   no file
#   invalid  not a regular file, or any key unknown, duplicated or missing, out
#            of order, schema_version other than 1, or a bad value
#   stale    valid, but its generation is not CURRENT_GENERATION (the profile
#            moved since, or no current generation was given)
#   ok       valid and for the current generation
IR_STATE=""
install_record_read() {
  local current="${1:-}" file
  file="$(install_record_path)"
  IR_SCHEMA_VERSION=""; IR_WRITTEN_BY=""; IR_WRITTEN_AT=""; IR_RUN_ID=""; IR_HOST=""
  IR_GENERATION_KIND=""; IR_GENERATION=""; IR_REPO_REV=""; IR_REPO_DIRTY=""
  IR_SELECTION_FILE=""; IR_SELECTION_SHA256=""
  if [[ ! -e "$file" && ! -L "$file" ]]; then IR_STATE=absent; printf 'absent\n'; return 0; fi
  if [[ ! -f "$file" || "$(_ir_valid "$file" 2>/dev/null)" != ok ]]; then IR_STATE=invalid; printf 'invalid\n'; return 0; fi
  IR_SCHEMA_VERSION="$(_ir_field "$file" schema_version)"
  IR_WRITTEN_BY="$(_ir_field "$file" written_by)"
  IR_WRITTEN_AT="$(_ir_field "$file" written_at)"
  IR_RUN_ID="$(_ir_field "$file" run_id)"
  IR_HOST="$(_ir_field "$file" host)"
  IR_GENERATION_KIND="$(_ir_field "$file" generation_kind)"
  IR_GENERATION="$(_ir_field "$file" generation)"
  IR_REPO_REV="$(_ir_field "$file" repo_rev)"
  IR_REPO_DIRTY="$(_ir_field "$file" repo_dirty)"
  IR_SELECTION_FILE="$(_ir_field "$file" selection_file)"
  IR_SELECTION_SHA256="$(_ir_field "$file" selection_sha256)"
  if [[ -n "$current" && "$IR_GENERATION" == "$current" ]]; then IR_STATE=ok; else IR_STATE=stale; fi
  printf '%s\n' "$IR_STATE"
  return 0
}
