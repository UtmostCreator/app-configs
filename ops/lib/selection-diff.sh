#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2153  # SELECTION_*, SEL_* and IR_* belong to the libraries it uses
# sys-update --selection-diff (T-0043): the read-only comparison of the declared
# state (the committed profile with the local selection applied) with what is
# installed, and what the next `sys-update --apply` would therefore add, remove
# or change. Classifier, outcome and the two renderers (text and JSON).
#
# Sourced by ops/update-all.sh only, after ops/lib/selection-facts.sh (the
# evaluation, the installed generation and the comparison helpers),
# ops/lib/update-facts.sh (package_delta) and ops/lib/install-record.sh. It defines functions only and never
# reads the terminal. A grep rule in tests/bash/install-selection.bats keeps
# every other script from sourcing it.
#
# Read-only, strictly: it builds nothing (`nix eval` only, with
# --no-write-lock-file), writes nothing outside a private temp directory that
# its own EXIT trap removes, runs `chezmoi status` and `brew list --cask`, reads
# the last-run record with sed, and never takes, waits for or probes the
# sys-update lock. It never recovers an interrupted run.
#
# Three sources, each with a per-check state (in_sync, pending, unknown, error):
#   Selected  the local selection.toml (present or absent), effective profile and
#             groups with where each value comes from (local or profile)
#   Declared  selection_facts in strict mode: an evaluation failure is exit 1
#   Installed the Home Manager generation (ok, none, unknown), chezmoi status,
#             on macOS `brew list --cask -1`
# plus the run state (last-run and its record) and the applied-state record
# (ops/lib/install-record.sh; absent, invalid or stale means the causes are
# unknown, never "no").
#
# Exit codes (precedence 1 > 11 > 10 > 0):
#   0   in sync
#   1   execution failure: nix missing, the declared state does not evaluate,
#       an internal error (the reason is on stderr; stdout stays empty, or with
#       --json holds a minimal envelope with outcome "failed" and an error)
#   10  changes pending: any add, remove or change
#   11  action required: any conflict, an incomplete assessment (a check that is
#       unknown or error), an unfinished or failed last run
# Homebrew casks that a deselected group leaves installed (cleanup = none) are
# listed as manual but do not count towards the exit code. Exit 2 (invalid
# arguments) is decided by update-all.sh before this file is loaded.

SD_LIST_MAX=30
# Names of the classes, in the order the text output prints their sections.
SD_CLASSES=(remove conflict add change manual unsupported unknown error)

# Result variables of selection_diff_collect.
SD_SEL_FILE=""
SD_SEL_STATE=""        # present | absent
SD_SEL_SHA=""
SD_PROFILE=""
SD_PROFILE_SRC=""      # local | host-default
SD_KEEP=0
SD_COMPLETE=yes        # yes only when every requested check completed
# Per-check state (the components of the diff). SD_ST_<c> is in_sync, pending,
# unknown (missing information prevents the comparison) or error (the comparison
# failed unexpectedly); not_applicable for casks off macOS. SD_RS_<c> is the
# structured reason, SD_DT_<c> a fixed-vocabulary detail, SD_RQ_<c> what is
# missing. Unknown is never pending, in sync or an empty collection.
SD_CHECKS=(packages hm_files chezmoi casks run record)
# The one machine-local file chezmoi needs. It is secret-bearing: this library
# tests that it exists and is readable and never opens, reads, hashes or prints it.
SD_MACHINE_DATA_REL="home/.chezmoidata/personal.yaml"
SD_RECORD_STATE="absent"
SD_CAUSE_SELECTION="unknown"   # yes | no | unknown, from the record
SD_CAUSE_REPO="unknown"
SD_CAUSE_GENERATION="unknown"
SD_APPLIED_SEL=""              # the record's selection (file state and hash), when it differs
SD_REPO_REV="unknown"
SD_REPO_DIRTY="unknown"
SD_OUTCOME=""
SD_EXIT=0
SD_NOTES=()
SD_LIMITS=()

# _sd_err MESSAGE: to stderr, and kept in SD_ERROR for the --json failure envelope.
SD_ERROR=""
_sd_err() { SD_ERROR="$*"; printf 'selection-diff: %s\n' "$*" >&2; }

# _sd_js TEXT: TEXT as a JSON string (quotes included). Escapes \ and " and
# every control character; no jq.
_sd_js() {
  local s="$1" i c u
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\b'/\\b}"
  s="${s//$'\f'/\\f}"
  if [[ "$s" == *[[:cntrl:]]* ]]; then
    for ((i = 1; i < 32; i++)); do
      c="$(printf '%b' "\\$(printf '%03o' "$i")")"
      [[ "$s" == *"$c"* ]] || continue
      u="$(printf '\\u%04x' "$i")"
      s="${s//"$c"/"$u"}"
    done
  fi
  printf '"%s"' "$s"
}

# _sd_row ROW: splits an entries row into SD_F. `IFS=tab read` would merge the
# empty fields, so it is done with parameter expansion.
SD_F=()
_sd_row() {
  local rest="$1"
  SD_F=()
  while :; do
    if [[ "$rest" == *"$_SEL_TAB"* ]]; then
      SD_F+=("${rest%%"$_SEL_TAB"*}")
      rest="${rest#*"$_SEL_TAB"}"
    else
      SD_F+=("$rest")
      break
    fi
  done
}

# ── classifier: pure, text in, TSV out ──────────────────────────────────────
#
# Entries are "kind name operation action from to group by_apply", tab
# separated. by_apply is true only when the next apply does it by itself.

# _sd_classify_packages GROUPMAP < package_delta output. GROUPMAP is "name<TAB>group".
_sd_classify_packages() {
  awk -F '\t' -v OFS='\t' -v gfile="$1" '
    FILENAME == gfile { g[$1] = $2; next }
    $1 == "summary" { next }
    $1 == "added"    { print "package", $2, "add", "install", "", $4, g[$2], "true" }
    $1 == "removed"  { print "package", $2, "remove", "uninstall", $3, "", g[$2], "true" }
    $1 == "upgraded" { print "package", $2, "change", "update", $3, $4, g[$2], "true" }
  ' "$1" -
}

