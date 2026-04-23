# Agent Operations

Use this document when the task involves agent loops, tool use, RAG, multi-agent handoffs, or security review of AI-assisted workflows.

## Core Model

Operate agentic systems in this order:

1. observability
2. evaluation
3. optimization

Do not optimize a workflow you cannot trace, and do not trust a trace alone as proof that the behavior was correct.

## Observability

For agentic workflows, capture enough evidence to reconstruct what happened:

- end-to-end trace duration
- agent-to-agent handoff latency when staged roles are involved
- tool execution latency for external systems
- cost per request or per task
- exact tool calls, retries, and stop conditions

If a workflow can mutate external state, treat missing traceability as a release blocker.

## Evaluation

Measure whether the workflow was actually good, not only whether it ran:

- task completion rate
- guardrail violation rate
- factual accuracy against a trusted source
- human-review quality checks for regulated or high-impact work
- first-pass success rate when retries or escalation are part of the flow

Prefer evaluation against repository truth, source documents, or live system evidence over self-grading.

## Optimization

Only tune after observability and evaluation exist:

- prompt token efficiency
- retrieval precision at `k`
- handoff success rate
- flow-step efficiency and avoidable loop overhead

Optimization without grounded evaluation usually just makes the wrong behavior cheaper.

## Shift-Left Code Risk

Code risk should surface where it is created, reviewed, and released:

- IDE or editor while code, config, or prompts are being written
- pull request review before merge
- CI or release validation before deployment

For AI-assisted coding, treat insecure snippets, unsafe dependencies, and risky configuration as inputs to catch early, not only as late security findings.

## Identity And Access

Avoid super-agents. Prefer a maturity path like this:

1. foundation: non-human identity, basic delegation, audit logging
2. enhanced: agents treated as first-class identities, ephemeral credentials, fine-grained contextual access, real-time detection
3. adaptive: continuous authentication, risk-based reauthentication, real-time revocation

Default posture:

- use task-scoped, time-bound credentials
- preserve on-behalf-of delegation chains when an agent acts for a user or another agent
- log who acted, with what rights, and on whose behalf
- escalate when a workflow needs long-lived credentials or broad cross-system access

## Common Agent Risks

Treat these as recurring review categories:

- goal hijack through prompt injection hidden in docs, web pages, tickets, or RAG sources
- tool misuse from ambiguous instructions or excessive privileges
- identity and privilege abuse when agents inherit too much trust
- agentic supply chain risk from plugins, registries, prompt packs, or MCP servers loaded at runtime
- unexpected code execution from generated code paths or unsafe tool chaining
- memory or context poisoning that persists across tasks
- insecure inter-agent communication, spoofing, or replay
- cascading failures across delegated workflows
- human trust exploitation where confident output bypasses verification
- rogue or drifting behavior over time

## Architecture Choices

Choose the stack by the job:

- use `RAG` when documents are the source of truth
- use an `ADK` or tool-driven agent workflow when the system must act through a repeatable procedure
- use a hybrid when the workflow must both reason over documents and take actions

Short rule:

- `RAG` answers questions about grounded data
- `ADK` does things through steps and tools
- hybrid systems do both and need tighter guardrails

For specialized domains, ground the workflow in trusted documents first, then let agents act.

## Role Design

Common multi-agent roles:

- planner
- doer or implementer
- tool operator
- learner or retriever
- critic or evaluator
- supervisor
- presenter

Add roles only when isolation, expertise, or verification quality improves. Do not split one simple workflow into many agents without a clear safety or quality reason.

## Multimodal Note

Do not assume multimodal support unless the runtime proves it.

- text-first surfaces should say so explicitly
- image support does not imply robust video support
- video tasks may need temporal reasoning, not just sampled frames

When support differs by runtime surface, document the fallback instead of implying parity.
