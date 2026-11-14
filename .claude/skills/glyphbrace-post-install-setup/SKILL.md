---
name: glyphbrace-post-install-setup
description: After Glyphbrace installs or updates guidance, inspects installed files, records evidenced project facts in user sections, and reports checks and blockers. Not for dependency installation.
---

# Post-install setup

Guide the first safe pass after `glyphbrace install` or `glyphbrace update`:
confirm what landed, resolve the project facts the installed skills leave as
placeholders, and report installed-state checks separately from host discovery and application checks.

## Choose This Skill When

- Glyphbrace just installed or updated guidance in this repository.
- Installed skills still show `<TOKEN>`-style placeholders such as `<PROJECT_NAME>`.
- Installed files may have been edited or removed since the install.

## Workflow

1. Confirm what is installed. When the `glyphbrace` command is available, run
   `glyphbrace status --root <dir> --provider <claude|codex|copilot>` for each
   provider in use: it reports the installed state and exits 0 when nothing is
   pending. Otherwise list the host's directories (Claude Code `.claude/agents/`
   and `.claude/skills/`, Codex `.codex/agents/` and `.agents/skills/`, GitHub
   Copilot `.github/agents/` and `.github/skills/`).
2. List project facts still in placeholder form in installed files (search for
   `<[A-Z][A-Z0-9_]*>`). Glyphbrace performs no substitution, so these stay
   literal. Derive each value from repository evidence, leave anything unproven
   as `unknown` rather than inventing it, and record the values in the user
   section at the end of that skill file, which survives updates. An edit
   anywhere else in an installed file is reported as a conflict on the next
   update.
3. Check host discovery using the host's documented inspection or listing
   mechanism when available. Record the host version, what was discovered,
   and any missing evidence. A status check proves installed state, not that a
   host discovered or selected a skill.
4. Run an application check only when appropriate to the setup facts being
   resolved. A linter or test proves installation behaviour only when it
   actually exercises the installed guidance; report its scope separately.
5. Report installed-state evidence, host-discovery evidence, application
   checks and unresolved blockers separately. Mark unperformed discovery
   `unverified`; never infer it from a successful application test.

## Repair

- `--check` on `install` or `update` previews the run without writing anything.
- An installed file edited outside its user section is kept and reported as a
  conflict; `--resolve <path>=keep` keeps the edit and `--resolve <path>=replace`
  takes Glyphbrace's copy, saving the edited file under `.glyphbrace/local/replaced/`.
- A run interrupted part-way is recovered by the next Glyphbrace run on that root.
- `glyphbrace uninstall` removes unmodified owned content and keeps customised
  or modified files and everything it does not own.

## Output

- unresolved setup blockers
- files still needing human input: each placeholder, its derived value or
  `unknown`, and the file that proves it
- installed-state evidence: what `glyphbrace status` and the files show
- host-discovery evidence, or `unverified` when no discovery check ran
- application checks run, with their result and what each one exercised
- the safest next step

## Gotchas

- Do not treat broad application lint, typecheck or security findings as
  install failures unless the installed files actually caused them.
- Resolve each placeholder from evidence before a write-capable agent relies on
  it: an agent reading `<PRIMARY_TEST_COMMAND>` has no verification command.
  Record the resolved value in the user section; never rewrite the managed
  placeholder itself, or the next update reports a conflict.
- Edits outside an installed file's user section become conflicts on update;
  put local changes in the user section instead.
- An install carries only the agents and skills the kit ships and the optional
  skills selected; an absent agent is not a defect.

## Renamed Skills And Customisations

A renamed skill installs at a new path. An unchanged old copy retires, while
an old copy with user content or managed-body edits stays byte-identical and
may remain discoverable. Glyphbrace reports that retention on the transition
run; later updates do not inventory it again.

Review the old and new files, then copy applicable user-section content into
the replacement's user section. Do not copy the old managed body over the new
one. Resolve overlapping local rules deliberately and verify the host sees
the intended skill. Retire the old copy only with the user's authorisation;
there is no automatic transfer. The rename mapping is in Glyphbrace's usage
reference, under "Renamed skills and customisations".
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