# _sd_classify_files FILE: FILE holds "added|removed|changed<TAB>target" rows
# (from _sel_files_delta).
_sd_classify_files() {
  local row kind target k rows=()
  _sel_split rows "$(cat "$1")"
  for row in "${rows[@]+"${rows[@]}"}"; do
    [[ -n "$row" ]] || continue
    kind="${row%%"$_SEL_TAB"*}"
    target="${row#*"$_SEL_TAB"}"
    target="${target//"$_SEL_TAB"/\\t}"
    k='file'
    [[ -n "$(_sel_unit_note "$target")" ]] && k=unit
    case "$kind" in
      added)   printf '%s\t%s\tadd\tlink\t\t\t\ttrue\n' "$k" "$target" ;;
      removed) printf '%s\t%s\tremove\tunlink\t\t\t\ttrue\n' "$k" "$target" ;;
      changed) printf '%s\t%s\tchange\trelink\t\t\t\ttrue\n' "$k" "$target" ;;
    esac
  done
}

# _sd_classify_chezmoi < `chezmoi status` output. Columns X (the destination
# changed since chezmoi last wrote it) and Y (what an apply would do):
#   X blank, Y A / M / D   add / change / remove
#   X blank, Y R           change (a script runs)
#   X set, Y blank         keep (a local edit only; an apply leaves it)
#   X set, Y set           conflict (edited here and in the repo: an apply
#                          without --force stops)
# The count of keeps goes to stderr as "keep<TAB>N" for the caller to read.
_sd_classify_chezmoi() {
  awk -v OFS='\t' '
    length($0) < 4 { next }
    {
      x = substr($0, 1, 1); y = substr($0, 2, 1); p = substr($0, 4)
      gsub(/\t/, "\\t", p)
      if (x == " ") {
        if (y == "A") print "chezmoi", p, "add", "chezmoi apply creates it", "", "", "", "true"
        else if (y == "M") print "chezmoi", p, "change", "chezmoi apply updates it", "", "", "", "true"
        else if (y == "D") print "chezmoi", p, "remove", "chezmoi apply removes it", "", "", "", "true"
        else if (y == "R") print "chezmoi", p, "change", "chezmoi apply runs the script", "", "", "", "true"
      } else if (y == " ") keep++
      else print "chezmoi", p, "conflict", "chezmoi apply stops: edited here and in the repo (--force overwrites the local edit)", "", "", "", "false"
    }
    END { printf "%d\n", keep > "/dev/stderr" }
  '
}

# _sd_classify_casks DECLARED INSTALLED GATED: "name" lists (sorted, unique) and
# "group<TAB>cask" rows of the casks a group gates. Prints entries, and the
# counts "keep N" and "unmanaged N" on stderr.
_sd_classify_casks() {
  awk -F '\t' -v OFS='\t' -v dfile="$1" -v ifile="$2" '
    FILENAME == dfile { D[$1] = 1; next }
    FILENAME == ifile { I[$1] = 1; next }
    { gated[$2] = $1 }
    END {
      for (c in D) {
        if (c in I) keep++
        else print "cask", c, "add", "install at the next switch", "", "", "", "true"
      }
      for (c in I) {
        if (c in D) continue
        if (c in gated) print "cask", c, "manual", "stays installed (Homebrew cleanup = none); remove by hand: brew uninstall --cask " c, "", "", gated[c], "false"
        else unmanaged++
      }
      printf "%d %d\n", keep, unmanaged > "/dev/stderr"
    }
  ' "$1" "$2" "$3"
}

# ── collection ──────────────────────────────────────────────────────────────

_sd_note() { SD_NOTES+=("$1"); }

# _sd_check COMPONENT STATUS [REASON [DETAIL [REQUIRED]]]
_sd_check() {
  printf -v "SD_ST_$1" '%s' "$2"
  printf -v "SD_RS_$1" '%s' "${3:-}"
  printf -v "SD_DT_$1" '%s' "${4:-}"
  printf -v "SD_RQ_$1" '%s' "${5:-}"
}
_sd_get() { local n="SD_$1_$2"; printf '%s' "${!n:-}"; }

# _sd_machine_data_state: the ONE decision on machine-local data. Prints
# missing, unreadable or available, from -e, -L, -f and -r only. SAFETY: it must
# never open, read, source, hash or print the file (it holds private values).
_sd_machine_data_state() {
  local f="$REPO_ROOT/$SD_MACHINE_DATA_REL"
  if [[ ! -e "$f" ]]; then
    if [[ -L "$f" ]]; then printf 'unreadable'; else printf 'missing'; fi
  elif [[ ! -f "$f" || ! -r "$f" ]]; then printf 'unreadable'
  else printf 'available'; fi
}

# _sd_chezmoi_class TEXT: a fixed error class for a chezmoi failure. The raw
# line is never shown: a template or YAML error could quote private values.
_sd_chezmoi_class() {
  case "$1" in
    *"persistent state lock"*) printf 'state_locked' ;;
    *template*) printf 'template_error' ;;
    *[Yy][Aa][Mm][Ll]*) printf 'machine_data_invalid' ;;
    *) printf 'unspecified' ;;
  esac
}

# _sd_reason_text REASON DETAIL: the sentence for a reason code.
_sd_reason_text() {
  case "$1" in
    machine_data_missing)    printf 'machine-local data missing (%s)' "$SD_MACHINE_DATA_REL" ;;
    machine_data_unreadable) printf 'machine-local data present but unreadable (%s)' "$SD_MACHINE_DATA_REL" ;;
    chezmoi_missing)         printf 'chezmoi is not installed' ;;
    chezmoi_failed)
      case "$2" in
        state_locked) printf 'chezmoi status failed: another chezmoi holds its persistent state lock' ;;
        template_error) printf 'chezmoi status failed: a template could not be evaluated (class template_error)' ;;
        machine_data_invalid) printf 'chezmoi status failed: the machine-local data looks invalid (class machine_data_invalid)' ;;
        *) printf 'chezmoi status failed (class unspecified)' ;;
      esac ;;
    generation_unreadable)   printf 'the installed Home Manager generation could not be read' ;;
    no_generation)           printf 'no Home Manager generation yet (first install): everything declared is pending' ;;
    brew_missing)            printf 'brew is not installed, so the cask state is unknown' ;;
    brew_failed)             printf 'brew list --cask failed, so the cask state is unknown' ;;
    run_unfinished)          printf 'the last run has no exit code: it is still running or it was killed' ;;
    last_run_failed)         printf 'the last run failed' ;;
    record_absent)           printf 'no applied-state record' ;;
    record_invalid)          printf 'the applied-state record is invalid' ;;
    record_stale)            printf 'the applied-state record is for another generation' ;;
    *)                       printf '%s' "$1" ;;
  esac
}

