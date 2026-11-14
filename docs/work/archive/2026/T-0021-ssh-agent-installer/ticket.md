Source: local

# T-0021: ssh-agent installer injection and data safety (P0)

Status: closed (2026-11-14)
Wave: 1
Depends on: none

## Summary
The ssh-agent installer injects unescaped values and can delete or corrupt user files.

## Owned files (write boundary)
- ops/unix/ssh-agent-setup.sh
- the ssh-agent loader sources under home/ (locate first)
- tests/bash/ssh-agent-setup.bats
- tests/bash/ssh-agent-loader.bats

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- `fish -c "set -Ux APP_CONFIGS_SSH_KEYS $APP_CONFIGS_SSH_KEYS"` injection plus `|| true` (pass as argv, split to a list).
- --remove deletes the chezmoi-managed loader when an RC file is unmanaged (check loader ownership separately; delete only what the installer created).
- zsh does not word-split `for k in $APP_CONFIGS_SSH_KEYS`.
- macOS ssh config writes UseKeychain before IgnoreUnknown (must precede).
- Uninstall awk+mv changes ~/.ssh/config 0600 to 0644.
- Marker removal with a missing end marker drops the rest of the file (validate pairs).
- UseKeychain detection by grep is inadequate (manage own block).
- Unknown args ignored.
- Shell detection defaults to bash.
- Absolute home paths in RC lines.
- Mixed ownership not tested; zsh not tested.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Not a bug: fish `exit 0` in a sourced conf.d. Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 0744891 fix(ssh-agent): close review gaps in installer argv, shell and rewrite safety
  - 796ed92 fix(ssh-agent): pass keychain one argv entry per key under zsh
  - 5b5e163 fix(ssh-agent): harden installer against injection and data loss
  - 8509df0 fix(ssh-agent): split APP_CONFIGS_SSH_KEYS explicitly and stop shadowing zsh path
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
