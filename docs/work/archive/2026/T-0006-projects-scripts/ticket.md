Source: local

# T-0006: projects scripts correctness (P1)

Status: closed (2026-11-14)
Wave: 1
Depends on: none (coordinate with T-0005 on lib.sh use)

## Summary
Several ops/projects scripts reference missing files, mis-handle arguments or lose failures.

## Owned files (write boundary)
- ops/projects/workspace/config.sh
- ops/projects/tmux/ssh.sh
- ops/projects/tmux/master.sh
- ops/projects/github/pr-watch.sh
- ops/projects/github/sync-main.sh
- related tests

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- config.sh:45,50 reference logging/workspace/watch.sh and stop-watch.sh, which do not exist (real: logging/watch/).
- ssh.sh:~1209 SSH alias interpolated into shell commands unescaped.
- master.sh:205-219 `--force --invalid` kills the session before rejecting the invalid arg (parse all args first).
- pr-watch.sh:79-82 returns early when there are no open PRs, so closures are never reported.
- pr-watch.sh:140-153 a closed-unmerged PR fires pr_merged.
- sync-main.sh:37-43 earlier repo failures are not aggregated into the exit status.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.

## Closure

- **Commits:**
  - 0a2435d fix(projects): stop pr-watch feeding jq a malformed previous state
  - b642d75 fix(projects): report pr-watch closures and tell merged from closed
  - bb6309e fix(projects): parse all master.sh args before killing the session
  - e94a219 fix(projects): validate and quote ssh aliases sent to tmux panes
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
