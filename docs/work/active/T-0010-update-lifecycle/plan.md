# T-0010 update-all lifecycle, locking and rollback: execution plan

- **Status:** draft
- **Work id:** T-0010-update-lifecycle (`Source: local` in `ticket.md`)
- **Branch:** none cut yet. Base is `main`. The implementer's branch name is unknown and will be recorded here when it is created.
- **Designed against:** unknown. The handed design (revision 3) does not record a commit. For reference only, the main worktree HEAD observed while this plan was written was `b6f2969` at the first check and `2f21a95` at the read-back (another session committed in between); neither is asserted to be the design commit.
- **Date:** 2026-11-14

## Context

`docs/work/active/T-0010-update-lifecycle/ticket.md` records that `ops/update-all.sh` has rollback, locking and ordering defects, and that an architect decides the scope (prepare/activate/maintain split) before implementation.

- **Design status:** accepted. Architect revision 3 passed independent design review (round 3, PASS WITH NOTES). Implementation has not started.
- **Base:** `main`, after T-0002, T-0003, T-0011, T-0012 and T-0013 land. When this plan was written all five were recorded as `Status: open` in their tickets, so their landing is unverified.
- **Shape:** one implementer, tests first. Gate A (T0–T2) must be committed and independently reviewed before Gate B (T3–T7) starts.
- **Findings:** the ticket's findings are external audit claims, unverified until reproduced. Reject false positives with evidence. The mapping from findings F1–F23 to scenarios is under Notes.

## Decision

The design below is recorded from architect revision 3 and the reviewer's notes. Wording is normalised, not redesigned.

Rejected alternatives: unknown (not recorded in the handed design).
Decision records that govern this work: none given.

### Phase order

read and unset env (`SYS_UPDATE_REEXEC`, `SYS_UPDATE_RUN_ID`, `SYS_UPDATE_PULLED_FROM`) → traps (EXIT on_exit, INT exit 130, TERM exit 143) → parse args → lock → PRECHECK → confirm → pull (if HEAD moved: exec child) → SNAPSHOT (+ GC root) → PREPARE → ACTIVATE → VERIFY (gate) → COMMIT → MAINTAIN → CHECKS (advisory) → CLEANUP → SUMMARY

- Statuses: `started` (SNAPSHOT), `prepared`, `activating` (before chezmoi apply), `activated`, `verified` | `verify-skipped`, `committed` | `commit-skipped` | `commit-failed`, `done`. A failure is recorded as `failed:<phase>` plus `exit_code`.
- `--help` keeps PRECHECK, VERIFY, rollback and the exit codes.
- Exit codes: 0 ok; 1 failure or incomplete rollback; 2 usage; 3 bats HOME guard; 4 host detection failed; 5 lock held; 130/143 interrupted.

### 1. Lock

- **flock mode** (when `flock` is on PATH and `/proc/self/fd` exists): `exec 9>"$STATE_DIR/lock"; flock -n 9 || exit 5`. Never unlink the lock file. The refusal shows lsof/fuser holders and never an rm command. Step commands go through `run_step` = `ui_run "$@" 9>&-`, which replaces all `ui_run` calls. The update-ui lib is not edited.
- **mkdir mode** (macOS, or no flock): `mkdir lock.d` plus an atomic owner file (`pid run_id`). A mkdir failure means held, including a missing or unparseable owner. The refusal prints the owner, `ps -p PID -o command=` with a pid-reuse note, and the exact `rm -rf` command; exit 5. Never auto-reclaim. EXIT removes the lock only if owner == `$$` + RUN_ID. Test seam: `SYS_UPDATE_FORCE_MKDIR_LOCK=1`.
- Report mode takes no lock (an info line if the lock is held). Rollback takes the lock.

### 2. Adoption

- flock mode: `flock -n 9` AND `[[ /proc/$$/fd/9 -ef "$LOCK_FILE" ]]`. mkdir mode: owner == `$$` + `SYS_UPDATE_RUN_ID`. Otherwise a fresh run.
- Adopted child: `ui_init "" "$VERBOSE"`, then `UI_LOG="$RUN_LOG"` (append, no truncation).

