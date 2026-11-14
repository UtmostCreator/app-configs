Source: local

# T-0011: update-* helper libraries (P1)

Status: open
Wave: 1
Depends on: none

## Summary
The update UI, facts and profile-conflict libraries contain parsing and error-masking defects.

## Owned files (write boundary)
- ops/lib/update-ui.sh
- ops/lib/update-facts.sh
- ops/lib/profile-conflicts.sh
- tests/bash/update-ui.bats, update-facts.bats, profile-conflicts.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- ui_note builds "$sev\t$src\t$*" with a literal backslash-t; ui_notes_report splits on a real tab, so severity/content are lost.
- ui_run leaks /tmp/sys-update-step.* files.
- git_worktree_state treats a failed git status as clean (fail closed, distinct error state; use GIT_OPTIONAL_LOCKS=0 and --untracked-files=all).
- nix_toplevel_packages pipeline masks nix-store failure.
- nix_parse_store_name `((i++))` aborts under set -e (use ((++i))).
- nix_packages_from_paths filters inspect parsed pname, not basename (.json/.drv/-env slip through).
- package_delta: duplicate names miscounted, summary not last after sort, same-version rebuild invisible.
- Letter-prefixed versions misparsed.
- git_upstream `|| true` conflates no-upstream with failure.
- classify_warning downgrades "error:" to warn; first-number extraction catches timestamps.
- profile-conflicts ignores inactive manifest elements and only checks bin/.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Progress

- 2026-11-14: The ticker fix lands with T-0010.
- 2026-11-14: The ticker fix landed with T-0010 (1cc9f2a, `fix(update-ui): watch the updater pid in the progress ticker`). The ticket stays active: that fix covers only the progress-ticker part, and the other findings above (ui_note tab, git_worktree_state, nix_* parsing, package_delta, classify_warning, profile-conflicts) are not shown as reproduced or fixed by the landed tests. It also waits on the T-0010 release audit.