# _sd_unknown_entry KIND TEXT [unknown|error]: one entry for a component that
# could not be compared.
_sd_unknown_entry() {
  printf '%s\t(all)\t%s\t%s\t\t\t\tfalse\n' "$1" "${3:-unknown}" "$2" >>"$SELECTION_WORK/entries.tsv" || return 1
}

# _sd_pending KINDS: the add, remove and change entries of those kinds.
_sd_pending() {
  awk -F '\t' -v k="$1" 'index(" " k " ", " " $1 " ") && ($3 == "add" || $3 == "remove" || $3 == "change") { n++ } END { print n + 0 }' "$SELECTION_WORK/entries.tsv"
}

# _sd_finalize_checks: components not already unknown or error become in_sync or
# pending from their entries; the record never affects completeness or the exit.
_sd_finalize_checks() {
  local c kinds n
  for c in packages hm_files chezmoi casks; do
    [[ -z "$(_sd_get ST "$c")" ]] || continue
    case "$c" in packages) kinds=package ;; hm_files) kinds="file unit" ;; chezmoi) kinds=chezmoi ;; casks) kinds=cask ;; esac
    n="$(_sd_pending "$kinds")" || return 1
    if ((n > 0)); then printf -v "SD_ST_$c" pending; else printf -v "SD_ST_$c" in_sync; fi
  done
  # A conflict is a difference an apply would stop on: chezmoi is pending even
  # when conflicts are all there is (they are not add, remove or change).
  if [[ "$(_sd_get ST chezmoi)" != unknown && "$(_sd_get ST chezmoi)" != error ]]; then
    n="$(_sd_count_op chezmoi conflict)" || return 1
    if ((n > 0)); then _sd_check chezmoi pending conflicts_present; fi
  fi
}
_sd_count_op() { awk -F '\t' -v k="$1" -v op="$2" '$1 == k && $3 == op { n++ } END { print n + 0 }' "$SELECTION_WORK/entries.tsv"; }

# Repo facts for the output; --no-optional-locks keeps git from refreshing the index.
_sd_repo_facts() {
  local rev porcelain
  SD_REPO_REV=unknown
  SD_REPO_DIRTY=unknown
  rev="$(git --no-optional-locks -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)" || return 0
  [[ "$rev" =~ ^[0-9a-f]{40}$ ]] && SD_REPO_REV="$rev"
  if porcelain="$(git --no-optional-locks -C "$REPO_ROOT" status --porcelain -- nix home 2>/dev/null)"; then
    if [[ -n "$porcelain" ]]; then SD_REPO_DIRTY=yes; else SD_REPO_DIRTY=no; fi
  fi
}

# The last run, taken with sed only. No exit_code line means it is still running
# or was killed; a non-zero exit code or a failed:* status needs a person.
_sd_run_state() {
  local last meta rid status exitc
  _sd_check run in_sync
  last="${STATE_DIR:-}/last-run"
  [[ -f "$last" ]] || return 0
  meta="$(sed -n '1p' "$last")"
  if [[ ! -f "$meta" ]]; then
    _sd_note "the last run's record is gone ($meta); it is not taken into account"
    return 0
  fi
  rid="$(sed -n 's/^run_id=//p' "$meta" | tail -n 1)"
  status="$(sed -n 's/^status=//p' "$meta" | tail -n 1)"
  exitc="$(sed -n 's/^exit_code=//p' "$meta" | tail -n 1)"
  rid="${rid:-unknown}"
  # the status goes into the detail, restricted to a safe alphabet
  status="${status//[!A-Za-z0-9:_-]/}"
  if [[ -z "$exitc" ]]; then
    _sd_check run unknown run_unfinished "status ${status:-none}"
    printf 'run\t%s\tmanual\t%s\t\t\t\tfalse\n' "$rid" \
      "last run has no exit code (status ${status:-none}): it is still running or it was killed; check sys-update-log before applying" >>"$SELECTION_WORK/entries.tsv" || return 1
  elif [[ "$exitc" != 0 || "$status" == failed:* ]]; then
    _sd_check run error last_run_failed "status ${status:-none}"
    case "$status" in
      failed:activate)
        printf 'run\t%s\tmanual\t%s\t\t\t\tfalse\n' "$rid" \
          "last run failed:activate (exit $exitc): the profile may have moved; roll back with: sys-update rollback" >>"$SELECTION_WORK/entries.tsv" || return 1 ;;
      *)
        printf 'run\t%s\tmanual\t%s\t\t\t\tfalse\n' "$rid" \
          "last run failed (status ${status:-none}, exit $exitc); see sys-update-log before applying" >>"$SELECTION_WORK/entries.tsv" || return 1 ;;
    esac
  fi
}
# _sd_file_keys FILE: the group keys named in a selection file.
_sd_file_keys() { _sel_groups_of_file "$1" | cut -f1; }

