Source: local

# T-0039: Refresh the WSL2 docs (docs)

Status: open
Wave: 3
Depends on: T-0034, T-0036, T-0037, T-0038 (so the docs describe merged behaviour)

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
| setup.md wsl.conf snippet | `#` comments after values; whether WSL strips them is UNKNOWN | Put each comment on its own line above its key |
| setup.md BROWSER line | Says only fish sets BROWSER and `open` | fish, zsh and the bash fallback (T-0036) |
| setup.md verify table | No `code` row | Add the `code` check and its fix (T-0037) |
| setup.md VS Code row | — | The extension installer skips WSL2; extensions come from Windows VS Code Settings Sync (T-0037) |
| setup.md docker compose | "docker compose" from Nix | A plugin of the Nix `docker` package, or explicit, per the T-0038 result |
| setup.md section 1 | No Windows prerequisites | Manual, unmanaged: Windows VS Code; Windows Terminal (built into Windows 11); JetBrainsMono Nerd Font (same family as the macOS font cask) set as the Terminal profile font; without it starship and eza icons show as boxes |
| setup.md "Not yet verified" | — | Link docs/platforms/wsl/test-pass.md (T-0034) and T-0040 |
| bootstrap.md and implementation.md clipboard lines | "Clipboard: use clip.exe ... No automation here" | `clipcopy` (home/dot_local/bin/executable_clipcopy) copies through clip.exe for tmux; `wsl-open` opens URLs and paths |
| bootstrap.md and implementation.md detection lines | Detection by a `/proc/version` grep | `ops/detect-host.sh` reads the kernel release and WSL markers (/proc/sys/fs/binfmt_misc/WSLInterop, /run/WSL) and refuses WSL1; the `HOST_PROFILE` override remains |
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
- Only the files listed above.
