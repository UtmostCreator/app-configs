Source: local

# T-0018: Home Manager dev/gui module runtime issues

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
Runtime and comment defects in dev.nix and gui.nix.

## Owned files (write boundary)
- nix/modules/home/dev.nix
- nix/modules/home/gui.nix
- nix/modules/home/scripts/* touched by gui.nix fixes
- related tests

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- dev.nix gremlins config at gremlins/gremlins/.gremlins.yaml (should be gremlins/.gremlins.yaml).
- User service Wants/After network-online.target is ineffective in systemd --user.
- php (generic) + php84Packages.composer mismatch.
- codebase-memory updater runs full HM activation (assess, document).
- gui.nix HDMI WirePlumber rule renames any pci hdmi sink to "DELL S3425DW" (narrow the match).
- api.alsa.soft-mixer on a node rule but is a device property (verify docs).
- sync-open opens the UI after readiness fails; comment says 15s but worst case ~75s.
- Flameshot comment says disabledTrayIcon=true but sets false.
- vscode-recent-projects `code ... || true` hides failures.
- 250ms focus-tracker polling (assess; follow-up if event-driven is large).
- node.pause-on-idle comment misleading.
- USB bandwidth comment incorrect.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Hardware split into a host module is a follow-up unless trivial. Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - a9f7bd0 fix(gui): scope HDMI rename to the two GPU audio functions, fix audio comments
  - ebcd938 fix(gui): surface vscode-recent-projects open failures
  - 295cfb6 fix(gui): bound sync-open and open the UI only when it answers
  - c01d30d fix(dev): pin php and composer together, drop ineffective network-online
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - The ticket named event-driven focus-tracking and a hardware host-module split as follow-ups; unknown whether either was taken, none recorded.
