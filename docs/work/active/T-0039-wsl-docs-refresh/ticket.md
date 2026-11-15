Source: local

# T-0039: Refresh the WSL2 docs (docs)

Status: open
Wave: 3
Depends on: T-0034, T-0036, T-0037, T-0038 (so the docs describe merged behaviour); also T-0035 (exit-3 text) and T-0045 (systemd and CBM guidance). Exception: the wsl.conf row below is a first-boot risk, has no dependencies and may land first.
Order: seventh. Recommended implementation order for the WSL2 work: T-0035, T-0038, T-0037, T-0036, T-0034, T-0045 (Wave 2), T-0039 (its wsl.conf fix may land first), T-0040 last. Full test order and fix-before gates: T-0040. The wsl.conf fix must land before T-0040 step 3. Test order: T-0040.

Re-verified 2026-11-15 against main ed39171: none of the WSL2 tickets has been executed and every bug described is still present. User decisions unchanged: Wave 1 = T-0034..T-0038; Windows-side provisioning stays manual; T-0041 is docs-only.

## Summary
Fix stale and risky WSL2 statements and document the manual Windows
prerequisites. No behaviour change.

## Owned files (write boundary)
- docs/platforms/wsl/setup.md
- docs/getting-started/bootstrap.md ("WSL2 caveats" section only)
- docs/plans/migration/implementation.md (the clipboard and detection lines only; not Appendix A)

## Findings
| Location | Stale or risky | Correction |
| --- | --- | --- |
| setup.md wsl.conf snippet (around lines 20-24) | CRITICAL, can land earlier: `#` comments follow values (`systemd=true`, `default=...`, `appendWindowsPath=true`). Whether WSL strips trailing comments is UNKNOWN, so this is a first-boot risk that blocks test step 3 | Move each comment to its own line above its key |
| setup.md "Opening URLs and files" / BROWSER line | Says only fish sets BROWSER and `open` | Mention fish, zsh and bash after T-0036 |
| setup.md verify table | No `code` row | Add the `code` check and its fix (T-0037) |
| setup.md systemd and CBM | systemd is described only as running timers | State that systemd must be on before install and that the codebase-memory-mcp units run on WSL only with systemd (T-0045) |
| setup.md readiness text | Treats ALL SET and exit 0 as the only success | Add exit 3 ("READY with TODO") once T-0035 lands (T-0035 owns install.md and README.md) |
| setup.md VS Code row | — | The extension installer skips WSL2; extensions come from Windows VS Code Settings Sync (T-0037) |
| setup.md docker compose | "docker compose" from Nix | A plugin of the Nix `docker` package, or explicit; the claim must follow T-0038's result |
| setup.md section 1 | No Windows prerequisites | Manual, unmanaged: Windows VS Code; Windows Terminal (built into Windows 11); JetBrainsMono Nerd Font (same family as the macOS font cask) set as the Terminal profile font; without it starship and eza icons show as boxes |
| setup.md "Not yet verified" | — | Link the test-pass doc (docs/platforms/wsl/test-pass.md, created by T-0034) and T-0040 |
| bootstrap.md (around lines 96-97) and implementation.md (lines 91, 1477) clipboard lines | "Clipboard: use clip.exe ... No automation here" (wrong: `home/dot_local/bin/executable_clipcopy` uses clip.exe) | `clipcopy` (home/dot_local/bin/executable_clipcopy) copies through clip.exe for tmux; `wsl-open` opens URLs and paths |
| bootstrap.md and implementation.md detection lines (implementation.md around 1087, 1479 and 1616) | Detection by a `/proc/version` grep | `ops/detect-host.sh` reads the kernel release and WSL markers (/proc/sys/fs/binfmt_misc/WSLInterop, /run/WSL) and refuses WSL1; the `HOST_PROFILE` override remains |
- The install-selection section already exists at the end of setup.md: do not duplicate it.
- implementation.md Appendix A stays unchanged (still accurate; T-0041 owns it if approved).

## Acceptance criteria
- AC1: every row above is corrected.
- AC2: `git diff --stat` lists only the owned files; docs only.
- AC3: `bats tests/bash/doc-contracts.bats` passes.

## Verification
- `git diff --stat`; `bats tests/bash/doc-contracts.bats`
- A reviewer reads setup.md end to end against the merged T-0034 to T-0038.

## Out of scope / notes
- Windows app lists (T-0041), `.wslconfig`, Terminal fragments.
- Test order and fix-before gates: T-0040.
- Only the files listed above.