# selection_diff_collect: runs the facts and fills the result variables and
# SELECTION_WORK/entries.tsv (unsorted). Returns 1 on an execution failure.
selection_diff_collect() {
  local w="$SELECTION_WORK" rc=0 row rows=() g v src keys
  : >"$w/entries.tsv"
  SELECTION_REPO_ROOT="$REPO_ROOT"
  SELECTION_HOST="$HOST_PROFILE"
  SEL_EVAL_EXTRA=(--no-write-lock-file)
  SEL_FACTS_TAG=selection-diff

  if ! command -v nix >/dev/null 2>&1; then
    _sd_err "nix is not installed, so the declared state cannot be evaluated"
    return 1
  fi
  # Strict: no lenient fallback; selection_facts prints its reasons to stdout
  # and the Nix error to stderr, and stdout here must stay clean.
  selection_facts >"$w/facts.out" || rc=$?
  if ((rc != 0)); then
    [[ -s "$w/facts.out" ]] && sed 's/^/selection-diff: /' "$w/facts.out" >&2
    _sd_err "the declared state could not be evaluated"
    return 1
  fi

  # Selected
  SD_SEL_FILE="$(selection_dir)/selection.toml"
  if [[ -f "$SD_SEL_FILE" ]]; then SD_SEL_STATE=present; SD_SEL_SHA="$(install_record_sha256 "$SD_SEL_FILE" || printf unknown)"
  else SD_SEL_STATE=absent; SD_SEL_SHA=none; fi
  SD_PROFILE="$(_sel_state_profile "$w/c.tsv")"
  SD_PROFILE_SRC=host-default
  if [[ "$SD_SEL_STATE" == present && "$(selection_profile_of "$SD_SEL_FILE")" != default ]]; then SD_PROFILE_SRC=local; fi
  _sel_state_groups "$w/c.tsv" | LC_ALL=C sort >"$w/groups.tsv"
  : >"$w/group-src.tsv"
  keys=""
  [[ "$SD_SEL_STATE" == present ]] && keys="$(_sd_file_keys "$SD_SEL_FILE")"
  _sel_split rows "$(cat "$w/groups.tsv")"
  for row in "${rows[@]+"${rows[@]}"}"; do
    [[ -n "$row" ]] || continue
    g="${row%%"$_SEL_TAB"*}"
    v="${row#*"$_SEL_TAB"}"
    src=profile
    if printf '%s\n' "$keys" | grep -Fxq -- "$g"; then src=local; fi
    printf '%s\t%s\t%s\n' "$g" "$v" "$src" >>"$w/group-src.tsv"
  done
  # a group key the host does not have (macInput on Linux)
  for g in $keys; do
    if ! awk -F '\t' -v g="$g" '$1 == g { f = 1 } END { exit !f }' "$w/groups.tsv"; then
      printf 'group\t%s\tunsupported\tignored on %s: this host has no such group\t\t\t\tfalse\n' "$g" "$HOST_PROFILE" >>"$w/entries.tsv" || { _sd_err "internal error: recording an unsupported group failed"; return 1; }
    fi
  done
  if [[ "$SD_PROFILE" == personal && -z "$(_sel_members_of @personal)" ]]; then
    printf 'group\t@personal\tunsupported\tthe profile is personal but declares no personal-only packages\t\t\t\tfalse\n' >>"$w/entries.tsv" || { _sd_err "internal error: recording an unsupported group failed"; return 1; }
  fi

  # group of each package, for the entries
  : >"$w/pkg-group.tsv"
  _sel_sets
  for g in "${SEL_SETS[@]+"${SEL_SETS[@]}"}"; do
    _sel_members_of "$g" | awk -v g="$g" '{ print $0 "\t" g }' >>"$w/pkg-group.tsv"
  done

  SD_KEEP=0
  for row in packages hm_files chezmoi casks; do _sd_check "$row" ""; done
  # No Home Manager profile directory at all cannot say "no generation yet": it
  # is unknown (the layout is unreadable here). "none" stays for a profile
  # directory without a generation link.
  if [[ "$SEL_I_STATE" == none ]] && ! selection_hm_profile >/dev/null 2>&1; then SEL_I_STATE=unknown; fi
  case "$SEL_I_STATE" in
    unknown)
      _sd_check packages unknown generation_unreadable
      _sd_check hm_files unknown generation_unreadable
      _sd_unknown_entry packages "$(_sd_reason_text generation_unreadable)" || { _sd_err "internal error: recording an unknown source failed"; return 1; }
      _sd_unknown_entry hm_files "$(_sd_reason_text generation_unreadable)" || { _sd_err "internal error: recording an unknown source failed"; return 1; }
      ;;
    *)
      # No generation yet (first install): the comparison is complete, everything
      # declared is pending; the reason says why.
      if [[ "$SEL_I_STATE" == none ]]; then _sd_check packages "" no_generation; _sd_check hm_files "" no_generation; fi
      local pk="$w/pkg-delta.tsv" n_same
      # Fail closed: this runs without -e, so every step is checked; a failed
      # write or awk is exit 1, never a quiet "in sync".
      package_delta "$(cat "$w/i-pkgs.tsv")" "$(cat "$w/c-pkgs.tsv")" >"$pk" || { _sd_err "internal error: the package comparison failed"; return 1; }
      _sd_classify_packages "$w/pkg-group.tsv" <"$pk" >>"$w/entries.tsv" || { _sd_err "internal error: classifying packages failed"; return 1; }
      n_same="$(awk -F '\t' '$1 == "summary" { print $5 }' "$pk")" || { _sd_err "internal error: reading the package summary failed"; return 1; }
      SD_KEEP=$((SD_KEEP + ${n_same:-0}))
      _sel_state_files "$w/c.tsv" >"$w/c-files.tsv" || { _sd_err "internal error: reading the declared files failed"; return 1; }
      _sel_files_delta tree "$w/i-files.tsv" "$w/c-files.tsv" >"$w/files-delta.tsv" || { _sd_err "internal error: the file comparison failed"; return 1; }
      _sd_classify_files "$w/files-delta.tsv" >>"$w/entries.tsv" || { _sd_err "internal error: classifying files failed"; return 1; }
      local nf nd
      nf="$(grep -c . "$w/c-files.tsv" || true)"
      nd="$(grep -cE '^(added|changed)' "$w/files-delta.tsv" || true)"
      SD_KEEP=$((SD_KEEP + (nf > nd ? nf - nd : 0)))
      ;;
  esac

  # chezmoi: needs machine-local data. Whether it is there is decided in one
  # place and by existence and readability alone, never by opening the file.
  local md
  md="$(_sd_machine_data_state)"
  if [[ "$md" != available ]]; then
    _sd_check chezmoi unknown "machine_data_$md" "" "$SD_MACHINE_DATA_REL"
    _sd_unknown_entry chezmoi "$(_sd_reason_text "machine_data_$md")" || { _sd_err "internal error: recording an unknown source failed"; return 1; }
  else
    _sel_chezmoi_status
    if [[ "$SEL_CHEZMOI" == ok ]]; then
      _sd_classify_chezmoi <"$w/chezmoi.out" >>"$w/entries.tsv" 2>"$w/chezmoi.keep" || { _sd_err "internal error: classifying chezmoi status failed"; return 1; }
      row="$(tail -n 1 "$w/chezmoi.keep")"
      [[ "$row" =~ ^[0-9]+$ ]] || { _sd_err "internal error: the chezmoi classifier gave no count"; return 1; }
      SD_KEEP=$((SD_KEEP + row))
    elif [[ "$SEL_CHEZMOI_WHY" == "chezmoi not installed" ]]; then
      _sd_check chezmoi unknown chezmoi_missing
      _sd_unknown_entry chezmoi "$(_sd_reason_text chezmoi_missing)" || { _sd_err "internal error: recording an unknown source failed"; return 1; }
    else
      row="$(_sd_chezmoi_class "$SEL_CHEZMOI_WHY")"
      _sd_check chezmoi error chezmoi_failed "$row"
      _sd_unknown_entry chezmoi "$(_sd_reason_text chezmoi_failed "$row")" error || { _sd_err "internal error: recording an unknown source failed"; return 1; }
    fi
  fi

  # casks (macOS)
  _sd_check casks not_applicable
  if [[ "$HOST_PROFILE" == macos ]]; then
    _sd_check casks ""
    _sel_brew_casks
    if [[ "$SEL_BREW" == ok ]]; then
      { awk -F '\t' '$1 == "C" { print $2 }' "$w/c.tsv" | LC_ALL=C sort -u >"$w/casks-c.txt"; } || { _sd_err "internal error: reading the declared casks failed"; return 1; }
      awk -F '\t' '$1 == "X" { print $2 "\t" $3 }' "$w/m.tsv" >"$w/casks-gated.tsv" || { _sd_err "internal error: reading the gated casks failed"; return 1; }
      _sd_classify_casks "$w/casks-c.txt" "$w/casks-installed.txt" "$w/casks-gated.tsv" >>"$w/entries.tsv" 2>"$w/casks.counts" || { _sd_err "internal error: classifying casks failed"; return 1; }
      SD_KEEP=$((SD_KEEP + $(awk '{ print $1 + 0 }' "$w/casks.counts")))
      row="$(awk '{ print $2 + 0 }' "$w/casks.counts")"
      if ((row > 0)); then _sd_note "unmanaged installed casks: $row (not declared and not gated by a group; left alone)"; fi
    else
      # brew missing is missing information (unknown); brew present but failing
      # is a comparison that failed unexpectedly (error), like chezmoi_failed.
      if command -v brew >/dev/null 2>&1; then
        _sd_check casks error brew_failed
        _sd_unknown_entry casks "$(_sd_reason_text brew_failed)" error ||
          { _sd_err "internal error: recording an unknown source failed"; return 1; }
      else
        _sd_check casks unknown brew_missing
        _sd_unknown_entry casks "$(_sd_reason_text brew_missing)" || { _sd_err "internal error: recording an unknown source failed"; return 1; }
      fi
    fi
  fi

  _sd_run_state || { _sd_err "internal error: recording the last run failed"; return 1; }
  _sd_repo_facts
  _sd_record_state

  _sd_finalize_checks || { _sd_err "internal error: deriving the check states failed"; return 1; }
  LC_ALL=C sort -t "$_SEL_TAB" -k1,1 -k2,2 -k3,3 "$w/entries.tsv" >"$w/entries.sorted.tsv" || { _sd_err "internal error: sorting the entries failed"; return 1; }
}

