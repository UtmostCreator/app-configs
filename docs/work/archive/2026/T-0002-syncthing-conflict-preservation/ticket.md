Source: local

# T-0002: Syncthing conflict-file preservation (P0 data loss)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
The Syncthing Obsidian helper deletes sync-conflict files on --apply, and sys-update invokes it. Decision (user): REPORT ONLY. Conflict files are never deleted.

## Owned files (write boundary)
- ops/syncthing-obsidian-stignore.sh
- ops/update-all.sh (only the syncthing call-site hunk)
- tests/bash/syncthing-obsidian-stignore.bats (new)

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Apply path recursively finds and deletes `*sync-conflict-*` files (ops/syncthing-obsidian-stignore.sh ~152-199).
- update-all.sh --apply invokes it with --apply (~566-628) with no deletion confirmation.
- A deletion failure is treated as a warning only.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Decided behaviour: report only. Keep .stignore sync; list conflict files with resolve-by-hand guidance; sys-update never deletes them.
- Test proves conflict files and unrelated Syncthing folders survive --apply and the sys-update path.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed. Any deletion mode would need a new user decision.

## Closure

- **Commits:**
  - 39ee41c fix(syncthing): report sync-conflict files instead of deleting them
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
