Source: local

# T-0043: sys-update --selection-diff: a read-only diff of the selection (feature)

Status: open (T1 to T7 implemented on feat/selection-diff, not merged; human checks pending: macOS run, a real bash 3.2 run of the install path, a real apply that writes the record)
Wave: unassigned
Depends on: T-0042 (the selection, its facts and the preview it shares code with)

## Summary
`sys-update --selection-diff` answers one question without changing anything:
what would the next `sys-update --apply` add, remove or change, given the
committed profile and this machine's local selection? It compares the declared
state with the installed one, lists the result by operation (REMOVE first), and
exits with a code a script can act on. A second deliverable makes the answer
explain itself: an applied-state record, written after a successful apply, that
lets the diff say why something is pending (the selection changed or the repo
changed). The `generation_changed_outside` cause is `no` when the record is ok and
`unknown` otherwise; it exists to keep the envelope shape stable.

## Decision
Design by the architect, with the user's decisions on the open points; where they
differ, the user's decisions win.

User decisions
- `--selection-diff` always overrides `--apply`, whatever the argument order, as
  `rollback` already does, because both wrappers (the bash command and the fish
  function) prepend `--apply`. The diff is strictly read-only: no pull, re-exec,
  install, switch, cleanup, `ui_init`, state-directory creation or state write.
  It never takes, waits for or probes the update lock (`lock_is_held` briefly takes
  it, so it is not used), and never recovers an interrupted run.
- New exit codes, not colliding with the existing ones: 0 in sync; 1 execution
  failure (nix missing, the declared state does not evaluate, an internal error);
  2 invalid arguments; 3 to 5 the existing reserved codes, unchanged; 10 changes
  pending (any add, remove or change); 11 manual action required (any conflict,
  any unknown source, an unfinished or failed last run). Precedence 1, 11, 10, 0.
  Documented in `--help` and the header comment.
- An absent, invalid or stale applied-state record gives an explicit `unknown`
  status for the causes, never a false "in sync" for the attribution; the diff
  works without the record.
- Deselected Homebrew casks that stay installed (cleanup = none) are reported as
  manual (`remove by hand: brew uninstall --cask X`) and do not count towards the
  exit code.
- `install.sh` also writes the record, after its switch succeeds and never on a
  dry run. Both writers write atomically, and only after a successful apply (and
  the verification, in update-all).
- `--json` lists changed items only; unchanged items appear as counts. One
  envelope on stdout, stable key order, entries sorted with `LC_ALL=C`,
  diagnostics on stderr only. Valid only with `--selection-diff` (else exit 2).
- Tests for both wrappers (the bash command and the fish function) show that
  `sys-update --selection-diff` with the prepended `--apply` runs the diff.

Architect design (as built)
- Facts out of the preview: ops/lib/selection-facts.sh holds what the preview and
  the diff share (profiles and groups, the evaluation, the installed generation,
  the file and package comparison, `_sel_chezmoi_status`); it is bash 3.2 safe and
  defines functions and variables only. selection-preview.sh keeps the prompts,
  the preview, the write and the validation.
- ops/lib/selection-diff.sh holds the classifier, the outcome and both renderers;
  only update-all.sh sources it, and it never reads input.
- Three sources, each ok, unknown or n/a: selected (the local file, profile and
  group values with their origin), declared (strict evaluation with
  `--no-write-lock-file`, through a facts variable only the diff sets), installed
  (Home Manager generation, `chezmoi status`, on macOS `brew list --cask`); plus
  the run state (last-run and its record, read with sed).
- The classifier is awk over text into one TSV (kind, name, operation, action,
  from, to, group, by_apply). chezmoi columns X and Y: blank and A, M, D, R are add,
  change, remove, change (script); X set and Y blank is keep; both set is a conflict.
- Applied-state record v1 (ops/lib/install-record.sh): eleven `key=value` lines in
  a fixed order under the app-configs state directory; the selection is stored as
  a sha256, never as content. The reader answers ok, absent, invalid or stale.

Deviations from the design, and why
- A failure before the facts exist (nix missing, an evaluation error, an internal
  step failing) prints nothing on stdout in text mode; the reason and the Nix error
  go to stderr, so the design's `RESULT: FAILED (exit N)` line is not printed. With
  `--json` a minimal envelope (outcome `failed`, exit_code 1, error) is printed.
