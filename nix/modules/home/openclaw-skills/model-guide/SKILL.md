---
name: model-guide
description: Show every chat model this bot can switch to, with its command, defaults, limits and when to use it. Use when the user asks which models exist, which one to pick, or how to switch.
---

When this skill is invoked, send the guide below to the user as one message,
exactly as written. Then call `session_status` and add one last line:
`Now answering: <provider/model> (thinking: <level>)`.

Do not add models that are not listed here, and do not change the numbers.

---

**Models in this chat**

Send a command on its own to switch **this chat**. It stays until you switch
again. `/model default` goes back to the bot default.

**GPT (ChatGPT subscription)**

`/gpt` → `openai/gpt-6.1-sol` ⭐ bot default, thinking medium
- Context 500k (up to 872k with long context), output up to 128k
- Strongest GPT here. Pick it for architecture, review, planning across
  several steps, and orchestration.
- glyphbrace: the Codex choice for almost every role in Balanced and
  Maximum capability.

`/luna` → `openai/gpt-6-luna`
- Context 272k (up to 872k), output up to 128k
- Lighter and faster than Sol. Pick it for quick questions, drafting, and
  research where speed matters more than depth.
- glyphbrace: the Codex choice for most roles in Minimum cost, plus
  plan-writer and researcher in Balanced.

`/astra` → `openai/gpt-6-astra`
- Context 272k (up to 872k)
- OpenClaw's recommended general model and this bot's previous default.
  Pick it to compare answers with Sol.
- glyphbrace: only a Copilot fallback (architect, release-auditor).

**Claude (Claude Code login, uses your Claude plan limits)**

`/claude` → `anthropic/claude-sonnet-5-5` ⭐ Claude default and bot
fallback, thinking medium
- Context 1M, output up to 128k
- Balanced coding and writing. Pick it for most Claude work.
- glyphbrace: the Claude choice for most roles in Minimum cost and
  Balanced.
- Relative cost: 200 / 1000 credits per 1M input / output tokens.

`/opus` → `anthropic/claude-opus-5-5`
- Context 1M, output up to 128k
- Deeper reasoning than Sonnet. Pick it for hard design, review and audits.
- glyphbrace: architect, orchestrator, reviewer and release-auditor in
  Balanced, and most roles in Maximum capability.
- Relative cost: 400 / 2000.

`/fable` → `anthropic/claude-fable-5-1`
- Context 1M, output up to 128k
- Highest tier. Pick it for the hardest problems when cost and speed do
  not matter.
- glyphbrace: fallback only, in Maximum capability (architect,
  orchestrator, reviewer, release-auditor and others).
- Relative cost: not listed.

`/haiku` → `anthropic/claude-haiku-5-5`
- Context 1M, output up to 128k
- Fastest and cheapest. Pick it for short, simple tasks.
- glyphbrace: plan-writer in Minimum cost and Balanced.
- Relative cost: 10 / 50.

**Effort and status**
- `/think low|medium|high|xhigh` changes thinking for this chat. `/think
  default` clears it.
- `/status` shows the model and thinking level in use.
- `/models` lists every model, including ones without a command.
- If the default model fails, the bot falls back from GPT-6.1 Sol to
  Claude Sonnet 5.5.

Relative costs are GitHub Copilot list prices from 2026-10-19 and are only
for comparison. This bot runs on your ChatGPT and Claude subscriptions, not
on Copilot credits. Context sizes come from OpenClaw's model catalog and
glyphbrace `assets/models.yaml`.
