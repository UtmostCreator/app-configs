---
id: INC-EXAMPLE-MEMORY-COMMAND-REVIEW
title: Fictional document export memory failure — Command review
type: incident-evidence
domain: incident-history
status: illustrative
owner: platform
updated: undated
tags: [fictional-example, command-review, round-trips, memory]
symptoms: [slow investigation, memory limit, repeated route failures]
---

# Command review

> This fictional review demonstrates how to reduce repeated collection. It does not report a real investigation or measured response time.

## Shortest evidence path

| Stage | Source or command | Question answered |
| --- | --- | --- |
| A | Search approved incident records and supplied tracker exports | Is the route class or signature already known? |
| B | Run `incident-bundle.sh` once over a reviewed evidence interval | Are clock, service state, resource pressure, log coverage and runtime configuration known? |
| C | Run `fatal-correlate.py` against complete synthetic access and error inputs | Do fatal bursts and route failures have a candidate temporal relationship? |
| D | Inspect the relevant implementation and reproduce one request in an isolated fixture | Which phase consumes memory, and does a controlled scope change affect it? |

## Review rules

- Merge repeated commands that answer the same question into one bounded collection.
- Do not sample narrow intervals before confirming the full input coverage.
- Do not treat a route correlation, user-agent label or empty output as proof beyond its documented limits.
- Defer production changes until the approval and rollback gates are complete.
- Record unknown evidence and the next discriminating observation instead of filling gaps with assumptions.

Use the [command-review template](../_template/command-review.md) for real incidents, and remove identifying details before sharing any record.