- Unknown sources are entries (kind packages, hm_files, chezmoi or casks, name
  `(all)`), so the UNKNOWN section and `counts.unknown` count them one by one.
- The unfinished or failed last run is an entry of kind run (operation manual) and
  also forces exit 11; the manual casks do not.
- `repo.dirty` is `yes`, `no` or `unknown` in both the JSON and the record (the
  record schema had not shipped, so it was aligned rather than translated).
- `repo_changed` is `no` only for a clean tree at the same revision on both sides;
  dirty on both is `unknown`; clean against dirty is `yes`. An unhashable selection
  file makes `selection_changed` `unknown`.
- A tab in a path is shown as a literal `\t` in entries, so a path can never break
  the row format or the JSON; `by_apply` is printed as true only when exactly true.
- The steps that build the entries (classifiers, unknown-source and unsupported-group
  appends, the last-run entries, the sort) fail closed: a failed write or awk is exit
  1. Independently, any source that is unknown forces exit 11, even if its entry
  could not be recorded. The rendering, the repo facts and the record read are not
  separately guarded; they only print or fall back to unknown.

Per-check states (user decision after review)
- Components packages, hm_files, chezmoi, casks, run and record each have a state:
  in_sync, pending, unknown (missing information) or error (unexpected failure);
  casks are not_applicable off macOS. Unknown is never pending, in sync or empty.
- Exit codes are unchanged; 11 now also covers an incomplete assessment. The JSON has
  `complete` and a `checks` object with a structured `reason` per component (it
  replaces `sources`); verified counts survive one unknown component.
- One function decides machine-data availability (missing, unreadable, available) by
  -e/-L/-f/-r only and never opens home/.chezmoidata/personal.yaml. A present file with a
  failing chezmoi is `error` with a fixed class, never the raw message. No placeholder
  data, no fallback to another checkout, no private values in output.
- Isolated tests generate dummy machine data in the fake repo; the real checkout
  can return exit 0 (to be proven after merge, on main). A first install (no
  generation) is pending with reason no_generation, since the comparison is complete.

## Owned files (write boundary)
- ops/lib/selection-facts.sh (new), ops/lib/selection-diff.sh (new), ops/lib/install-record.sh (new)
- ops/lib/selection-preview.sh (the facts moved out), ops/lib/selection.sh (a comment)
- ops/update-all.sh (flags, help and header, the dispatch, the record write after the commit phase)
- ops/install.sh (sourcing, the record write after the switch)
- ops/lint-shell.sh (the three new files in the curated list)
- tests/bash/selection-diff.bats, tests/bash/install-record.bats (new)
- tests/bash/install-selection.bats, tests/bash/hm-switch.bats, tests/bash/portable-bash.bats,
  tests/bash/selection.bats, tests/bash/update-all-apply.bats (guards, sourcing, record tests)
- tests/bash/fixtures/selection/stubs/git (new), tests/bash/fixtures/selection/stubs/brew (a
  failure switch), tests/bash/fixtures/selection/state/work-noinput.tsv (new),
  tests/bash/fixtures/selection-diff/expected.json (new)
