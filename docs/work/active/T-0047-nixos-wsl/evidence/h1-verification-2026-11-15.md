# H1 verification after the two runs (2026-11-15)
Read-only checks on the Windows PC after the elevated and normal runs.

| Check | Result |
|-------|--------|
| `wsl --list --verbose` | NixOS, version 2 |
| Distro starts | Yes; commands as root run |
| Default user | Still nixos; `id utmostcreator` gives "no such user". Expected: the user switch happens in the D0-gated step 9, not a failure. |
| Windows tools (winget, per-user) | chezmoi 2.74.1, gitleaks 8.30.1, lefthook 2.2.2 |
| `.git\hooks\pre-commit` | Exists |
| `bash ops/doctor.sh` | Exit 0 |
| `bash ops/validate-config.sh` | Exit 0 ("all invariants pass") |
| `lefthook run pre-commit` | Exit 1: the inline no-personal-yaml command fails (see T-0051) |

## External review triage
Two outside reviews of the logs, pasted by the user.

| Recommendation | Verdict | Where |
|----------------|---------|-------|
| Verify the distro boots after import | Already done by step 5 (systemd PID 1 and interop); checked again here | This file |
| Preserve existing distros, safe re-runs | By design: state re-probed, exports once per label, import only if the distro is absent | AC-8 in T-0050 findings |
| Download integrity | Done: pinned SHA256 verified before import; a cached file is reused only on a hash match | Bootstrap script |
| Final summary, next action, result vocabulary | Adopted | T-0050 findings |
| Admin versus user separation | Done: only the WSL install step is elevated; tooling is non-elevated | Bootstrap script |
| Hook smoke test after install | Adopted | T-0051 |
| `gitleaks git --staged` | Adopted | T-0051 F4 |
| `wsl --install --from-file` instead of `--import` | Rejected for now: import has no launch step and an explicit location; revisit | - |
| `-Distro` switch | Deferred | ADR-0015 |
| WSL-safe sys-setup defaults (Docker/Tailscale off on wsl) | Already in D0 | T-0047 |
| Windows CI job and Pester | Not adopted now: plain PowerShell tests; a CI ParseFile job is an optional follow-up | - |
| Persisted state machine | Rejected | T-0050 findings |
| Publish the script, update the Ubuntu-era docs | In progress: commits pending; the runbook rewrite is Slice 2b | T-0047 |
| Backup before Docker (`wsl --export`) | Already planned (`-Export before-docker`) | T-0047 |

## Deferred edits (after the first docs commits land)
- Add ADR-0015 to the ADR index and a consequence line to ADR-0001.
- Add T-0051 to `docs/work/index.md`.
- Link expected-results.md from the setup index.
- Update the T-0047 ticket and plan commit lists.
- Add the Ubuntu section to the WSL runbook (Slice 2b).
- Re-plan T-0047 D0 to ADR-0015 (keep genericLinux in the wsl home, add the wsl-nixos output and detect-host --hm-attr, no Ubuntu refusal in preflight).
- T-0047 Transfer-0 "commit on Windows with the hook run by hand" is superseded: lefthook is installed, so `git commit` on Windows runs the failing hook until T-0051 is fixed; commit on the NixOS machine or in WSL.