# The applied-state record (ops/lib/install-record.sh): when it is ok (valid and
# for the current generation) it says why changes are pending. Absent, invalid
# or stale, every cause stays "unknown": never a false "no".
_sd_record_state() {
  local current
  SD_CAUSE_SELECTION=unknown; SD_CAUSE_REPO=unknown; SD_CAUSE_GENERATION=unknown; SD_APPLIED_SEL=""
  if [[ "$HOST_PROFILE" == macos ]]; then
    current="$(readlink -f -- "${SYS_UPDATE_DARWIN_SYSTEM_LINK:-/run/current-system}" 2>/dev/null)" || current=""
  else
    current="$SEL_I_GEN"
  fi
  install_record_read "$current" >/dev/null
  SD_RECORD_STATE="$IR_STATE"
  # The record is a limitation: it never changes completeness or the exit code.
  if [[ "$SD_RECORD_STATE" == ok ]]; then _sd_check record in_sync; else _sd_check record unknown "record_$SD_RECORD_STATE"; fi
  [[ "$SD_RECORD_STATE" == ok ]] || return 0
  SD_CAUSE_GENERATION=no
  # An unhashable selection file (SD_SEL_SHA=unknown) cannot be compared.
  if [[ "$IR_SELECTION_SHA256" == unknown || "$SD_SEL_SHA" == unknown ]]; then
    SD_CAUSE_SELECTION=unknown
  elif [[ "$IR_SELECTION_SHA256" != "$SD_SEL_SHA" ]]; then
    SD_CAUSE_SELECTION=yes
    SD_APPLIED_SEL="$IR_SELECTION_FILE $IR_SELECTION_SHA256"
  else
    SD_CAUSE_SELECTION=no
  fi
  # "no" only when both sides are clean at the same revision: a tree that is
  # dirty on both sides may hold different uncommitted content, so that is
  # unknown; clean on one side and dirty on the other is a change.
  if [[ "$IR_REPO_REV" == unknown || "$SD_REPO_REV" == unknown ]]; then SD_CAUSE_REPO=unknown
  elif [[ "$IR_REPO_REV" != "$SD_REPO_REV" ]]; then SD_CAUSE_REPO=yes
  elif [[ "$IR_REPO_DIRTY" == unknown || "$SD_REPO_DIRTY" == unknown ]]; then SD_CAUSE_REPO=unknown
  elif [[ "$IR_REPO_DIRTY" == no && "$SD_REPO_DIRTY" == no ]]; then SD_CAUSE_REPO=no
  elif [[ "$IR_REPO_DIRTY" == yes && "$SD_REPO_DIRTY" == yes ]]; then SD_CAUSE_REPO=unknown
  else SD_CAUSE_REPO=yes
  fi
}

# ── outcome ─────────────────────────────────────────────────────────────────

# _sd_count OP: the number of entries with that operation.
_sd_count() { awk -F '\t' -v op="$1" '$3 == op { n++ } END { print n + 0 }' "$SELECTION_WORK/entries.sorted.tsv"; }

selection_diff_outcome() {
  local add remove change conflict unknown c st
  add="$(_sd_count add)"; remove="$(_sd_count remove)"; change="$(_sd_count change)"
  conflict="$(_sd_count conflict)"; unknown="$(_sd_count unknown)"
  SD_LIMITS=()
  SD_LIMITS+=("Nothing is built or activated, so a build or activation failure cannot be predicted.")
  SD_LIMITS+=("Homebrew formulae, mise tools and nix profile entries are not compared.")
  if [[ "$SD_RECORD_STATE" != ok ]]; then
    SD_LIMITS+=("The applied-state record is $SD_RECORD_STATE, so the causes of the changes are unknown.")
  fi
  # Complete only when every requested check completed. A check that is unknown
  # or error forces 11 by itself, even if its entry could not be recorded:
  # unknown is never "in sync". The record is a limitation and does not count.
  SD_COMPLETE=yes
  for c in packages hm_files chezmoi casks run; do
    st="$(_sd_get ST "$c")"
    if [[ "$st" == unknown || "$st" == error ]]; then SD_COMPLETE=no; fi
  done
  if ((conflict > 0 || unknown > 0)) || [[ "$SD_COMPLETE" == no ]]; then
    SD_EXIT=11; SD_OUTCOME=action-required
  elif ((add + remove + change > 0)); then
    SD_EXIT=10; SD_OUTCOME=changes-pending
  else
    SD_EXIT=0; SD_OUTCOME=in-sync
  fi
}