### 3. Metadata, run id, statuses, pruning

- `RUN_ID=<UTC ts>-$$`.
- `meta_put` returns its write status. SNAPSHOT failures exit 1 before PREPARE.
- Last-run pointer is written via temp file + mv, after run_id, host, hm_profile, hm_path_before, hm_gen_before (numeric only), lock_was_clean, backups, gcroot and `status=started` are recorded.
- The T-0003 call `meta_put snapshot_dir` gains a status check only.
- Pruning (KEEP_RUNS): remove `"$RUN_DIR/$id".*` and `$STATE_DIR/gcroots/$id`. Roots are also removed after KEEP_DAYS (14). Never prune last-run's run.

### 4. Host detection, paths, HM profile

- Always run `detect-host.sh` with stderr shown. Non-zero exit → exit 4.
- HM_PROFILE follows the HM activate rule:
  - `${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles` if that directory exists;
  - else `${NIX_STATE_DIR:-/nix/var/nix}/profiles/per-user/${USER:-$(id -un)}` if that directory exists;
  - else a precheck failure (non-macOS apply) or a warning.
  - The profile is `<dir>/home-manager`, recorded as `hm_profile`.
- F23: HM count `grep -cvFx "$UVR_EMPTY_SET"` once T-0024 is on main; otherwise leave it and note.

### 5. PRECHECK

- `GIT_STATE=error` → fail.
- `git_upstream`: 0 with empty output = no upstream (pull disabled); 1 = unresolvable (apply fails, report warns); 2 = not a repo.
- `chezmoi status` failure → apply fails, report warns.
- EXIT calls `ui_cleanup`.
- These contracts depend on T-0011.

### 6. Pull and re-exec

- Runs after PRECHECK and confirm. Skipped with `--no-pull` or the child flag.
- If HEAD moved: `shopt -s execfail; exec env SYS_UPDATE_REEXEC=1 SYS_UPDATE_RUN_ID="$RUN_ID" SYS_UPDATE_PULLED_FROM="$old" bash "$REPO_ROOT/ops/update-all.sh" "${ORIG_ARGS[@]}" --no-pull --yes`. An exec failure → exit 1.
- Cross-version contract (recorded in the script header):
  - the child accepts `--no-pull --yes` and the three env vars;
  - the child never pulls when `SYS_UPDATE_REEXEC=1`;
  - the child adopts the lock as in item 2;
  - the child appends to the log;
  - the child exits 2 before any change on invalid args.

### 7. PREPARE and ACTIVATE

- PREPARE: a second `nix build --no-link --print-out-paths` is fail-closed (non-zero exit, empty output or missing directory is a failure) and sets BUILD_OUT.
- PREPARE: hash after each writer, even on failure, using `git hash-object`:
  - `flake_lock_hash_written` after `nix flake update`;
  - `brave_release_hash_written` after `update-brave.sh`.
- ACTIVATE: after the switch, `readlink -f HM_PROFILE` (Linux) or `${SYS_UPDATE_DARWIN_SYSTEM_LINK:-/run/current-system}` (macOS) must equal BUILD_OUT. This check is not skippable.
- A switch failure message reports whether the profile moved.

### 8. EXIT handler `on_exit` (phase-driven, idempotent)

- precheck and pull: nothing to restore.
- snapshot: `failed:snapshot`.
- prepare: restore locks, `failed:prepare`.
- activate: `failed:activate`, restore, rollback hint.
- verify: `failed:verify`, keep locks, print both choices (see item 10).
- later phases: warnings only.
- Always: `ui_cleanup`, set `exit_code`, remove the owned mkdir lock.
- **REVIEW NOTE R3-01 (must fix):** kill background jobs first: `kill $(jobs -p) 2>/dev/null; wait 2>/dev/null`. The `_ui_progress` ticker is a forked subshell that inherits the saved fd copy and survives SIGINT. It would hold the flock and cause exit 5 on the next run.

### 9. Restore guard

