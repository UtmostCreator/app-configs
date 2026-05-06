# Evaluation And Regression Capability

## Purpose

Make agent behavior testable so quality does not depend only on ad hoc review.

## Trigger When

- prompts, policy, or tool routing behavior changes
- a task introduces or changes agent decision logic
- risky workflows need repeatable quality checks before merge
- failures need replay expectations instead of one-off debugging

## Workflow

1. define the behavior change and risk level
2. select or add relevant golden tasks
3. define expected and forbidden tool behavior
4. run regression checks for affected golden tasks
5. apply human-review triggers for medium/high-risk outcomes
6. record pass/fail evidence and replay notes

## Read Next

- `GOLDEN_TASKS.md` for reusable regression scenarios
- `REPLAY_RULES.md` for rerun and replay expectations
- `HUMAN_REVIEW_RULES.md` for escalation triggers

## Output Contract

- selected golden tasks and outcomes
- expected versus forbidden tool behavior
- regression evidence and result
- replay guidance for failures
- human-review decision when required

## Acceptance Criteria

- behavior-changing agent work has explicit regression expectations
- risky flows define forbidden tool behavior and review triggers
- failed runs include replay guidance
- optimization claims are backed by evaluation evidence