# ── text renderer ───────────────────────────────────────────────────────────

_sd_class_title() {
  case "$1" in
    remove)      printf 'REMOVE' ;;
    conflict)    printf 'CONFLICT' ;;
    add)         printf 'ADD' ;;
    change)      printf 'CHANGE' ;;
    manual)      printf 'MANUAL' ;;
    unsupported) printf 'UNSUPPORTED' ;;
    unknown)     printf 'UNKNOWN' ;;
    error)       printf 'ERROR' ;;
  esac
}
_sd_class_blurb() {
  case "$1" in
    remove)      printf 'the next sys-update --apply would remove' ;;
    conflict)    printf 'the next sys-update --apply stops here until you resolve it' ;;
    add)         printf 'the next sys-update --apply would add' ;;
    change)      printf 'the next sys-update --apply would change' ;;
    manual)      printf 'sys-update does not do these; they need you' ;;
    unsupported) printf 'in the selection, but not applicable on this host' ;;
    unknown)     printf 'missing information prevents the comparison; nothing is claimed about these' ;;
    error)       printf 'the comparison failed unexpectedly; nothing is claimed about these' ;;
  esac
}

# _sd_render_entry ROW: one section line.
_sd_render_entry() {
  local extra=""
  _sd_row "$1"
  # fields: kind name operation action from to group by_apply
  if [[ -n "${SD_F[4]}" && -n "${SD_F[5]}" ]]; then extra=" (${SD_F[4]} -> ${SD_F[5]})"
  elif [[ -n "${SD_F[4]}" ]]; then extra=" (${SD_F[4]})"
  elif [[ -n "${SD_F[5]}" ]]; then extra=" (${SD_F[5]})"; fi
  [[ -n "${SD_F[6]}" ]] && extra+=" [${SD_F[6]}]"
  printf '  %-9s %s%s: %s\n' "${SD_F[0]}" "${SD_F[1]}" "$extra" "${SD_F[3]}"
}

_sd_render_section() { # CLASS
  local c="$1" n row rows=() i=0
  n="$(_sd_count "$c")"
  ((n > 0)) || return 0
  printf '\n%s (%s): %s\n' "$(_sd_class_title "$c")" "$n" "$(_sd_class_blurb "$c")"
  _sel_split rows "$(awk -F '\t' -v op="$c" '$3 == op' "$SELECTION_WORK/entries.sorted.tsv")"
  for row in "${rows[@]+"${rows[@]}"}"; do
    if ((i < SD_LIST_MAX)); then _sd_render_entry "$row"; fi
    i=$((i + 1))
  done
  if ((n > SD_LIST_MAX)); then printf '  and %s more\n' "$((n - SD_LIST_MAX))"; fi
}

# _sd_kind_summary LABEL SOURCE KINDS KEEP: "keep N, add N, remove N, change N" or unknown.
_sd_kind_summary() {
  local label="$1" src="$2" kinds="$3" keep="$4" a r c
  if [[ "$src" == unknown ]]; then printf '%s: unknown (could not be read)\n' "$label"; return 0; fi
  a="$(awk -F '\t' -v k="$kinds" 'index(" " k " ", " " $1 " ") && $3 == "add" { n++ } END { print n + 0 }' "$SELECTION_WORK/entries.sorted.tsv")"
  r="$(awk -F '\t' -v k="$kinds" 'index(" " k " ", " " $1 " ") && $3 == "remove" { n++ } END { print n + 0 }' "$SELECTION_WORK/entries.sorted.tsv")"
  c="$(awk -F '\t' -v k="$kinds" 'index(" " k " ", " " $1 " ") && $3 == "change" { n++ } END { print n + 0 }' "$SELECTION_WORK/entries.sorted.tsv")"
  printf '%s: keep %s, add %s, remove %s, change %s\n' "$label" "$keep" "$a" "$r" "$c"
}

# _sd_group_lines: keep, add, remove and stays off per group, packages only
# (the casks a group gates are counted on macOS), from the installed set and
# the declared set.
_sd_group_lines() {
  local w="$SELECTION_WORK" g label names n in_i in_d keep off adds rems parts
  printf 'By group\n'
  if [[ "$SEL_I_STATE" == unknown ]]; then
    printf '  unknown: the installed generation could not be read, so keep, add and remove cannot be told\n'
    return 0
  fi
  _sel_pnames "$w/i-pkgs.tsv" >"$w/i-names.txt"
  _sel_pnames "$w/c-pkgs.tsv" >"$w/d-names.txt"
  _sel_sets
  for g in "${SEL_SETS[@]+"${SEL_SETS[@]}"}"; do
    label="$(_sel_set_label "$g")"
    keep=0; off=0; adds=0; rems=0
    _sel_split names "$(_sel_members_of "$g")"
    for n in "${names[@]+"${names[@]}"}"; do
      [[ -n "$n" ]] || continue
      in_i=0; in_d=0
      _sel_in_file "$n" "$w/i-names.txt" && in_i=1
      _sel_in_file "$n" "$w/d-names.txt" && in_d=1
      if ((in_i && in_d)); then keep=$((keep + 1))
      elif ((in_d)); then adds=$((adds + 1))
      elif ((in_i)); then rems=$((rems + 1))
      else off=$((off + 1)); fi
    done
    parts=""
    ((keep)) && parts+="keep $keep"
    ((adds)) && parts+="${parts:+; }add $adds"
    ((rems)) && parts+="${parts:+; }remove $rems"
    ((off)) && parts+="${parts:+; }stays off $off"
    printf '  %-14s %s\n' "$label" "${parts:-no members}"
  done
}

# _sd_text_line LABEL COMPONENT KINDS KEEP: the summary line of one component. An
# unknown or error component says why and how much else was verified.
_sd_text_line() {
  local st
  st="$(_sd_get ST "$2")"
  case "$st" in
    not_applicable | "") return 0 ;;
    unknown | error)
      printf '%s: %s — %s; %s other items in sync; assessment incomplete\n' "$1" "$st" \
        "$(_sd_reason_text "$(_sd_get RS "$2")" "$(_sd_get DT "$2")")" "$SD_KEEP"
      ;;
    *) _sd_kind_summary "$1" ok "$3" "${4:-0}" ;;
  esac
}