- If the file equals the backup (`cmp`): nothing to do.
- If a hash was recorded and the current file matches it: restore.
- If no hash was recorded: restore only if `lock_was_clean=1`.
- Otherwise: keep the file and warn.
- Restore by copying to `<file>.tmp.$$` then `mv -f`. Keep a `.failed` copy.
- Rollback uses the same guard.
- Wording (review note 6): the safety of this guard rests on the `.failed` copy, because other agent sessions may edit the repo concurrently. It does not rest on the sys-update lock.

### 10. VERIFY gate

- **Hard checks:**
  - the profile-target check (in ACTIVATE, item 7);
  - on linux-desktop, `brave --version` runs;
  - the Brave MIME mapping for `x-scheme-handler/http`, `x-scheme-handler/https`, `text/html` and `application/pdf` equals `brave-browser.desktop`, **whenever the query can run**. This is an orchestrator decision. `default-apps.nix:135-137` re-applies declared mappings; see `docs/reference/default-apps.md:14-17` and commit `cb8dba0`.
- **Advisory only** when `xdg-mime` is missing, any query result is empty, or there is no graphical session (`WAYLAND_DISPLAY` and `DISPLAY` empty, and `XDG_SESSION_TYPE` empty or `tty`).
- On a hard MIME failure, mention the desktop-specific `~/.config/*-mimeapps.list` precedence.
- `--skip-verify` skips the gate (not the profile check) and CHECKS. The run commits with `verify-skipped`.
- `failed:verify` prints either `sys-update rollback` or `git -C <repo> commit --only -m "chore(nix): update flake inputs" -- <files>`.

### 11. GC root

- In SNAPSHOT, when HM_PATH_BEFORE is non-empty: `nix-store --realise "$HM_PATH_BEFORE" --add-root "$STATE_DIR/gcroots/$RUN_ID/hm"` (no `--indirect`). A failure exits 1 before any change. An empty HM_PATH_BEFORE → `gcroot=none`.
- macOS also roots `/run/current-system` as the darwin root.
- Cleanup receives `--protect-hm-generation "$HM_GEN_BEFORE"` only if the value matches `^[0-9]+$`.
- After cleanup: if `$HM_PATH_BEFORE/activate` is missing → warn and set `rollback_handle=lost`.
- Caveat: moving `SYS_UPDATE_STATE_DIR` leaves the roots dangling.
- Rollback window: last-run's pre-update closure survives `nix-gc.timer`, `sys-cleanup --gc` and `nix-collect-garbage` while it remains last-run. Earlier roots survive until KEEP_RUNS (20) or 14 days.
- Not guaranteed: the generation number; darwin automated rollback; a moved or deleted STATE_DIR; `--ignore-liveness`.

### 12. Rollback

- Take the lock. Read host and hm_profile from metadata. Use detect-host only for old metadata without them; a detection failure exits 4.
- Status table:
  - `none` → today's behaviour plus checks;
  - `started`, `failed:snapshot`, `failed:prepare` → guarded lock restore, print "nothing to roll back", exit 0;
  - `prepared`, `activating`, `activated`, `verified`, `verify-skipped`, `failed:activate`, `failed:verify`, `committed*`, `done` → full rollback ("already on target" if nothing changed).
- Linux full rollback:
  1. If the profile is already on target, report it.
  2. Otherwise run `$hm_path/activate`.
  3. If still not on target, run `nix-env --profile "$hm_profile" --set "$hm_path"` and recheck.
  4. If still not on target, exit 1.
  5. Then the guarded lock restore.
  6. If the locks differ from HEAD, print the git revert/checkout choices.
- macOS: restore the locks, print the rooted darwin path and the manual step, exit 1.
- Append `status=rolled-back` to the run record.

### 13. Lefthook

- `sh -c 'cd "$1" && lefthook install' sh "$REPO_ROOT"`, run via `run_step`.

### 14. Docs (boundary extension, approved by orchestrator)

- `README.md` lines 31, 122, 126–127, 150–153.
- `docs/getting-started/install.md` lines 173–183 and 243–250.

## Acceptance criteria

The ticket lists five acceptance criteria without ids. No ids have been invented for them. Ids are `unassigned` until the designer or coordinator gives them.

