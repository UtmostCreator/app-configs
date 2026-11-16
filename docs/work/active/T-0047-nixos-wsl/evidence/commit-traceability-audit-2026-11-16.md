# Commit traceability audit (2026-11-16)

Later record for immutable, already published commits; the commits are not rewritten.

- Scope: the 11 commits below, chosen by hand from `git log 3757c2e^..8f6b4eb` (Windows bootstrap, hooks, WSL docs). Not audited: e71bdef, 9a4c97d and the other NixOS-side commits.
- Result: 11 commits, 3 PASS / 8 FAIL.
- Secrets: gitleaks over 48 commits found no leaks.
- Rule audited: change-traceability (conventional subject of 72 characters or fewer, imperative; Why/Change/Verified body; `Refs:` ids; no AI attribution trailer).
- "not recorded at commit time": no evidence exists in the commit or the repo.

| SHA | Subject | Result | Gap | Context (Why / Verified pointer) |
|-----|---------|--------|-----|----------------------------------|
| 8f6b4eb | fix(hooks): check only dispatchers for +x so --check passes on Windows NTFS | FAIL | Subject 75 > 72; no labels; Verified not stated (adds a githooks.bats case); `Refs: T-0051` missing | Why: fixes T-0047 item (a); findings #9. Verified: not recorded at commit time |
| 0e93bb7 | feat(ssh): forget agent keys after a configurable lifetime, 8 h by default | FAIL | Subject 74; no labels; no Verified (adds bats). In scope only through a 1-line setup.md edit | Why: not recorded at commit time. Verified: not recorded at commit time |
| f7619da | feat(hooks): refuse partially staged commits before lefthook can stash | FAIL | No body for a large feature (installer, dispatchers, `_lefthook.sh`, bats); no `Refs: T-0051` | Why: T-0051 F3; findings #30. Verified: not recorded at commit time |
| 4568249 | docs(windows): record T-0052 and ADR-0016 for the Windows status line | PASS | Note: "links resolve" names no command | Why/Verified: no gap recorded by the audit |
| 9682803 | feat(windows): use the git hooks installer in bootstrap step C | PASS | none | Why/Verified: no gap recorded by the audit |
| 5cc6203 | docs(work): record verified Git alias safety findings (T-0053) | FAIL | AI attribution trailer; no labels; T-0053 in the subject instead of `Refs:`. Cannot be removed; recorded as non-compliant | Why: not recorded at commit time. Verified: not recorded at commit time |
| 400a30b | feat(windows): add the NixOS-WSL bootstrap script and its tests | PASS | none | Why/Verified: no gap recorded by the audit |
| 7731a31 | fix(hooks): move the personal-data guard into a script so lefthook runs it on Windows | FAIL | Subject 85; no Why/Change; Verified without results; `Refs: T-0051` missing | Why: T-0051 F1; findings #28. Verified: stated without results |
| b7ff236 | docs: ADR-0015 WSL distro selection, T-0051 Windows hooks, T-0050 findings | FAIL | Three unrelated records in one commit; subject not imperative (74 chars); no body | Why: not recorded at commit time. Verified: not recorded at commit time |
| 28c588b | docs(wsl): plan T-0047 NixOS-WSL desktop-first | FAIL | No body for the 710-line T-0047 plan/ticket/runbooks/evidence; no `Refs:` | Why: not recorded at commit time. Verified: not recorded at commit time |
| 3757c2e | docs(settings): T-0048 Windows settings inventory | FAIL | Subject not imperative; no body; no `Refs: T-0048` | Why: not recorded at commit time. Verified: not recorded at commit time |

## Patterns
- Early docs commits are subject-only.
- Hook and ssh commits have prose bodies without Verified results.
- Ids appear in subjects instead of `Refs:`.
- Nothing enforces the rule: `ops/hooks/commit-msg.sh` checks only the `type(scope)` prefix.

## Follow-up proposal (separate change, not done here)
`ops/hooks/commit-msg.sh` rejects subjects over 72 characters and AI attribution trailers, with bats cases.
