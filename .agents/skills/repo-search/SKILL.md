---
name: repo-search
description: Use when a repository task needs bounded file discovery, reference tracing, or wiring evidence; not for ownership assessment or root-cause diagnosis.
---

# Repository Search

Use this skill when a task needs bounded file discovery, reference or usage
tracing, or evidence of how something is wired. Search with the host's native
tools: its search and read tools, `rg`, `git grep` and `fd` where installed.

## Choose This Skill When

- You need to locate files by name, pattern, or content.
- You are tracing references, dependencies, or usage of a symbol.
- You are verifying repository wiring or configuration.

## Choose Another Skill When

- Use `project-context` when you need to understand ownership, boundaries, and risk before planning work.
- Use `repo-investigation` when you are diagnosing a specific observed problem or bug.
- Use `select-repo-commands` when you are choosing which repository command to run or whether it needs approval.

## Before Searching

Identify the query, the relevant path boundary, and the result you need. Run
`git status --short` only when the query concerns uncommitted changes and the
request did not already give that scope.

## Search Order

Pick the smallest surface that can answer the question. These are
alternatives, not a sequence:

- uncommitted changes: `git diff --name-only`, then search those files;
- staged changes: `git diff --cached --name-only`;
- the tracked tree: `git grep -n -- '<pattern>'` or `rg -n '<pattern>'`;
- a code graph tool such as codebase-memory, when available: call
  `list_projects` first, pass the project name of the entry with the deepest
  root that contains the working directory as `project` on every call (a name
  from that list, never a folder path), and never index a temporary or
  scratch directory. When no entry matches, continue without the graph and
  say so.

Widen only when the narrow result is insufficient, and widen by intent: docs,
tests, configuration, or a structural pattern. Do not run every kind of search
to manufacture duplicate evidence. Run one search per tool call and choose the
next from its result.

Keep searches source-oriented: constrain by directory and file type, and skip
`vendor/`, `node_modules/`, `.git/`, `dist/`, `build/`, `coverage/`, `.cache/`,
large lockfiles, generated bundles and media or archives unless the task is
about them.

A broad sweep for unsafe patterns across the whole repository needs the user's
approval first.

## Reading A Hit

When a result gives a file and line, read a bounded range around it with the
host's read tool (a line offset and limit) rather than the whole file. Check
the path against secret files (`.env`, `.env.*`, `*.pem`, `*.key`, `id_rsa*`,
`secrets.*`, `credentials.*`) before opening it, and do not open a match.
Avoid unbounded `cat`, `sed` or `awk` reads: they waste context and can surface
secrets.

## Usage Tracing

Before adding logic, changing a public contract, or claiming a symbol is
unused, search for it with a fixed-string query (`rg -nF '<symbol>'` or
`git grep -nF '<symbol>'`). Account for dynamic references (reflection,
string-built names, configuration keys) before calling something unused.

A size or token-cost estimate of a path does not trace symbols; never mistake
it for a usage map.

Report the closest reuse candidate and substantial behavioural or
responsibility overlap. State numeric similarity only when a tool measured it,
naming the method and scope; text similarity alone does not establish
behavioural equivalence.

## Verification

When a change relies on repository search or wiring evidence, identify the
smallest relevant verification command from the project's instructions, build
files or CI configuration; do not assume a toolchain.

Execute it only when the calling agent has authority to run it and the
environment satisfies its safety constraints. Otherwise, or if a required
tool is unavailable, report the command as recommended but not run, with the
reason. Discovery and reference tracing alone do not prove that a behavioural
change works.

## Ask First

Never read secrets; request a sanitised example or an owner handoff instead.
Ask before a repository-wide unsafe-pattern sweep, overriding
output limits, running mutating or installer tools, destructive git, editing
generated files, or packing the repository into a context bundle.

Return evidence with exact commands, status, files and lines, gaps, and the
safest next step.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