- [ ] Ticket criterion (id unassigned): each finding is reproduced by a failing bats or unit test, or recorded as a false positive with evidence.
- [ ] Ticket criterion (id unassigned): the fix is applied, and the regression test fails on the old code and passes on the new.
- [ ] Ticket criterion (id unassigned): the affected bats files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (for nix changes) pass.
- [ ] Ticket criterion (id unassigned): independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- [ ] Ticket criterion (id unassigned): architect design recorded before implementation. The design passed review (round 3); this plan records it. Not ticked: no evidence has been reported for implementation.

The verification scenarios below are the design's test scenarios. Each is recorded with its id. Scenario descriptions are given only where the handed design gives them; otherwise the line says so. No scenario is renumbered.

Lock:
- [ ] S01: flock holder → exit 5, no rm hint.
- [ ] S02: lock is free after a failure; the lock file is kept.
- [ ] S03: mkdir mode, live non-sys-update owner → refused, with the `rm -rf` command and a pid-reuse note.
- [ ] S04: owner-less lock directory → held.
- [ ] S05: only the owner removes the mkdir lock.
- [ ] S48: a step sees no fd 9 while the lock is still held. Must also cover the `_ui_progress` ticker after SIGINT under a pseudo-TTY (`script -qec …`), and assert that `flock -n "$LOCK_FILE" true` succeeds afterwards.

Metadata:
- [ ] S06: description not given in the handed design (finding F5).
- [ ] S07: description not given in the handed design (finding F7).
- [ ] S08: description not given in the handed design (finding F6).
- [ ] S09: description not given in the handed design (finding F6).

Host and XDG:
- [ ] S10: description not given in the handed design (finding F15; preflight).
- [ ] S11: description not given in the handed design (finding F15; preflight).
- [ ] S12: description not given in the handed design (finding F16).
- [ ] S51: description not given in the handed design (finding F23).

PREPARE:
- [ ] S13: description not given in the handed design (finding F8).
- [ ] S14: description not given in the handed design (finding F8).
- [ ] S15: description not given in the handed design (finding F9).
- [ ] S16: description not given in the handed design (finding F22).
- [ ] S17: description not given in the handed design (finding F22).

ACTIVATE:
- [ ] S18: description not given in the handed design (finding F3).
- [ ] S19: description not given in the handed design (finding F3).
- [ ] S20: description not given in the handed design (finding F3).

Restore:
- [ ] S21: description not given in the handed design (finding F11).
- [ ] S22: description not given in the handed design (finding F11).
- [ ] S23: description not given in the handed design (finding F11).
- [ ] S49: description not given in the handed design.
- [ ] S50: description not given in the handed design.

VERIFY:
- [ ] S24: description not given in the handed design (findings F10, F20).
- [ ] S25a: description not given in the handed design (finding F20). Environment pinning and mimeapps precedence hint apply (see Notes).
- [ ] S25b: description not given in the handed design (finding F20). Same pinning and hint note.
- [ ] S25c: description not given in the handed design (finding F20). Same pinning and hint note.
- [ ] S26: description not given in the handed design.
- [ ] S27: description not given in the handed design (finding F21; finding F10 for the group). Pin `DISPLAY`, `WAYLAND_DISPLAY`, `XDG_SESSION_TYPE`, `XDG_CURRENT_DESKTOP`.

Re-exec:
- [ ] S28: description not given in the handed design (finding F14).
- [ ] S29: description not given in the handed design (finding F14).
- [ ] S30: description not given in the handed design (finding F14).

Rollback:
- [ ] S32: description not given in the handed design (finding F1; a conditional false positive).
- [ ] S33: description not given in the handed design (finding F1; a conditional false positive).
- [ ] S34: description not given in the handed design (finding F1; a conditional false positive).
- [ ] S35b: description not given in the handed design.
- [ ] S36: description not given in the handed design (finding F12, accepted).
- [ ] S37: description not given in the handed design (finding F2).
- [ ] S38: description not given in the handed design (finding F4).
- [ ] S39: description not given in the handed design.
- [ ] S40: description not given in the handed design.

