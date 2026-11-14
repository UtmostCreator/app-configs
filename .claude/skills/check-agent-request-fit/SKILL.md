---
name: check-agent-request-fit
description: Checks a parseable agent definition against the original request for missing requirements and excess scope, tools or autonomy. Reports corrections without editing or running it.
---

## What I Do

I judge request-to-definition fit, not syntax: given an agent definition that already parses in the host's format, plus the original user request, I decide whether it does what was requested without exceeding it. I return a verdict with exact fixes; I never edit the definition and never run the agent.

## When To Use Me

- after the definition parses (or the project's declared validator passed) and before a human approves it
- when the agent can use tools, write files, call APIs, search the web, or act across steps without confirmation
- to check least privilege and autonomy against the stated purpose
- optional for text-only agents that only read and reply

## Read Alongside

- `agent-definition-review` — the scoring rubric for a definition
- the host's or the project's permission settings, when the definition relies on them

## Steps

1. Confirm the definition parses in the host's format (or the project's validator passed) and the original user request is present. If the request is missing, stop and ask for it; never infer intent from the definition alone.
2. Request fit: does the definition do what the request asks, no more and no less? Flag instructions that are too broad, off-target or internally conflicting.
3. Request-bounded privilege: check every tool and permission the definition sets or relies on against the stated purpose; anything the request does not justify is a finding to reduce, never expand.
4. Request-bounded autonomy: check that file writes, network access, delegation and the points where the agent must stop for human approval are justified by the requested outcome and risk; excess autonomy is a mismatch.
5. Confirm the definition's success criteria are specific and checkable, then issue one verdict (MATCHES, MATCHES WITH NOTES or MISMATCH) with the exact changes required before use.

## Output

- a request-versus-definition fit assessment and any conflicts or ambiguities
- overpower findings across tools, permissions and autonomy
- one verdict: MATCHES | MATCHES WITH NOTES | MISMATCH
- the exact reductions or fixes required before approval

## Gotchas

- parsing is not the same as safe: never pass an overpowered agent just because it parses
- a limit stated only in the body is guidance, not enforcement; say so rather than counting it as a control
- use `unknown` when the request does not prove a needed detail, and stop rather than guess intent
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
