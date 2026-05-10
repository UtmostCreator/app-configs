# In-Repo Installation Runbook (Restarted From Zero)

Target repository: `C:/xampp/htdocs/app-configs`

## Step Log

| # | command | description | verification step / expected result |
|---|---|---|---|
| 1 | `git status --short` | Capture pre-install backup evidence of working tree before overwrite-style operations. | **Observed:** `?? readme-install.md`. **Expected:** known baseline before install/apply. |
| 2 | `git log -1 --oneline` | Capture rollback anchor commit before running install flow. | **Observed:** `06dde0c feat(policy): correct policy and regestry scripts & rules`. **Expected:** latest commit hash recorded. |
| 3 | `php tools/ai/ai.php install --profile full-governance --reinstall --dry-run` | Canonical full-governance dry-run reinstall plan (covers copilot/opencode/scripts/hooks/advisor surfaces). | **Blocked by policy gate:** command class is `ask` in current runtime policy, execution denied. **Expected when approved:** dry-run install plan output without mutations. |
| 4 | `php tools/ai/install-ai-kit.php --target . --profile full-governance --runtime dual --dry-run --force` | Alternative direct installer dry-run with explicit force/override semantics. | **Blocked by policy gate:** denied in current runtime. **Expected when approved:** overwrite plan for dual runtime surfaces. |
| 5 | `php tools/ai/validate-command-policy.php .` | Validate command-policy tiers and registry contracts after policy/registry work. | **Observed:** `{"status":"passed","policy_score":100,...}`. **Expected:** pass with no major findings. |
| 6 | `php tools/ai/validate-ai-config.php` | Verify root AI workflow files, references, and policy consistency. | **Observed:** `OK: rootAIworkflowvalidationpassedwithwarnings` with only `.github/copilot-instructions.md` warnings. **Expected:** pass (warnings allowed). |
| 7 | `php tools/ai/validate-ai-catalog.php` | Validate AI catalog metadata integrity. | **Observed:** `OK: AI catalog metadata validation passed`. **Expected:** pass. |
| 8 | `php tools/ai/generate-ai-catalog.php --check` | Ensure generated catalog artifacts are up to date after changes. | **Observed:** all up to date (`catalog.json`, `docs/ai/catalog.md`, `BROWSE.md`, `llms.txt`). **Expected:** no drift. |
| 9 | `php tools/ai/verify-full-install.php` | Full install verification chain (preflight -> package verify -> plan -> validation -> repomix -> advisor -> verify). | **Blocked by policy gate:** command is `ask` and denied in this runtime. **Expected when approved:** full/partial install state + remediation list. |
| 10 | `bash scripts/ai/run-repomix-context.sh .` | Repomix context script verification path. | **Not runnable in this runtime:** `bash` not available. **Expected when available:** context pack analysis + validation output. |
| 11 | `bash scripts/ai/repomix-context-tree.sh all .` | Repomix tree pack/plan/analyze comprehensive script check. | **Not runnable in this runtime:** `bash` not available. **Expected when available:** context tree artifacts and summary. |
| 12 | `php tools/ai/ai.php advisor --all` | Advisory script pass over generated signals/context. | **Blocked by policy gate:** not allowlisted for direct execution in this runtime. **Expected when approved:** advisor findings and recommendations. |

## Preferred Options (and Why)

| Option | Prefer? | Why |
|---|---|---|
| `--profile full-governance` | Yes | Broadest install profile that includes both Copilot and OpenCode governance surfaces plus verification-oriented defaults. |
| `--reinstall` | Yes (for restart-from-zero) | Reapplies surfaces on top of existing repo to refresh adapters/scripts/docs without manual cleanup. |
| `--dry-run` first | Always | Produces explicit mutation plan before apply; safest way to verify intended overwrite scope. |
| `--runtime dual` | Yes | Ensures both Copilot and OpenCode installation targets are refreshed in one run. |
| `--force` | Use carefully | Needed when overwrite semantics are required; pair with dry-run evidence first. |
| `--verify-after` | Yes | Runs follow-up validation chain automatically after install for immediate proof. |

## Full Installation Command Set To Run When Policy Approval Is Granted