Cleanup and GC:
- [ ] S41: description not given in the handed design (finding F18).
- [ ] S41b: description not given in the handed design.
- [ ] S42: description not given in the handed design (finding F18).
- [ ] S43: description not given in the handed design (finding F18).
- [ ] S44: description not given in the handed design (finding F18).

Pruning, lefthook and help:
- [ ] S45: description not given in the handed design. Pruning. Without roots in T1; with roots in T6.
- [ ] S46: description not given in the handed design (finding F17). Lefthook.
- [ ] S47: description not given in the handed design. Help.

Scenario S31 is not in the handed design. See Notes.

## Tasks

Sequence as stated in the design: T0, T1, T2, Gate A review, T3, T4, T5, T6, T7, Gate B review. One implementer. Every task in the plan changes `ops/update-all.sh`, so no two tasks run in parallel. Per-task fields that the handed design does not give are recorded as `unknown`. Dependencies are the stated sequence plus the prerequisite tickets, and nothing else.

- [ ] **T0 Test fixtures** (update-all-apply.bats setup)
  - Files: `tests/bash/update-all-apply.bats` (setup only). Any other files: unknown.
  - Content:
    - `nix build --print-out-paths` prints `${STUB_HM_OUT:-$BATS_TEST_TMPDIR/hm-out}`. Switches: `STUB_HM_OUT_EMPTY`, `FAIL_PRINT_OUT`.
    - `home-manager switch` relinks the profile unless `STUB_HM_NO_RELINK=1`.
    - `GEN_DIR/activate` relinks unless `STUB_ACTIVATE_NO_RELINK=1`.
    - Stub `nix-store`: `--add-root` creates the link; `-q` prints nothing; `FAIL_GCROOT`.
    - Stub `nix-env --set` relinks.
    - Stub `xdg-mime` prints `$STUB_MIME`; `STUB_MIME_EMPTY` makes it empty.
    - Stub `brave`: `FAIL_BRAVE`.
    - `CHEZMOI_STATUS_FAIL`, `STUB_TOUCH_LOCK`, `STUB_TERM_AFTER_UPDATE`.
    - No existing assertion is weakened.
  - Dependencies: base prerequisites; first in sequence.
  - Criteria covered: not mapped in the handed design. The fixtures support the scenarios in T1–T6.
  - Risk: unknown.
  - Review: Gate A.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **T1 Lock, run id, metadata, statuses, pruning**
  - Design items: 1 (lock, including `run_step` replacing `ui_run`), 3 (run id, checked metadata, atomic last-run, statuses, pruning without roots). Rollback taking the lock belongs to T5.
  - Files: `ops/update-all.sh`; `tests/bash/update-all-*.bats`.
  - Criteria covered: S01–S09, S45 (without roots), S48.
  - Dependencies: T0; base prerequisites.
  - Risk: unknown. See R3-01 and implementer note 2 under Notes.
  - Review: Gate A.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **T2 Host detection, HM_PROFILE, PRECHECK contracts, PREPARE gaps, lefthook, exit codes**
  - Design items: 4 (host, paths, F23), 5 (PRECHECK contracts), 7 (PREPARE part: fail-closed second build, hashes after writers), 13 (lefthook), exit codes in the header and `--help`.
  - Files: `ops/update-all.sh`; `tests/bash/update-all-*.bats`.
  - Criteria covered: S10–S17, S46, S47, S51.
  - Dependencies: T0; base prerequisites; T-0011 (PRECHECK contracts, as stated); T-0024 only for the F23 change, and only if it is on main (conditional).
  - Risk: unknown.
  - Review: Gate A.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **Gate A review (T0–T2)**
  - Independent review. Gate A is committed before Gate B starts.
  - Review verdict and evidence recorded in the Progress log when reported.

