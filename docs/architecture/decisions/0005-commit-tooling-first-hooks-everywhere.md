# ADR-0005: Commit tooling first, hooks everywhere
Status: decided (Windows automation planned, not yet committed) · Date: 2026-11-15 · Sources: docs/platforms/base.md, `.lefthook.yml`, `ops/hooks/pre-commit.sh`, `ops/install.sh` (steps 3, 9), T-0047 plan (task T2), `repo-docs/migration-source-of-truth.md` (line 77)

## Decision
- lefthook runs the hooks, gitleaks scans for secrets, chezmoi is needed by `ops/validate-config.sh`. All three are installed before the first commit on every machine.
- Linux and macOS: automatic in `ops/install.sh` (chezmoi and lefthook in step 3, `lefthook install` in step 9; gitleaks comes from `nix/modules/home/dev.nix`). Windows: the bootstrap's commit-tooling step (planned).
- Rules: never bypass a failing hook (no `--no-verify`); commit only where the hooks are installed and pass.

## Why
- A secret or a broken config must be stopped before it enters history, on every machine, not only the main one.
- One hook owner: lefthook; the old `.husky/` shims were removed (`repo-docs/migration-source-of-truth.md:77`).
- The scan fails closed: no scanner means the commit is blocked.

## Strong alternatives
| Option | Why it lost |
|--------|-------------|
| trufflehog as the scanner | Not a loser: `ops/hooks/pre-commit.sh` uses it when gitleaks is missing. gitleaks is the default; why gitleaks first: reason not recorded. |
| Other hook runners (husky, the pre-commit framework) | husky was replaced by lefthook; why lefthook: reason not recorded. The pre-commit framework: not mentioned in the repo. |

## Discarded
`APP_CONFIGS_ALLOW_MISSING_SCANNER=1` exists as a loud bootstrap-only escape hatch; it is not a standing option.

## Consequences
- Windows has no hooks until T-0047 task T2; docs-only commits there are allowed with `ops/validate-config.sh` and gitleaks run by hand, code commits only where hooks run.
- Follow-up: `gitleaks protect --staged` is deprecated since v8.19.0 (maintained form `gitleaks git --staged`).
- Proposal, not decided: move `lefthook install` right after step 3 of `ops/install.sh`.
