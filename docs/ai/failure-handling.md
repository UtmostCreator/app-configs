# Failure Handling

Use this file to classify command failures, decide whether to retry, and record what happened in a way that is useful later.

## Default Rules

- Safe repo-local read-only commands are approval-free by default.
- Approval is still required before secrets access, privileged locations, installs, destructive commands, machine-wide changes, auth or billing changes, or remote actions with side effects.
- Log every command failure that occurs during a task.
- Do not hide a failed command behind a later successful command. Record both.
- Do not blindly rerun the same failing command without a reason.
- If the command was wrong, write down the corrected usage and what to avoid next time.
- For broad repository edits, prefer `scripts/copilot/ai-edit.sh` over raw mass-edit shell commands so snapshots, dry-runs, and post-edit verification are available.

## Failure Log Contract

Record each failure in the task summary or other durable task record with these fields:

| Field             | Requirement                                                                                              |
| ----------------- | -------------------------------------------------------------------------------------------------------- |
| `command`         | exact command or closest safe rendering                                                                  |
| `intent`          | what the command was trying to prove or do                                                               |
| `workdir`         | working directory or target surface                                                                      |
| `risk`            | `low`, `medium`, or `high`                                                                               |
| `mode`            | `read-only` or `mutating`                                                                                |
| `risk_tier`       | `1` (read-only), `2` (modification), or `3` (deletion/recovery) — see `docs/ai/command-risk-taxonomy.md` |
| `result`          | exit code, hook denial, timeout, or observed failure                                                     |
| `category`        | taxonomy entry from this file                                                                            |
| `cause`           | best grounded explanation, or `unknown`                                                                  |
| `reattempted`     | `no`, `same command`, or `corrected command`                                                             |
| `resolution`      | fixed, deferred, blocked, or still failing                                                               |
| `correct usage`   | corrected command, fallback, or safer alternative                                                        |
| `avoid next time` | short note about the bad pattern to avoid                                                                |

## Failure Taxonomy

| Category              | Meaning                                                            | Retry Rule                                                   |
| --------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------ |
| `usage-error`         | wrong flag, wrong path, wrong cwd, bad quoting, bad command choice | do not retry unchanged; correct the command first            |
| `policy-blocked`      | blocked by repo guardrail, hook, or explicit safety rule           | do not retry unchanged; choose a safer path or get approval  |
| `approval-blocked`    | task requires human approval before continuing                     | do not retry until approval is granted                       |
| `environment-missing` | tool, runtime, file, or dependency is missing locally              | do not loop; record limitation and fallback                  |
| `transient-runtime`   | temporary flake, lock, race, or intermittent tool failure          | limited retry is allowed when there is evidence of flakiness |
| `network-remote`      | remote API, GitHub, or network transport failure                   | retry narrowly, then record and defer if still failing       |
| `verification-failed` | a check ran correctly and found a real problem                     | treat as signal, investigate before rerunning                |
| `unknown`             | evidence is insufficient to classify confidently                   | do one narrower diagnostic step before retrying              |

For agent evidence events, use normalized categories from `docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md` when the runtime supports structured event output.

## Agent Evidence Mapping

Use this mapping when both command-level retry policy and event-level evidence are recorded:

| Command-Level Category | Evidence Category Guidance                                                                |
| ---------------------- | ----------------------------------------------------------------------------------------- |
| `policy-blocked`       | `authorization_denied` or `unsafe_mutation_blocked`                                       |
| `approval-blocked`     | `approval_missing`                                                                        |
| `environment-missing`  | `tool_unavailable`                                                                        |
| `transient-runtime`    | `tool_timeout` when timeout is proven, otherwise `external_dependency_failure`            |
| `usage-error`          | `invalid_tool_input`                                                                      |
| `verification-failed`  | `test_failure`, `lint_failure`, or `schema_validation_failure` based on the failing check |
| `network-remote`       | `external_dependency_failure`                                                             |
| `unknown`              | `unknown`                                                                                 |

## Reattempt Policy

- Reattempt at most once for `transient-runtime` unless the tool output clearly recommends another safe retry.
- Reattempt with a corrected command for `usage-error` only after changing the path, flags, quoting, target, or command selection.
- Do not reattempt mutating commands unchanged after a partial failure unless the command is idempotent and the output proves retry safety.
- Do not reattempt `policy-blocked` or `approval-blocked` commands unchanged.
- For `verification-failed`, fix or explain the underlying issue before rerunning the check.
- If two attempts fail for the same reason, stop looping and record the blocker.

## Scenario Matrix

| Scenario                                                       | Category                                    | Treat It As                     | Record                                  | What To Avoid                                    |
| -------------------------------------------------------------- | ------------------------------------------- | ------------------------------- | --------------------------------------- | ------------------------------------------------ |
| wrong file path or stale doc command                           | `usage-error`                               | operator error, not tool flake  | corrected path or command               | rerunning the same bad path                      |
| unsupported runtime feature or unavailable agent surface       | `environment-missing`                       | capability mismatch             | fallback workflow or limitation note    | implying cross-surface parity                    |
| read-only command denied by private path or missing permission | `approval-blocked` or `environment-missing` | boundary issue                  | denied surface and safe fallback        | escalating privileges by default                 |
| hook blocks risky command                                      | `policy-blocked`                            | intended safety stop            | blocked command, hook, safe alternative | fighting the guardrail without changing approach |
| external API or GitHub lookup times out                        | `network-remote`                            | remote dependency issue         | retry count and whether fallback exists | repeated blind retries                           |
| validator or parser fails after an edit                        | `verification-failed`                       | likely real defect in the slice | failing check and follow-up fix         | treating the failure as noise                    |
| agent handoff loses context or uses wrong file set             | `usage-error` or `unknown`                  | workflow setup issue            | missing context and corrected handoff   | expanding agent scope without grounding          |
| missing local tool like `php`, `gh`, or `rg`                   | `environment-missing`                       | local limitation                | missing tool and alternative path       | writing docs that assume universal availability  |

## Logging Rule

- For normal task execution, include failure records in the final summary when any command failed.
- For recurring workflow failures or policy changes, update the durable docs in `docs/ai/` in the same slice.
- When a command succeeds on retry, keep the original failure in the record and note why the retry was valid.
- For behavior-changing agent workflows, include regression evidence and replay notes from `docs/ai/capabilities/evaluation-and-regression/` in the task summary.

## Minimal Record Example

```text
command: php tools/ai/validate-ai-config.php
intent: validate the live AI workflow layer after doc edits
workdir: C:\xampp\htdocs\app-configs
risk: low
mode: read-only
result: exit 1
category: verification-failed
cause: broken path reference in docs/ai/workflow.md
reattempted: corrected command
resolution: fixed
correct usage: fix the referenced path, then rerun the same validator
avoid next time: do not add new canonical doc links without updating the target file first
```