- [ ] **T3 Phase reorder, `activating` status, EXIT handler, restore guard, profile-target check, VERIFY gate, `--skip-verify`**
  - Design items: the phase order and the `activating` status; 7 (ACTIVATE: profile-target check, and a switch failure message that says whether the profile moved); 8 (EXIT handler, including R3-01); 9 (restore guard); 10 (VERIFY gate, `--skip-verify`, `failed:verify` messages).
  - Files: `ops/update-all.sh`; `tests/bash/update-all-apply.bats` and `tests/bash/update-all-*.bats`.
  - Criteria covered: S18–S27, S49, S50.
  - Dependencies: Gate A committed and reviewed. The INT and TERM trap placement is not stated; see Open questions.
  - Risk: unknown. R3-01 is a must-fix.
  - Review: Gate B.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **T4 Re-exec, adoption, log append**
  - Design items: 2 (adoption, which depends on item 1), 6 (pull and re-exec, with the cross-version contract).
  - Files: `ops/update-all.sh`; `tests/bash/update-all-*.bats`.
  - Criteria covered: S28–S30.
  - Dependencies: T3 (sequence); T1 (lock modes).
  - Risk: unknown. Implementer note 5 applies.
  - Review: Gate B.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **T5 Rollback**
  - Design items: 12 (rollback), with its lock (item 1) and guarded restore (item 9).
  - Files: `ops/update-all.sh`; `tests/bash/update-all-*.bats`.
  - Criteria covered: S32–S40, S35b.
  - Dependencies: T3 (sequence).
  - Risk: unknown.
  - Review: Gate B.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **T6 GC roots, protect flag, lost handle, root pruning**
  - Design items: 11 (GC root, protect flag, `rollback_handle=lost`, the caveats), and root pruning from item 3 (roots removed after KEEP_DAYS, 14).
  - Files: `ops/update-all.sh`; `tests/bash/update-all-*.bats`.
  - Criteria covered: S41–S45 (S45 with roots), S41b.
  - Dependencies: T3 (sequence). Implementer note 4 applies: never create real GC roots or state in tests.
  - Risk: unknown.
  - Review: Gate B.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **T7 Docs**
  - Design item: 14.
  - Files: `README.md` (lines 31, 122, 126–127, 150–153); `docs/getting-started/install.md` (lines 173–183, 243–250). These files are outside the ticket's owned-file pattern; the boundary extension was approved by the orchestrator.
  - Criteria covered: not mapped in the handed design.
  - Dependencies: T3–T6 (sequence).
  - Risk: unknown.
  - Review: Gate B.
  - Done: unknown.
  - Verifying command: unknown per task. See Verification.

- [ ] **Gate B review (T3–T7)**
  - Independent review. The ticket requires PASS.
  - Review verdict and evidence recorded in the Progress log when reported.

## Verification

Commands recorded from the design:

- `bats tests/bash/update-all-apply.bats tests/bash/update-all-preflight.bats tests/bash/update-ui.bats tests/bash/update-facts.bats tests/bash/cleanup.bats`
- `bash ops/lint-shell.sh`
- `bash ops/update-all.sh` (report mode)
- `nix flake check ./nix`

Human verification (a person is needed):

- One real `--apply`, then a rollback, on Linux.
- macOS is unverified.

Report implementation and verification separately, with the exact checks, scope, results and checks not run.

## Notes

### Open questions

1. **S31 is missing.** The handed scenario list runs S01–S51, but S31 appears in no group, no finding mapping and no task. It has not been renumbered. The designer is asked to confirm whether it was dropped or is intentionally unused.
2. **Scenario descriptions.** Only S01–S05 and S48 carry descriptions in the handed design. The other ids are recorded by id, with the finding mapping and notes where the design gave them.
3. **Per-task fields.** Files beyond the ones named above, dependencies beyond the stated sequence, risk, review beyond the gates, done definitions and per-task verifying commands are all `unknown` in the handed design.
4. **Design commit and rejected alternatives** are `unknown`.
5. **Acceptance criterion ids.** The ticket's five criteria have no ids. None were invented.
6. **INT and TERM traps.** The phase order includes them (exit 130 and exit 143), but the handed design does not assign them to a task. Assignment is open; T3 with the EXIT handler is the likely home, to be confirmed.
7. **AGENTS.md checks.** The repository rule for build-affecting changes to `ops/*.sh` lists more checks than the design's list: `nix build --no-link` of the activation package, `chezmoi diff`, and `bash ops/update-all.sh` in report mode, plus pre-commit hooks. The design's verification list does not include the first two. Whether they are required for this work is unknown.
8. **Prerequisites.** T-0002, T-0003, T-0011, T-0012 and T-0013 were all `Status: open` in their tickets when this plan was written. Their landing is unverified.
9. **T-0024** is `Status: open`. The F23 change depends on it, conditionally.
10. **Owned files.** The ticket owns `ops/update-all.sh` and `tests/bash/update-all-*.bats`. The design also touches `README.md` and `docs/getting-started/install.md` (orchestrator-approved). The verification list also runs `update-ui.bats`, `update-facts.bats` and `cleanup.bats`, which the handed design does not assign any edits to.

