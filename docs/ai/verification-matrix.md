# Verification Matrix

Select verification by changed paths, then escalate only as needed.

| Changed path | Minimum verification | Broader verification | Risk bump |
| --- | --- | --- | --- |
| `docs/ai/**` | docs link/path integrity + config validation | adapter drift validation | low |
| `.github/**` | adapter drift validation | config + catalog validation | medium |
| `.opencode/**` | adapter drift validation | config + catalog validation | medium |
| `tools/ai/**` | targeted tool command check | full AI validation commands | medium |
| `scripts/**` | shell syntax + focused script dry run | doctor + verify workflow | medium |
| `.schemas/**` | schema parse/validation | config + generated artifact validation | medium |
| `policies/**` | policy lint/review | release-safety review | high |

## Required Evidence

Report:

- commands run
- commands not run and why
- risk level
- remaining uncertainty
