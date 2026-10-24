---
id: INC-TEMPLATE-COMMAND-REVIEW
title: Incident command review (template)
type: incident-evidence
domain: incident-history
status: template
owner: platform
updated: undated
tags: [incident, template, command-review, round-trips]
symptoms: []
---

# Command review

> [Incident archive](../README.md) · [Runbook index](../../README.md) · Feeds the [fast path](../../shared/fast-path.md)

Fill in at [RB-11/VAL-06](../../response/11-validation-review.md#val-06). Count every pasted production round, including failed and repeated ones. Anonymise commands.

**Full review** (all sections) when any of these holds: severity 1–2, a harmful or reverted action, a rejected hypothesis that was acted on, a recurrence of an archived pattern, or more than ten production rounds. **Short form** otherwise: the response-metrics table, the shortest path, and one promoted lesson (or "none").

## Response metrics

Use UTC times where recorded, otherwise sequence labels; unknown stays `unknown`. Retrospective "could have been" values are hypotheses until a [blind replay](../../shared/fast-path.md#keep-the-fast-path-honest) measures them.

| Metric | Actual | Could have been |
| --- | --- | --- |
| Impact start → first discriminating observation | `<time or round>` | `<round>` |
| Impact start → adequately supported explanation | `<time or round>` | `<round>` |
| Impact start → effective mitigation | `<time or n/a>` | `<time>` |
| Production rounds | `<n>` | `<n>` |
| Redundant rounds (no new evidence) | `<n>` | 0 |
| Hypotheses acted on and later rejected | `<list or none>` | none |
| Recovery validated against the recovery matrix | `<yes / no / n/a>` | yes |

## Shortest path in hindsight

| Round | Where (ticket / laptop / production) | Command | Answers |
| --- | --- | --- | --- |
| 0 | ticket | `<error tracker fields, archive search>` | `<what was already known>` |

## Round-by-round verdicts

Verdicts: **Keep** (right time), **Merge** (fold into a combined command), **Shorten** (narrower or more informative), **Drop** (should not have run).

| Round | What ran | Verdict | Better command or reason |
| --- | --- | --- | --- |
| 1 | `<command>` | `<verdict>` | `<replacement and why>` |

## Commands that returned misleading information

- `<command>`: `<why the output misled>`

## Time-to-answer

| Question | Answered at round | Could have been |
| --- | --- | --- |
| `<question>` | `<n>` | `<n>` |

Promote any new "Drop" pattern or reusable command to the [fast path](../../shared/fast-path.md) or a [command helper](../../shared/commands/README.md).

See also: [timeline](timeline.md) · [observations](observations.md) · [hypotheses](hypotheses.md) · [actions](actions.md) · [conclusions](conclusions.md) · [command review](command-review.md)
