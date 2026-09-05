import type { Plugin } from "@opencode-ai/plugin"

// OpenCode -> OTel Collector tracing plugin.
//
// Exports tool-call spans (and a best-effort per-turn root span) from OpenCode to
// an OTel Collector over OTLP/HTTP JSON — the same wire format and endpoint proven
// working by the ai-monitoring repo's own smoke tests
// (docs/observability/VERIFY.md, docs/observability/CLAUDE_CODE_TELEMETRY.md).
// The Collector fans this out to Phoenix (full detail, local) and Langfuse
// (redacted copy, cloud) if that repo's split-pipeline collector config is in use.
//
// STATUS: NOT YET VERIFIED AGAINST A REAL RUNNING OPENCODE SESSION. OpenCode's
// public docs list plugin event/hook *names* (`tool.execute.before`,
// `tool.execute.after`, `session.idle`, etc.) but not their full payload schemas.
// This plugin was written defensively against that gap (never throws, degrades
// gracefully if an expected field is missing/renamed) but the exact fields below
// — especially whether `tool.execute.before`/`tool.execute.after` share the same
// `input` object reference, and what `session.idle`'s event payload actually
// contains — are assumptions, not confirmed facts. If spans don't appear, or
// appear with unexpected/empty attributes, that is the most likely cause: add a
// temporary `console.error(JSON.stringify(input/output/event))` at the relevant
// hook to see the real shape, then adjust the field access here to match.
//
// Multi-repo separation: this plugin automatically derives a per-repo project
// name from the OpenCode `directory`/`project` context it already receives — no
// manual per-repo environment variable exports needed (unlike the Claude Code
// OTel setup, which requires OTEL_RESOURCE_ATTRIBUTES set per shell/repo). Set
// OPENCODE_OTEL_PROJECT to override the derived name if you ever need to.

const OTLP_ENDPOINT = process.env.OPENCODE_OTEL_ENDPOINT || "http://localhost:4318/v1/traces"
const PROJECT_OVERRIDE = process.env.OPENCODE_OTEL_PROJECT
const SEND_TIMEOUT_MS = 1500
// Opt-in, off by default — mirrors Claude Code's OTEL_LOG_TOOL_DETAILS pattern. When enabled,
// captures the tool call's raw arguments (e.g. a Bash command string, a file path) as a `tool.args`
// attribute. `tool.error` (the failure message, if any) is always captured regardless of this flag
// — a message alone is lower-risk than full arguments, but see the redaction note below either way.
// BOTH `tool.args` and `tool.error` are in otel/collector-config.yaml's redact_for_langfuse delete
// list — Phoenix (local) gets them, Langfuse (cloud) does not. If you add this plugin's attributes
// to a *different* Collector config that doesn't have that redaction list, these will reach
// wherever that Collector sends traces, unfiltered.
const CAPTURE_ARGS = process.env.OPENCODE_OTEL_CAPTURE_ARGS === "1"
const MAX_ATTR_LENGTH = 2000

function hexId(byteLength: number): string {
  const bytes = new Uint8Array(byteLength)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")
}

function nowNs(): bigint {
  return BigInt(Date.now()) * 1_000_000n
}

type AttrValue = string | number | boolean

function toOtlpAttributes(attrs: Record<string, AttrValue>) {
  return Object.entries(attrs)
    .filter(([, v]) => v !== undefined && v !== null)
    .map(([key, value]) => {
      if (typeof value === "number") {
        return Number.isInteger(value)
          ? { key, value: { intValue: String(value) } }
          : { key, value: { doubleValue: value } }
      }
      if (typeof value === "boolean") return { key, value: { boolValue: value } }
      return { key, value: { stringValue: String(value) } }
    })
}

