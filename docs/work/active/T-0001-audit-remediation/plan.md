# T-0001 Audit remediation: execution plan

- **Status:** draft
- **Work id:** T-0001-audit-remediation (local id; `ticket.md` is being written by the coordinator)
- **Branch:** main (integration target; per-ticket branches are created from it)
- **Designed against:** commit c138903
- **Date:** 2026-11-14

## Context

External audit findings in app-configs are remediated as one ticket per independent area. Each implementation ticket runs in its own git worktree, is reviewed, and is landed on main serially. No push.

User authority, quoted from the request:

- "categorize all of it into tickets, and then write a plan parallel runs and execute the plan and in parallel run reviwers for changes"
- "Each implementer commits its reviewed fix ... on its worktree branch, then the commits get cherry-picked onto main one ticket at a time. No push. mandatory merges to main, conflict resolution where required and then branch and worktrees cleanup are mandatory"
- Syncthing: "report only, never delete conflict files"
- Policy questions: "run researcher to identify strategy and follow it"

## Decision

**Execution model (per implementation ticket)**

1. Create an isolated worktree and branch from current main.
2. Implementer reproduces each finding with a failing test first, then fixes, verifies and commits. Conventional commits, hooks on, never `--no-verify`, no AI attribution trailers.
3. Reviewer independently reviews `git diff <base>..<tip>` and returns PASS, PASS WITH NOTES or FAIL. At most 3 failing rounds per ticket. Corrections are folded into the original commits with fixup and autosquash on the unlanded branch.
4. After PASS, the coordinator records base, tip and sha256 of the diff.
5. Landing: cherry-pick each ticket branch onto main serially, resolve conflicts where required, then run bats, `nix flake check ./nix` and `validate-config` after each wave.
6. Remove that ticket's worktree and branch. Never touch the two pre-existing locked worktrees of other sessions.

**Waves** (dependencies as stated in the request)

- Wave 0 (running): ticket records; policy research; architect design for T-0010.
- Wave 1 (parallel): T-0002, T-0003, T-0004, T-0005, T-0006, T-0007, T-0011, T-0012, T-0013, T-0015, T-0016, T-0018, T-0021, T-0023, T-0024, T-0027.
- Wave 2 (after Wave 1 lands and research/design is done): T-0008, T-0010, T-0014, T-0017, T-0019, T-0022. Within Wave 2, T-0022 must land before T-0014 and T-0019, which depend on its policy.
- Wave 3: T-0009, T-0020, T-0025, T-0026.
- Final: land records, full verification on main, final review, cleanup confirmation.

**Constraints**

- Syncthing (T-0002): report only. Never delete conflict files.
- Policy topics for Wave 0 research: tool ownership, runtime ownership, navi/glow/tealdeer, Nix installation and GC ownership, Homebrew scope. Follow the researcher's recommended strategy.
- T-0026 (repo-guardian agent draft) stays inactive until the user approves it.
- Do not touch the user's uncommitted Glyphbrace files: `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `.claude/`, `.agents/`, `.codex/`, `.glyphbrace/`, `docs/ai`, `docs/generated`, `docs/shared`, `docs/work/index.md` and READMEs.
- Ticket records under `docs/work/active/T-*/` are committed at the end with `git add -- <paths>` only.

**Rejected alternatives:** none recorded in the request (`unknown`).

## Acceptance criteria

None were defined in the request, so no criterion ids exist and none are invented here. Each ticket's criteria are `unknown` until its `ticket.md` is written. Once written, criteria are copied with their ids exactly as given.

**Program gates on main (final wave):** `bats tests/bash`; `nix flake check ./nix`; `bash ops/validate-config.sh`; `chezmoi diff` report; `bash ops/update-all.sh` in report mode.

## Tasks

For every task, files, criteria covered, risk, done definition and verifying command are `unknown` until its `ticket.md` exists. Review is required for every implementation ticket (program rule).

**Wave 0 activities (no task ids)**

- [ ] Ticket records for T-0001 to T-0027 (in progress, coordinator)
- [ ] Policy research: tool ownership, runtime ownership, navi/glow/tealdeer, Nix installation and GC ownership, Homebrew scope (researcher)
- [ ] Architect design for T-0010 (architect)

**Wave 1**

- [ ] T-0002 Syncthing conflict preservation (P0). Depends: none listed. Report only for conflict files.
- [ ] T-0003 Snapshot fail-closed. Depends: none listed.
- [ ] T-0004 Git hooks detection (P0). Depends: none listed.
- [ ] T-0005 Projects lib safety (injection). Depends: none listed.
- [ ] T-0006 Projects scripts. Depends: none listed.
- [ ] T-0007 Health runner. Depends: none listed.
- [ ] T-0011 Update libs. Depends: none listed.
- [ ] T-0012 Cleanup exit status. Depends: none listed.
- [ ] T-0013 Detect-host validation. Depends: none listed.
- [ ] T-0015 Doctor preflight. Depends: none listed.
- [ ] T-0016 Nix flake checks, CI and darwin-rebuild output. Depends: none listed.
- [ ] T-0018 Nix home modules runtime (dev.nix, gui.nix). Depends: none listed.
- [ ] T-0021 SSH-agent installer. Depends: none listed.
- [ ] T-0023 codebase-memory-mcp tests. Depends: none listed.
- [ ] T-0024 Ops reporting accuracy. Depends: none listed.
- [ ] T-0027 Statusline upgrade. Depends: none listed.

**Wave 2**

- [ ] T-0008 Bootstrap safety. Depends: T-0003, T-0013, T-0015, T-0016.
- [ ] T-0010 Update lifecycle. Depends: T-0002, T-0003, T-0011, T-0012, T-0013, and the architect design.
- [ ] T-0014 validate-config enforcement. Depends: T-0022.
- [ ] T-0017 Nix identity. Depends: none listed.
- [ ] T-0019 Nix settings, hosts, darwin and CLI ownership. Depends: policy (Wave 0 research, T-0022).
- [ ] T-0022 Ownership policy docs. Depends: Wave 0 policy research.

**Wave 3**

- [ ] T-0009 Install safety. Depends: T-0008, T-0017.
- [ ] T-0020 Mise tasks. Depends: T-0003, T-0010.
- [ ] T-0025 Failure-prevention registry and skill. Depends: landed fixes (which ones: `unknown`).
- [ ] T-0026 Repo-guardian agent draft. Depends: T-0025. Inactive until user approval.

## Notes

**Open questions**

1. Wave 1 runs in parallel, but no file lists were supplied. Same-file overlap cannot be checked. Likely pairs to check: T-0005 and T-0006 (projects), and T-0016 and T-0018 (nix). Coordinator to confirm before launch.
2. T-0025 names "landed fixes" without naming them. Confirm the set.
3. Audit findings source (report path) is not stated in the request. Findings should be traced to tickets in each `ticket.md`.
4. T-0001 was chosen as a local id. Before integration, check that no folder on the joining branch uses it (per `docs/work/active/README.md`).

**Risks**

- Glyphbrace and other concurrent sessions edit the repo; docs/work is untracked, so this plan will not appear in `git diff`.
- Two locked worktrees from other sessions exist and must be left alone.

**Decisions made along the way:** none yet.

## Progress log

- 2026-11-14: Plan created as draft at commit c138903. No task is evidenced as done.
