Source: local

# T-0013: detect-host validation (P0)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
ops/detect-host.sh misclassifies hosts and silently accepts bad input.

## Owned files (write boundary)
- ops/detect-host.sh
- tests/bash/detect-host.bats (new)

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- WSL1 kernel 4.4.0-Microsoft gives profile `wsl` though only WSL2 is supported (reported reproduced). Use a single detect_wsl_version; reject WSL1 in profile mode.
- HOST_PROFILE_DEFAULT not validated: a broken profile is echoed (allow only linux-desktop|linux-cli on Linux).
- Unreadable/missing /proc/version gives linux-desktop (distinguish grep error 2).
- Generic 'microsoft|wsl' match yields false positives.
- Custom WSL2 kernels: use /proc/sys/kernel/osrelease / uname -r, WSL_DISTRO_NAME as secondary, fail on ambiguity.
- Unknown args (e.g. --wsl-verison) silently ignored.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed. Consumed by T-0008 and T-0010.

## Closure

- **Commits:**
  - 4ccd4c5 fix(ops): require a filesystem marker for WSL2 detection by env var
  - b3f37ce test(ops): isolate detect-host caller suites from the host kernel and WSL env
  - 3d197a3 fix(ops): validate input and fail loudly in detect-host
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