async function sendSpan(opts: {
  traceId: string
  spanId: string
  parentSpanId?: string
  name: string
  startNs: bigint
  endNs: bigint
  attributes: Record<string, AttrValue>
  repoName: string
}) {
  const payload = {
    resourceSpans: [
      {
        resource: {
          attributes: [
            { key: "service.name", value: { stringValue: "opencode" } },
            // Phoenix routes raw-OTLP into a project via this attribute — confirmed
            // empirically against a running Phoenix instance (2026-07-12), not
            // assumed from docs.
            { key: "openinference.project.name", value: { stringValue: opts.repoName } },
            // Langfuse's equivalent segmentation dimension (filterable "environment"
            // within one project) — per Langfuse's own OTel docs.
            { key: "deployment.environment.name", value: { stringValue: opts.repoName } },
          ],
        },
        scopeSpans: [
          {
            scope: { name: "opencode.otel-tracing-plugin", version: "0.1.0" },
            spans: [
              {
                traceId: opts.traceId,
                spanId: opts.spanId,
                ...(opts.parentSpanId ? { parentSpanId: opts.parentSpanId } : {}),
                name: opts.name,
                kind: 1,
                startTimeUnixNano: opts.startNs.toString(),
                endTimeUnixNano: opts.endNs.toString(),
                attributes: toOtlpAttributes(opts.attributes),
              },
            ],
          },
        ],
      },
    ],
  }

  try {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), SEND_TIMEOUT_MS)
    await fetch(OTLP_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    }).catch(() => undefined) // Collector unreachable — never break the actual session over this.
    clearTimeout(timer)
  } catch {
    // Belt-and-braces: nothing in this plugin should ever throw into OpenCode's
    // own event loop, no matter what fetch/AbortController do.
  }
}