1. `php tools/ai/ai.php install --profile full-governance --reinstall --dry-run`
2. `php tools/ai/ai.php install --profile full-governance --reinstall --apply`
3. `php tools/ai/validate-ai-config.php`
4. `php tools/ai/validate-install-surface.php`
5. `php tools/ai/validate-ai-catalog.php`
6. `php tools/ai/generate-ai-catalog.php --check`
7. `php tools/ai/verify-full-install.php`
8. `bash scripts/ai/run-repomix-context.sh .`
9. `bash scripts/ai/repomix-context-tree.sh all .`
10. `php tools/ai/ai.php advisor --all`

## Current Session Status

- Validation commands that are allowlisted **were executed successfully** (steps 5-8).
- Core installer/apply/verify-full-install/advisor/repomix commands are **policy-gated (`ask`) and were denied in this runtime**, so full in-place reinstall could not be completed here.
- This file documents both executed evidence and the exact command set required to finish full installation once approval/policy gate is opened.

## Maintenance Mode (Temporary Full-Install Window)

Use maintenance mode to temporarily permit full repository install/verify workflows while keeping strict defaults outside this window.

1. `php tools/ai/maintenance-mode.php status`
2. `php tools/ai/maintenance-mode.php enable --reason "full-governance reinstall" --ttl-seconds 1800`
3. run the full installation command set in this runbook
4. `php tools/ai/maintenance-mode.php disable`

### Explicitly allowed search evidence during maintenance mode

- `AI_OUTPUT=json bash scripts/ai/ai-search.sh changed "maintenance mode" . --fixed`
- `AI_OUTPUT=json bash scripts/ai/ai-search.sh staged "maintenance mode" . --fixed`
- `AI_OUTPUT=json bash scripts/ai/ai-search.sh tracked "maintenance mode" . --fixed`

If a script is not repository-delivered under this repo path, it must remain `ask` (human approval required).

## Continuation Session (Post-Install-Surface Fixes)

| # | command | description | verification step / expected result |
|---|---|---|---|
| 13 | `php tools/ai/validate-install-surface.php` | Re-run install-surface verifier after source fixes. | **Observed:** `OK: install surface validation passed` with warnings only (line budgets + missing optional `.vscode/settings.json`). **Expected:** no install-surface errors. |
| 14 | `php tools/ai/validate-ai-config.php` | Confirm overall AI config after repairs. | **Observed:** pass with `.github/copilot-instructions.md` advisory warnings only. **Expected:** pass. |
| 15 | `php tools/ai/validate-ai-catalog.php` | Confirm catalog integrity. | **Observed:** pass. **Expected:** pass. |
| 16 | `php tools/ai/generate-ai-catalog.php --check` | Drift check after adding missing skills/pack mappings. | **Observed:** `catalog.json` and `docs/ai/catalog.md` out of date. **Expected after regenerate:** up to date. |

### Additional fixes applied in this continuation

1. Added missing `scripts-pack` entries in installer pack registry for:
   - `scripts/ai/ai-structured.sh`
   - `scripts/ai/ai-task.sh`
   - `scripts/ai/ai-test-select.sh`
   - `scripts/ai/session-checkpoint.sh`
2. Added missing installed skills to satisfy workflow-template validation:
   - `.github/skills/review-search-tool/SKILL.md`
   - `.github/skills/search-evidence/SKILL.md`
   - `.opencode/skills/review-search-tool/SKILL.md`
   - `.opencode/skills/search-evidence/SKILL.md`
3. Updated Copilot repository agents to use fine-grained VS Code tool names:
   - `.github/agents/repository-researcher.agent.md`
   - `.github/agents/repository-reviewer.agent.md`
4. Added execution-protocol reference in `.github/copilot-instructions.md`.

### Remaining action to complete this runbook

- Regenerate catalog artifacts (not just `--check`) and re-run checks:
  1. `php tools/ai/generate-ai-catalog.php`
  2. `php tools/ai/generate-ai-catalog.php --check`

If your shell prints `'git' is not recognized as an internal or external command` during installer commands, add Git to PATH and retry:

```powershell
$env:Path = "C:\Program Files\Git\cmd;$env:Path"
git --version
```
