Source: local

# T-0014: validate-config rule enforcement

Status: closed (2026-11-14)
Wave: 2
Depends on: T-0022 (ownership policy)

## Summary
ops/validate-config.sh rules miss real violations or report wrongly. Prefer evaluated-nix checks over regex where practical.

## Owned files (write boundary)
- ops/validate-config.sh
- tests/bash/validate-config.bats (new, good/bad fixtures)

## Findings
Each item is an external audit claim — unverified until reproduced. Reproduce first; reject false positives with evidence.

- Rule 7 (bootstrap tools in home.packages) and rule 8 (direnv) miss multiline lists because rg prints only the matching line.
- Rule 7 prints [OK] after errors.
- Rule 2 checks home/.chezmoiscripts but the message says .chezmoiops.
- Rule 6 regex misses `programs.x = { enable = true; }`, `programs = { x.enable = ... }`, mkDefault, and matches comments.
- rg failures suppressed (fail closed).
- Rules 4-5 secret path checks depend on working-tree existence (check the tracked index).
- Rule 10 bypassed by `git add -N` (note).
- Rule 1 .chezmoiroot content not validated.
- Rule 9 empty docs / TBD variants.

## Acceptance criteria
- Each finding reproduced by a failing bats/unit test, or recorded as a false positive with evidence.
- Fix applied; regression test fails on the old code and passes on the new.
- Affected `bats` files, `bash ops/lint-shell.sh` (if applicable) and `nix flake check ./nix` (nix changes) pass.
- Independent review PASS; one conventional commit per logical change; no AI attribution trailers.
- Follows the allowlist of HM programs/services from T-0022.

## Out of scope / notes
Only the files listed above. Unrelated findings are reported, not fixed.
- Write boundary extended to docs/architecture/tool-ownership.md (validator section) for the F5/F7 follow-up; accepted by the orchestrator within the user-authorised batch, 2026-11-14.

## Closure

- **Commits:**
  - d0e42fe chore(gitignore): ignore private projects.yaml and restsift state
  - 9c5bf51 fix(validate): reject chezmoi-owned home.file, ask chezmoi about ignores
  - 5906e16 feat(validate): evaluate the macos profile and show nix eval errors
  - d411ded fix(validate): fail closed on rule 9 and find errors, allow quoted names
  - 21cc376 feat(validate): add --eval for the evaluated Home Manager config
  - 5f1f114 feat(validate): enforce xdg.configFile allowlist and one owner per path
  - 82676f7 fix(validate): check Home Manager policy on stripped Nix, not grep
  - 9f5aa08 fix(validate): fail closed; check tracked secrets, chezmoi dirs, TBDs
- **Verification:** independent review PASS / PASS WITH NOTES; full bats and ci-local green on main 2f93e0f.
- **Remaining limitations or follow-ups:**
  - F7-5: parent-level `inherit file`/`inherit home` can hide `home.file`.
  - N-4: `config = <non-literal>` and `imports` are decided only by `--eval`.
  - `--eval` is not yet in CI; this is parked for the user.