export const OtelTracingPlugin: Plugin = async ({ directory, project }) => {
  const derivedFromProject =
    project && typeof project === "object" && "name" in (project as Record<string, unknown>)
      ? (project as Record<string, unknown>).name
      : undefined
  const repoName =
    PROJECT_OVERRIDE ||
    (typeof derivedFromProject === "string" && derivedFromProject) ||
    directory.split("/").filter(Boolean).pop() ||
    "opencode-unknown-repo"

  // One trace per "turn": starts lazily at the first tool call, exported (as a
  // root span covering that turn) when session.idle fires. If session.idle never
  // fires as expected, the root span is simply never sent — individual tool spans
  // below still export independently the moment each tool call finishes, so the
  // most valuable data (what ran, how long, success/fail) is not blocked on this
  // grouping working correctly.
  let traceId: string | undefined
  let rootSpanId: string | undefined
  let turnStartNs: bigint | undefined

  // Tool-call start times, keyed defensively: prefer a real call id if the plugin
  // API exposes one; otherwise fall back to a per-tool-name stack (imperfect if
  // many calls to the SAME tool name run concurrently — see STATUS note above).
  const startsByKey = new Map<string, bigint>()
  const stackByToolName = new Map<string, bigint[]>()
  const argsByKey = new Map<string, unknown>()

  // Assistant-message ids already exported as an LLM span. `message.updated` fires
  // repeatedly as a message streams and again once it completes, so we dedupe on id
  // and only emit once, when the message is finished (time.completed set).
  const emittedMessageIds = new Set<string>()

  function truncate(s: string): string {
    return s.length > MAX_ATTR_LENGTH ? s.slice(0, MAX_ATTR_LENGTH) + "...(truncated)" : s
  }

  function ensureTurn() {
    if (!traceId) {
      traceId = hexId(16)
      rootSpanId = hexId(8)
      turnStartNs = nowNs()
    }
  }

  return {
    event: async ({ event }: { event: any }) => {
      if (event?.type === "session.idle" && traceId && rootSpanId && turnStartNs) {
        await sendSpan({
          traceId,
          spanId: rootSpanId,
          name: "opencode.turn",
          startNs: turnStartNs,
          endNs: nowNs(),
          attributes: { repo: repoName },
          repoName,
        })
        traceId = undefined
        rootSpanId = undefined
        turnStartNs = undefined
      }

      // LLM span: one per completed assistant message. This is what makes token/cost
      // data show up in Phoenix — the tool/turn spans above carry none. Field shapes
      // (AssistantMessage.tokens/cost/modelID/providerID, EventMessageUpdated.properties.info)
      // are taken from @opencode-ai/sdk's generated types, not guessed. Attributes use the
      // canonical OpenInference `llm.token_count.*` names Phoenix reads directly, so no
      // Collector transform is needed for these (unlike Claude Code's `input_tokens` names).
      if (event?.type === "message.updated") {
        const info = event?.properties?.info
        if (
          info &&
          info.role === "assistant" &&
          info.time?.completed &&
          typeof info.id === "string" &&
          !emittedMessageIds.has(info.id)
        ) {
          emittedMessageIds.add(info.id)
          ensureTurn()
          const tokens = info.tokens ?? {}
          const cache = tokens.cache ?? {}
          const input = Number(tokens.input ?? 0)
          const output = Number(tokens.output ?? 0)
          const reasoning = Number(tokens.reasoning ?? 0)
          const cacheRead = Number(cache.read ?? 0)
          const cacheWrite = Number(cache.write ?? 0)
          // `prompt` is uncached input only (OpenInference convention); cached portions
          // ride in prompt_details.* so cache-aware pricing stays accurate. `total` is full
          // throughput = uncached input + completion + cache read + cache write — matching
          // the Collector's Claude Code total convention. reasoning is a subset of output,
          // so it is reported separately, never added into total.
          const attributes: Record<string, AttrValue> = {
            "openinference.span.kind": "LLM",
            "llm.model_name": String(info.modelID ?? "unknown"),
            "llm.provider": String(info.providerID ?? "unknown"),
            "llm.token_count.prompt": input,
            "llm.token_count.completion": output,
            "llm.token_count.prompt_details.cache_read": cacheRead,
            "llm.token_count.prompt_details.cache_write": cacheWrite,
            "llm.token_count.total": input + output + cacheRead + cacheWrite,
            repo: repoName,
          }
          if (reasoning > 0) attributes["llm.token_count.completion_details.reasoning"] = reasoning
          if (typeof info.sessionID === "string") attributes["session.id"] = info.sessionID
          if (typeof info.cost === "number") attributes["opencode.cost_usd"] = info.cost
          if (info.finish) attributes["llm.finish_reason"] = String(info.finish)
          if (info.error) {
            const em =
              (info.error?.data && typeof info.error.data.message === "string" && info.error.data.message) ||
              info.error?.name
            if (em) attributes["error.message"] = truncate(String(em))
          }
          const startNs =
            typeof info.time?.created === "number" ? BigInt(info.time.created) * 1_000_000n : nowNs()
          const endNs =
            typeof info.time?.completed === "number" ? BigInt(info.time.completed) * 1_000_000n : nowNs()
          await sendSpan({
            traceId: traceId!,
            spanId: hexId(8),
            parentSpanId: rootSpanId,
            name: "opencode.llm_request",
            startNs,
            endNs,
            attributes,
            repoName,
          })
        }
      }
    },

    "tool.execute.before": async (input: any, output?: any) => {
      ensureTurn()
      const toolName = String(input?.tool ?? "unknown")
      const callId = input?.callID ?? output?.callID
      const start = nowNs()
      if (callId) {
        startsByKey.set(String(callId), start)
      } else {
        const stack = stackByToolName.get(toolName) ?? []
        stack.push(start)
        stackByToolName.set(toolName, stack)
      }
      if (CAPTURE_ARGS && output?.args) {
        argsByKey.set(String(callId ?? `${toolName}:${start}`), output.args)
      }
    },

    "tool.execute.after": async (input: any, output?: any) => {
      if (!traceId || !rootSpanId) return
      const toolName = String(input?.tool ?? "unknown")
      const callId = input?.callID ?? output?.callID
      const argsKey = String(callId ?? `${toolName}:pending`)
      let startNs: bigint | undefined
      if (callId && startsByKey.has(String(callId))) {
        startNs = startsByKey.get(String(callId))
        startsByKey.delete(String(callId))
      } else {
        const stack = stackByToolName.get(toolName)
        startNs = stack?.pop()
      }
      if (!startNs) startNs = nowNs() // fallback: zero-duration span rather than dropping it

      // Best-effort: exact field names for failure state/message are unconfirmed (see STATUS
      // note) — absent/undefined is treated as success; several plausible field names are tried
      // for the error message so this degrades gracefully if the real one differs.
      const errorVal = output?.error ?? output?.isError
      const isFailure = Boolean(errorVal)
      const errorMessage =
        typeof errorVal === "string"
          ? errorVal
          : errorVal && typeof errorVal === "object" && "message" in errorVal
            ? String((errorVal as { message: unknown }).message)
            : undefined

      const attributes: Record<string, AttrValue> = {
        "tool.name": toolName,
        repo: repoName,
        success: !isFailure,
      }
      if (errorMessage) attributes["tool.error"] = truncate(errorMessage)
      if (CAPTURE_ARGS) {
        const args = argsByKey.get(argsKey)
        argsByKey.delete(argsKey)
        if (args !== undefined) {
          try {
            attributes["tool.args"] = truncate(JSON.stringify(args))
          } catch {
            // args not JSON-serializable — skip rather than throw.
          }
        }
      }

      await sendSpan({
        traceId,
        spanId: hexId(8),
        parentSpanId: rootSpanId,
        name: `opencode.tool.${toolName}`,
        startNs,
        endNs: nowNs(),
        attributes,
        repoName,
      })
    },
  }
}
