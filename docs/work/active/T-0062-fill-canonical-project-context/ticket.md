Source: local

# T-0062: Canonical project context pages are still unfilled templates (docs)

Status: open (verified 2026-11-21 with qmd and grep; not started)
Relates to: T-0033

Written 2026-11-21 against main cf53949 from a documentation audit.

## Finding (verified)
`docs/shared/overview/project-context.md` (lines 23-32: project, purpose, type, language, runtime, stack, package manager, targets, test and build commands), `project-stack.md` and `conventions.md` still hold `[OWNER_TO_FILL]`, and `project-interaction.md:19` holds generic placeholders such as `[CANONICAL_DOC_OWNER_REPOSITORY]`. Their metadata says `kind: template`, `status: template`, yet agents are told to read them as project context. They are Glyphbrace-seeded and owner-editable ("seeded once and yours to edit"); the copies under `docs/shared/templates/` stay as templates.

## Acceptance criteria
- AC1: replace each placeholder with a verified app-configs fact, or mark the page as not authoritative.
- AC2: record the real stack: Bash, PowerShell, Nix and Home Manager, chezmoi, mise, Lefthook, bats and Pester, and the CI commands (`ops/ci.sh`).
- AC3: name the entry points (`ops/install.sh`, `ops/update-all.sh`, `ops/readiness.sh`), the host profiles (linux-desktop, linux-cli, wsl, macos), the ownership boundaries and the verification commands from AGENTS.md.
- AC4: drop irrelevant sample assumptions (frontends, databases, APIs, shared domain repositories) from project-interaction.md, or state that app-configs has none.
- AC5: metadata distinguishes these project documents from the templates; `docs/shared/templates/` is unchanged.
- AC6: a check (bats or validate-config) rejects unresolved placeholder tokens in `docs/shared/overview/`.
