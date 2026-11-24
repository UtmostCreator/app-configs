# AI Scripts

This directory holds the scripts listed below. Earlier revisions of this README described
a larger wrapper suite (`ai-search.sh`, `preview-file.sh`, `pack-context.sh`,
and others); none of those exist in this repository.

| Script          | Purpose                                                        | Run directly? |
| --------------- | -------------------------------------------------------------- | ------------- |
| `repo-stats.sh` | Per-file and per-directory line and size metrics (via `scc`)   | Yes           |

```bash
bash scripts/ai/repo-stats.sh [root] [options]   # --help lists the options
```

It needs Bash 4+, `scc` and `jq`, honours `.repomixignore`, `.ignore` and
`.gitignore`, writes only to stdout, and is read-only.

## Codex status line (opt-in)

`codex-statusline.mjs` mirrors the existing Claude Code footer using the experimental
Codex MCP status-line API (verified against the v0.171.0 schema). It groups model,
reasoning, project, branch, permissions, run state, context usage and remaining
tokens, consumed 5h/7d quotas and reset countdowns, live Git counts and input/output,
cache and cost metrics. Missing metrics are omitted; Git is read-only, cached for
five seconds, and bounded by two 200 ms command timeouts. No session log parsing,
network calls, or third-party packages. Requires Node.js 18+.

From the repository root:

```bash
node scripts/ai/codex-statusline.mjs --self-test
codex mcp add app_config_statusline -- node "$PWD/scripts/ai/codex-statusline.mjs"
```

Enable **Custom status line** in `/experimental`, restart Codex, start a new
conversation, then use `/statusline` → **Choose a status line provider** →
**app-configs · Claude-style status line**. Alternatively merge the keys in
[codex-statusline.toml.example](codex-statusline.toml.example) into existing
tables in `~/.codex/config.toml`, replacing the checkout path. Do not duplicate
TOML tables or overwrite unrelated settings.

The native fallback includes task progress, which the custom snapshot does not
currently expose. Claude-only agent identity, subagent rows, session duration and
PR review status are not inferred. Codex wraps the groups rather than reproducing
Claude's exact width-specific multi-row layout. Both use consumed quota percentages
in custom renderers; the native Codex fallback uses remaining percentages.

To revert, select the built-in provider in `/statusline` or set
`tui.status_line_provider = "default"` in the existing configuration. Remove the
MCP server with `codex mcp remove app_config_statusline` if no longer needed.

This is deliberately not managed by chezmoi yet: it leaves live configuration
and the existing Claude status line untouched. Verify in the real Codex TUI before
promoting it to a managed dotfile.