### Risks

- R3-01 is a must-fix in T3 (see design item 8).
- The restore guard's safety rests on the `.failed` copy, not on the sys-update lock (design item 9).
- Adoption relies on `ui_init ""` not truncating the log. Recheck if update-ui changes.
- The GC rollback window is not guaranteed in the cases listed under design item 11.
- macOS is unverified. There is no darwin automated rollback (FU1).
- The hard MIME gate can fail because of user-level `mimeapps.list` precedence. A failure must name that cause (design item 10).
- The `_ui_progress` ticker can print after Ctrl-C (T-0011 follow-up). S48 covers the lock side.
- Tests must never use real GC roots or real state (implementer note 4).

### Findings to scenarios

The design's mapping, as recorded:

- F1 → S32–S34 (conditional false positive)
- F2 → S37
- F3 → S18–S20
- F4 → S01–S05, S38, S48
- F5 → S06
- F6 → S08, S09
- F7 → S07
- F8 → S13, S14
- F9 → S15
- F10 → S24–S27
- F11 → S21–S23, S49, S50
- F12 → S36 (accepted)
- F13 → FU2
- F14 → S28–S30
- F15 → S10, S11
- F16 → S12
- F17 → S46
- F18 → S41–S44
- F19 → T-0003
- F20 → S24, S25a–c
- F21 → S27
- F22 → S16, S17
- F23 → S51

### Decisions recorded along the way

- The MIME query is a hard gate whenever it can run. This is an orchestrator decision (design item 10).
- The docs boundary extension to `README.md` and `docs/getting-started/install.md` was approved by the orchestrator (design item 14).
- Design review round 3: PASS WITH NOTES. The notes are folded into this plan as recorded below.
- The follow-up "`date -d` skips GC on macOS" is obsolete, because T-0012 made the date handling portable.
- The F23 change is conditional on T-0024 being on main.

### Implementer notes (from the design review)

1. R3-01 (design item 8), must fix.
2. Every command that may daemonize after the lock is taken goes through `run_step`: `git commit` (which may detach `gc --auto`), `chezmoi apply`, and `home-manager switch`. Short `$(…)` queries are fine.
3. S25: pin the environment variables, and include the mimeapps precedence hint.
4. bats isolation: stub `nix-store`, use flock where needed, and set `XDG_STATE_HOME`. Never touch real GC roots or real state.
5. The adopted-child append relies on `ui_init ""` not truncating. Recheck if update-ui changes.
6. Restore-guard wording: safety rests on the `.failed` copy, because other agent sessions may edit the repo concurrently (design item 9).
7. The "`date -d` skips GC on macOS" follow-up is obsolete (T-0012 is portable).
8. Gates: Gate A (T0–T2) is committed and independently reviewed before Gate B (T3–T7) starts.

### Follow-ups (not in this plan)

- FU1: darwin automated rollback by rooted path.
- FU2: cross-machine lock-commit policy (F13).
- FU3: `prepare`, `activate` and `maintain` subcommands.
- T-0011 follow-up: orphaned ticker printing after Ctrl-C.

### Rollback of this change

- `git revert` the commits.
- Metadata keys are additive, so older readers ignore them.
- Remove `$STATE_DIR/gcroots` to drop the GC roots.

## Progress log

- 2026-11-14: Plan created as `draft`. Design accepted (round 3, PASS WITH NOTES). Implementation not started. No task, criterion or scenario is ticked. The prerequisite tickets are `Status: open` in their tickets, so their landing is unverified.