selection_diff_render_text() {
  local w="$SELECTION_WORK" row rows=() line c gl="" n
  printf 'SELECTION DIFF · %s   (read-only: nothing is built, written or applied)\n\n' "$HOST_PROFILE"
  _sel_split rows "$(cat "$w/group-src.tsv")"
  for row in "${rows[@]+"${rows[@]}"}"; do
    [[ -n "$row" ]] || continue
    _sd_row "$row"
    gl+="${gl:+ }${SD_F[0]}=$([[ "${SD_F[1]}" == true ]] && echo on || echo off) (${SD_F[2]})"
  done
  printf 'Selected:  %s (%s); profile %s (%s); %s\n' "$SD_SEL_FILE" "$SD_SEL_STATE" "$SD_PROFILE" "$SD_PROFILE_SRC" "${gl:-no groups}"
  printf 'Declared:  ok (evaluated, nothing built)\n'
  case "$SEL_I_STATE" in
    ok) printf 'Installed: ok; Home Manager generation %s (%s)\n' "$(_sd_generation_number)" "$SEL_I_GEN" ;;
    none) printf 'Installed: none; no Home Manager generation yet\n' ;;
    *) printf 'Installed: unknown; the installed generation could not be read\n' ;;
  esac
  if [[ "$SD_RECORD_STATE" == ok ]]; then
    printf 'Record:    ok; written by %s at %s (run %s)\n' "$IR_WRITTEN_BY" "$IR_WRITTEN_AT" "$IR_RUN_ID"
    printf 'Causes:    selection changed since the last apply: %s; repo changed: %s; generation changed outside sys-update: %s\n' \
      "$SD_CAUSE_SELECTION" "$SD_CAUSE_REPO" "$SD_CAUSE_GENERATION"
    if [[ -n "$SD_APPLIED_SEL" ]]; then printf 'Applied:   selection file %s (sha256 %s)\n' "${SD_APPLIED_SEL%% *}" "${SD_APPLIED_SEL#* }"; fi
    printf '\n'
  else
    printf 'Record:    %s (the causes of the changes are unknown)\n\n' "$SD_RECORD_STATE"
  fi
  _sd_group_lines
  printf '\n'
  _sd_text_line Packages packages package "$(awk -F '\t' '$1 == "summary" { print $5 }' "$w/pkg-delta.tsv" 2>/dev/null)"
  n="$(grep -c . "$w/c-files.tsv" 2>/dev/null || true)"
  c="$(grep -cE '^(added|changed)' "$w/files-delta.tsv" 2>/dev/null || true)"
  _sd_text_line "HM files and units" hm_files "file unit" "$((n > c ? n - c : 0))"
  _sd_text_line chezmoi chezmoi chezmoi "$(tail -n 1 "$w/chezmoi.keep" 2>/dev/null)"
  _sd_text_line Casks casks cask "$(awk '{ print $1 + 0 }' "$w/casks.counts" 2>/dev/null)"
  for c in "${SD_CLASSES[@]}"; do _sd_render_section "$c"; done
  printf '\nLimitations\n'
  for line in "${SD_LIMITS[@]}"; do printf '  %s\n' "$line"; done
  if ((${#SD_NOTES[@]})); then
    printf '\nNotes\n'
    for line in "${SD_NOTES[@]}"; do printf '  %s\n' "$line"; done
  fi
  printf '\n'
  case "$SD_OUTCOME" in
    in-sync) printf 'RESULT: IN SYNC\n' ;;
    changes-pending) printf 'RESULT: CHANGES PENDING (exit 10): sys-update --apply would change the system\n' ;;
    action-required)
      if [[ "$SD_COMPLETE" == no ]]; then
        printf 'RESULT: ACTION REQUIRED (exit 11): assessment incomplete; resolve the items above before sys-update --apply\n'
      else
        printf 'RESULT: ACTION REQUIRED (exit 11): resolve the items above before sys-update --apply\n'
      fi ;;
  esac
}

# ── JSON renderer ───────────────────────────────────────────────────────────

# The number in the Home Manager profile link (home-manager-N-link), or empty.
_sd_generation_number() {
  local link target
  link="$(selection_hm_profile 2>/dev/null)" || return 0
  target="$(readlink "$link" 2>/dev/null)" || return 0
  [[ "$target" =~ -([0-9]+)-link$ ]] && printf '%s' "${BASH_REMATCH[1]}"
  return 0
}

_sd_json_obj_strs() { # _sd_json_obj_strs FILE KEYCOL VALCOL "string"|"bool"
  local f="$1" kc="$2" vc="$3" mode="$4" out="" row rows=() k v
  _sel_split rows "$(cat "$f")"
  for row in "${rows[@]+"${rows[@]}"}"; do
    [[ -n "$row" ]] || continue
    k="$(printf '%s' "$row" | cut -f"$kc")"
    v="$(printf '%s' "$row" | cut -f"$vc")"
    if [[ "$mode" == bool ]]; then out+="${out:+, }$(_sd_js "$k"): $v"; else out+="${out:+, }$(_sd_js "$k"): $(_sd_js "$v")"; fi
  done
  printf '{%s}' "$out"
}

