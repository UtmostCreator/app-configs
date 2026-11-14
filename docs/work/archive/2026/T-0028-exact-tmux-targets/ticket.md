Source: local

# T-0028: Exact tmux targets in project workspace scripts (bug)

Status: closed (2026-11-14)
Wave: 1
Depends on: none
Branch: fix/T-0028-exact-tmux-targets (base f1f3fd3)

## Summary
tmux prefix-matches bare session names, so `has-session`, `kill-session`,
`detach-client` and `switch-client` with `-t "$SESSION"` can act on another
session whose name starts with it (for example ws-dev vs ws-dev-other).
Use the exact form `-t "=$SESSION"` everywhere the project scripts target a
session, and stop the tmux health check from running with an empty target.

## Owned files (write boundary)
- ops/projects/tmux/{master,ssh}.sh, ops/projects/logging/kill-logs.sh
- ops/projects/logging/watch/stop-watch.sh
- ops/projects/workspace/{stop,restart}.sh, workspace/frontend/{stop,restart}.sh,
  workspace/stack/stop.sh
- ops/projects/health/{lib,verify-workspace}.sh, health/checks.d/10-tmux.sh
- ops/projects/github/pr-watch.sh
- tests/bash/projects-tmux-exact.bats, projects-workspace-exact.bats,
  projects-yq-lookups.bats, projects-scripts.bats

## Findings
- Bare session names in kill/has/detach/switch calls (prefix match).
- master.sh --detached inside $TMUX still called switch-client.
- Tmux health check ran has-session with an empty target when
  tmux.master_session could not be read.
- pr-watch.sh and health/lib.sh interpolated an event name / project id into
  yq expressions instead of passing them via strenv().
- The private-socket ssh test could reach the real ssh and used a socket path
  that can exceed the unix socket length limit.

## Acceptance criteria
- Every session-targeting tmux call in the files above uses an exact target.
- master.sh --detached never switches the client; the attach path uses exact
  targets.
- The tmux health check emits fail on unreadable config.
- yq lookups of event names and project ids go through strenv().
- Tests never touch the real HOME, live tmux or real ssh/pkill.
- `bats tests/bash/projects-*.bats tests/bash/test-hygiene.bats` and
  `bash ops/lint-shell.sh` pass on every commit.
- Independent review PASS; one conventional commit per logical change, each
  with `Refs: T-0028`; no AI attribution trailers.

## Commits
- fix(projects): use exact tmux targets and fail the tmux check on bad config
- fix(projects): look up pr-watch events and health projects via strenv
- test(projects): make the private-socket ssh test hermetic
- fix(projects): use exact tmux targets in ws stop, restart and attach

## Evidence
- Per commit, in a scratch copy: bats projects-*.bats + test-hygiene.bats
  57/57, 59/59, 59/59 and 68/68 pass; `bash ops/lint-shell.sh` rc=0.
- Pre-commit and commit-msg hooks passed on every commit (no --no-verify).
- Content check: sha256 of the diff vs f1f3fd3 is identical before and after
  the history rewrite (280b298b...).

## Out of scope / notes
Not pushed. Landing on main is a separate step. `nix flake check` was not run
(no nix files changed).

## Closure

- **Commits:**
  - 29dbfce fix(projects): use exact tmux targets in ws stop, restart and attach
  - 4bf5ecb test(projects): make the private-socket ssh test hermetic
  - 6251e3a fix(projects): look up pr-watch events and health projects via strenv
  - 6434b79 fix(projects): use exact tmux targets; fail tmux check on bad config
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - none recorded.