- docs/getting-started/install.md, docs/architecture/tool-ownership.md,
  docs/work/index.md (row), docs/work/active/T-0043-selection-diff/** (this ticket, the evidence)

## Findings
- VERIFIED (evidence/t1-spike.md): `chezmoi status` leaves chezmoistate.boltdb
  byte-identical; while another chezmoi holds the database it fails after about 1 s
  with a lock timeout (exit 1), so the diff reports the source as unknown.
- VERIFIED (evidence/t1-spike.md): `--no-write-lock-file` keeps flake.lock untouched
  where a plain `nix eval` would create it.
- VERIFIED: the diff's two evaluations take about 27 s on this linux-desktop host
  (19 s group members, 8 s current state), over the roughly 20 s the design allowed.
  Recorded, not trimmed; see Open questions.
- VERIFIED: `sha256sum FILE` prefixes a backslash to the hash when FILE holds one
  (found by the golden test with a backslash in the path); the hash is therefore
  taken from stdin, in the diff and in the record.
- VERIFIED: in a git worktree the gitignored per-host chezmoi data is absent, so
  `chezmoi status` fails there and the diff reports chezmoi as unknown (exit 11);
  run from the main checkout it reads the real data.

## Acceptance criteria
- AC1: the facts split is behaviour preserving: install-selection, hm-switch,
  portable-bash and selection bats stay green, and seeded tests catch a facts call
  or a source of selection-facts.sh, selection-diff.sh or install-record.sh from
  another script.
- AC2: the diff is read-only: a hash tree of the repo (with .git), the state,
  selection and record directories is identical before and after, no `./result`,
  no temp directory left, no directory created when none existed.
- AC3: the exit matrix holds: in sync 0; add, remove or change 10 with REMOVE
  first; a chezmoi `MM` conflict 11; an unreadable installed generation 11; a
  failing brew 11; a failing chezmoi 11; an evaluation failure 1; a conflict plus
  an add 11; an evaluation failure plus anything 1.
- AC4: `--apply --selection-diff` and `--selection-diff --apply` run the diff and
  create no lock or state; `--json` alone, and `rollback`, `--force`, `--gc`,
  `--allow-dirty`, `--skip-verify`, `--full-check` or `--no-cleanup` with the diff
  exit 2; `--yes`, `--no-pull`, `--verbose` are accepted.
- AC5: it does not lock and does not prompt: a held sys-update lock does not block
  it, and a stdin nobody writes to is never read; the stub log shows evaluation and
  status only (no build, switch, apply, commit, pull or install).
- AC6: unknown is never shown as an unchanged count (the installed generation
  unknown gives `Packages: unknown`, `keep` 0 and an unknown entry per source).
- AC7: `--json` is exactly the golden envelope for a path with a space, a quote
  and a backslash, stdout holds only JSON, keys are in the specified order, entries
  are sorted, unchanged items are counts, control characters are escaped.
- AC8: a section lists 30 entries and then `and N more` (45 entries give `and 15
  more`), with the full count in its header.
- AC9: deselected casks that stay installed are MANUAL and do not change the exit
  code (0 when nothing else is pending, 10 beside an add).
- AC10: both wrappers: the bash `sys-update` and the fish `sys-update` still prepend
  `--apply`, and `sys-update --selection-diff` through each runs the diff, not an apply.
- AC11: the record is written by update-all after the commit phase of a successful
  apply and by install after a successful switch; never on a dry run, in report mode
  or after a failed apply or switch; atomically (no temp file left); exact bytes in a
  fixed order; the selection as a sha256 only; a failed write warns and never fails
  the apply.
- AC12: the reader returns ok, absent, invalid (unknown, duplicate or missing key,
  wrong order, schema other than 1, bad value, CRLF, not a file) or stale; the diff
  fills the causes and `applied_selection` from an ok record and reports unknown
  otherwise, still working.
- AC13: install.md documents the flags, the exit codes, the JSON summary and the
  record, with a pointer from the selection section; tool-ownership.md records the
  new owners.
- AC14: the full bats suite, lint-shell, validate-config, `nix flake check ./nix`
  and ci-local pass, and nix/flake.lock is unchanged.

## Plan
- [x] T1 spike: chezmoi status read-only and lock behaviour, `--no-write-lock-file`, eval time (evidence/t1-spike.md)
- [x] T2 facts split and guards, behaviour preserving
- [x] T3 the failing selection-diff suite, fixtures and golden envelope
- [x] T4 selection-diff.sh, the update-all flags, help, exit codes and dispatch; real read-only runs on this host
- [x] T5 the failing install-record suite
- [x] T6 install-record.sh, the two write points, the diff reading the record
- [x] T7 documentation, this ticket and the index row

## Verification
See evidence/verification.md for the commands, their scope and results.

## Open questions
- Eval time: about 27 s here, over the 20 s target. The group-members evaluation is
  the cost (it extends the host configuration five times). Options: leave it, cache
  the members by the committed-state hash, or evaluate them only for the by-group
  section. The user decides.
- macOS is unverified: the cask logic, the darwin-system record kind and the
  `brew list --cask` source are covered by stubs only.
- Future option for the eval time: expose group membership as a cheap Nix
  attribute so one evaluation is enough (the members evaluation is the 19 s part).
  Accepted as is for now.
- Whether `sys-update` (the apply) should print the diff summary before it
  confirms is out of scope here.
