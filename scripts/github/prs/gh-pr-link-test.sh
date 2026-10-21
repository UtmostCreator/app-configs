#!/usr/bin/env bash
# gh-pr-link-test.sh — test all link rendering modes so you can pick the one
# that produces clickable links in your terminal/renderer.
#
# Usage:
#   bash ~/scripts/github/prs/gh-pr-link-test.sh
#
# Each section is separated by a clear header.  Run this in your live Ghostty
# terminal and Ctrl+click each "link" variant to find which one works.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRW_PORTAL_DIR="${PRW_PORTAL_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)/prw-portal}"

SAMPLE_PR_URL="https://github.com/example-org/example-repo/pull/123"
SAMPLE_JIRA_URL="https://example.atlassian.net/browse/ABC-123"

sep() { printf '\n%s\n%s\n%s\n\n' "$(printf '═%.0s' {1..70})" "  $1" "$(printf '═%.0s' {1..70})"; }

# ─────────────────────────────────────────────────────────────────────────────
sep "OPTION A — raw markdown (no glow): plain https:// URLs in table + Links section below"
echo "(best Ghostty auto-detect: URLs clickable natively)"
echo ""
echo "The legacy awk formatter has been removed. Use: prw-md / prw-md-glow"
echo "or: bash $PRW_PORTAL_DIR/bin/prw render term <cache-prs.json>"

# ─────────────────────────────────────────────────────────────────────────────
sep "OPTION B — glow render of Option A (table labels + Links section outside table)"
echo "(Glamour renders [label](url) outside tables as OSC 8 hyperlinks)"
echo ""
if command -v glow >/dev/null 2>&1; then
  printf '[%s](%s) · [%s](%s)\n' "example-repo#123" "$SAMPLE_PR_URL" "ABC-123" "$SAMPLE_JIRA_URL" | glow - -w 0 -n
else
  echo "  glow not installed — skipping"
fi

# ─────────────────────────────────────────────────────────────────────────────
sep "OPTION C — OSC 8 terminal hyperlinks directly (bypasses markdown rendering)"
echo "(pure terminal hyperlinks; no markdown, short visible label)"
echo ""
osc8() { printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "$1" "$2"; }
printf '  PR link:   '; osc8 "$SAMPLE_PR_URL"   "example-repo#123"
printf '  Jira link: '; osc8 "$SAMPLE_JIRA_URL" "ABC-123"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
sep "OPTION D — raw plain https:// URL text (most basic; terminal auto-detect)"
echo "(no label, just URL — Ghostty and most modern terminals make these clickable)"
echo ""
echo "  PR:   $SAMPLE_PR_URL"
echo "  Jira: $SAMPLE_JIRA_URL"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
sep "OPTION E — glow diagnostic: check if OSC 8 escapes survive glow"
echo "(look for \\\\033]8 in the output — if present, OSC 8 links are being emitted)"
echo ""
if command -v glow >/dev/null 2>&1; then
  printf '[open PR](%s)\n' "$SAMPLE_PR_URL" | glow - | cat -v | head -5
else
  echo "  glow not installed — skipping"
fi

echo ""
printf '─%.0s' {1..70}
printf '\nDone. Tell me which option (A/B/C/D) produced clickable links in Ghostty.\n'