selection_diff_render_json() {
  local w="$SELECTION_WORK" add remove change conflict manual unsupported unknown gen_n gen i first row rows=()
  add="$(_sd_count add)"; remove="$(_sd_count remove)"; change="$(_sd_count change)"
  conflict="$(_sd_count conflict)"; manual="$(_sd_count manual)"; unsupported="$(_sd_count unsupported)"; unknown="$(_sd_count unknown)"
  printf '{\n'
  printf '  "schema_version": 1,\n'
  printf '  "command": "selection-diff",\n'
  printf '  "check": true,\n'
  printf '  "applied": false,\n'
  printf '  "outcome": %s,\n' "$(_sd_js "$SD_OUTCOME")"
  printf '  "exit_code": %s,\n' "$SD_EXIT"
  printf '  "host": %s,\n' "$(_sd_js "$HOST_PROFILE")"
  printf '  "repo": {"rev": %s, "dirty": %s},\n' "$(_sd_js "$SD_REPO_REV")" "$(_sd_js "$SD_REPO_DIRTY")"
  # the groups in sorted order: name true|false, and where each came from
  local gv gs
  gv="$(awk -F '\t' '{ print $1 "\t" $2 }' "$w/group-src.tsv" >"$w/g1.tsv"; _sd_json_obj_strs "$w/g1.tsv" 1 2 bool)"
  gs="$(awk -F '\t' '{ print $1 "\t" $3 }' "$w/group-src.tsv" >"$w/g2.tsv"; _sd_json_obj_strs "$w/g2.tsv" 1 2 string)"
  printf '  "selection": {"file": %s, "sha256": %s, "profile": %s, "groups": %s, "sources": {"file": %s, "profile": %s, "groups": %s}},\n' \
    "$(_sd_js "$SD_SEL_FILE")" "$(_sd_js "$SD_SEL_SHA")" "$(_sd_js "$SD_PROFILE")" "$gv" \
    "$(_sd_js "$SD_SEL_STATE")" "$(_sd_js "$SD_PROFILE_SRC")" "$gs"
  if [[ -n "$SD_APPLIED_SEL" ]]; then
    printf '  "applied_selection": {"file": %s, "sha256": %s},\n' "$(_sd_js "${SD_APPLIED_SEL%% *}")" "$(_sd_js "${SD_APPLIED_SEL#* }")"
  else
    printf '  "applied_selection": null,\n'
  fi
  gen_n="$(_sd_generation_number)"
  if [[ "$SEL_I_STATE" == ok ]]; then gen="$(_sd_js "$SEL_I_GEN")"; else gen=null; fi
  printf '  "installed": {"state": %s, "generation": %s, "generation_number": %s},\n' "$(_sd_js "$SEL_I_STATE")" "$gen" "${gen_n:-null}"
  printf '  "record": {"state": %s},\n' "$(_sd_js "$SD_RECORD_STATE")"
  printf '  "causes": {"selection_changed": %s, "repo_changed": %s, "generation_changed_outside": %s},\n' \
    "$(_sd_js "$SD_CAUSE_SELECTION")" "$(_sd_js "$SD_CAUSE_REPO")" "$(_sd_js "$SD_CAUSE_GENERATION")"
  printf '  "complete": %s,\n' "$([[ "$SD_COMPLETE" == yes ]] && echo true || echo false)"
  printf '  "checks": {'
  local c first_c=1 obj req r
  for c in "${SD_CHECKS[@]}"; do
    obj="{\"status\": $(_sd_js "$(_sd_get ST "$c")")"
    [[ -z "$(_sd_get RS "$c")" ]] || obj+=", \"reason\": $(_sd_js "$(_sd_get RS "$c")")"
    [[ -z "$(_sd_get DT "$c")" ]] || obj+=", \"detail\": $(_sd_js "$(_sd_get DT "$c")")"
    if [[ -n "$(_sd_get RQ "$c")" ]]; then
      req=""
      for r in $(_sd_get RQ "$c"); do req+="${req:+, }$(_sd_js "$r")"; done
      obj+=", \"required\": [$req]"
    fi
    [[ "$c" != record ]] || obj+=", \"affects_exit\": false"
    obj+="}"
    if ((first_c)); then first_c=0; else printf ','; fi
    printf '\n    %s: %s' "$(_sd_js "$c")" "$obj"
  done
  printf '\n  },\n'
  printf '  "counts": {"add": %s, "remove": %s, "change": %s, "keep": %s, "conflict": %s, "manual": %s, "unsupported": %s, "unknown": %s, "error": %s},\n' \
    "$add" "$remove" "$change" "$SD_KEEP" "$conflict" "$manual" "$unsupported" "$unknown" "$(_sd_count error)"
  # changed items only; keep and n/a items are counts
  first=1
  printf '  "entries": ['
  _sel_split rows "$(cat "$w/entries.sorted.tsv")"
  for row in "${rows[@]+"${rows[@]}"}"; do
    [[ -n "$row" ]] || continue
    _sd_row "$row"
    if ((first)); then printf '\n'; first=0; else printf ',\n'; fi
    printf '    {"kind": %s, "name": %s, "operation": %s, "action": %s, "from": %s, "to": %s, "group": %s, "by_apply": %s}' \
      "$(_sd_js "${SD_F[0]}")" "$(_sd_js "${SD_F[1]}")" "$(_sd_js "${SD_F[2]}")" "$(_sd_js "${SD_F[3]}")" \
      "$(_sd_js "${SD_F[4]}")" "$(_sd_js "${SD_F[5]}")" "$(_sd_js "${SD_F[6]}")" "$([[ "${SD_F[7]}" == true ]] && echo true || echo false)"
  done
  if ((first)); then printf '],\n'; else printf '\n  ],\n'; fi
  printf '  "limitations": ['
  i=0
  for row in "${SD_LIMITS[@]}"; do
    if ((i == 0)); then printf '\n'; else printf ',\n'; fi
    printf '    %s' "$(_sd_js "$row")"
    i=$((i + 1))
  done
  if ((i)); then printf '\n  ],\n'; else printf '],\n'; fi
  printf '  "notes": ['
  i=0
  for row in "${SD_NOTES[@]+"${SD_NOTES[@]}"}"; do
    if ((i == 0)); then printf '\n'; else printf ',\n'; fi
    printf '    %s' "$(_sd_js "$row")"
    i=$((i + 1))
  done
  if ((i)); then printf '\n  ]\n'; else printf ']\n'; fi
  printf '}\n'
}

# selection_diff_render_failed: the minimal envelope for an early failure (exit
# 1) under --json. Usage errors (exit 2) never get here and print nothing.
selection_diff_render_failed() {
  printf '{\n'
  printf '  "schema_version": 1,\n'
  printf '  "command": "selection-diff",\n'
  printf '  "check": true,\n'
  printf '  "applied": false,\n'
  printf '  "outcome": "failed",\n'
  printf '  "exit_code": 1,\n'
  printf '  "error": %s\n' "$(_sd_js "${SD_ERROR:-the selection diff failed}")"
  printf '}\n'
}

# ── entry points ────────────────────────────────────────────────────────────

# selection_diff_main: collect, classify, render. Returns the exit code.
selection_diff_main() {
  if ! selection_diff_collect; then
    [[ "${JSON_OUT:-0}" == 1 ]] && selection_diff_render_failed
    return 1
  fi
  selection_diff_outcome
  if [[ "${JSON_OUT:-0}" == 1 ]]; then selection_diff_render_json; else selection_diff_render_text; fi
  return "$SD_EXIT"
}

# selection_diff_run: selection_diff_main in a private work dir. Call it in a
# subshell: its EXIT trap removes the directory on every way out, including a
# signal, and the caller's own traps are not touched.
selection_diff_run() {
  SELECTION_WORK="$(mktemp -d)" || { _sd_err "cannot create a temporary directory"; exit 1; }
  trap 'rm -rf -- "$SELECTION_WORK"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap 'exit 129' HUP
  trap 'exit 131' QUIT
  trap 'exit 141' PIPE
  selection_diff_main
  exit $?
}
