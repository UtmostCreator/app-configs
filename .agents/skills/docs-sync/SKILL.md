---
name: docs-sync
description: Assesses documentation impact or audits coverage read-only; sync mode updates documentation to match a finished change.
---

## Purpose

Keep documentation true to the code without writing prose about behaviour that
is not finished. Work in exactly one mode:

- `assess`: list what documentation a change may affect. Write nothing.
- `sync`: update the documentation to match a finished change.
- `audit`: compare the final change with the documentation and report gaps.
  Write nothing.

## Inputs

- The change: a commit, a range or the current diff, named exactly.
- For `sync`, the change must be finished: implemented and verified, or
  confirmed by the user. Document what the code does now, not what is planned.
  If the change moves while you work, start again from its new state.
- The project's instructions on where documentation lives and who owns it.

## Where Documentation Lives

Look, in this order:

1. The locations the project's instructions name.
2. `docs/`, when the project has one.
3. README files at the root and next to the changed code.
4. Other documentation the project already keeps: a changelog, examples,
   sample configuration, command help text, API reference, doc comments on
   changed public symbols, and the project's own instruction files.

Find the documents that cover the changed surface by searching them for its
names: identifiers, commands, flags, configuration keys, environment variables,
endpoints, file paths, and the old names of anything renamed, moved or
removed.

- Edit the source of generated documentation and run its generator; never
  hand-edit generated output.
- In a file installed by Glyphbrace, write only between its `glyphbrace:user`
  markers, or change the project's own source for it.
- If documentation is needed but has no existing home or owner, stop and ask
  the user where it belongs. Never create a new documentation root as a
  convenience.

## What To Check

For each changed surface, check whether the documentation:

- states behaviour, defaults, limits, outputs or errors the change altered;
- names a path, command, flag, key, endpoint or symbol that was renamed,
  moved or removed;
- shows an example, snippet or sample configuration that no longer works;
- describes setup, installation, upgrade or migration steps the change affects;
- leaves a new user-visible behaviour, option or contract undocumented;
- links to something that no longer exists.

Record each candidate as one of:

- `needed` — the change makes existing text wrong or leaves a new behaviour
  undocumented;
- `none` — the change needs no documentation;
- `not_applicable` — a candidate that turned out not to be affected;
- `blocked` — documentation is needed but there is no target or owner.

Never treat missing information as `none`.

## Sync Workflow

1. Confirm the change you are documenting by commit or diff, not by assuming
   the working tree is it.
2. Update only statements the change supports.
3. Preserve unrelated prose; correct or remove statements the change made
   wrong.
4. Do not edit production code, tests or configuration. If documentation can
   only be fixed by changing code, stop and report it.
5. For generated documentation, edit its source, run the project's generator,
   and list the source, the generator and the outputs it changed.
6. Confirm your edits touched only documentation paths and generated outputs
   of the generator you ran.
7. Resolve every `needed` item explicitly: done, or still open with the reason.
8. A documentation change is a change: it goes to review with the code.

## Audit

Compare the final change with the documentation. Report each statement the
change made wrong, each new behaviour left undocumented and each `needed` item
not resolved, with file and line. If the change moved after an earlier review,
the documentation needs checking again.

## Report

- the mode and the change it covers (commit, range or diff);
- the places searched, including any the project's instructions name;
- each candidate with file, its classification and a one-line reason;
- for `sync`: each file updated and what changed, and any generator run with
  its outputs;
- what still needs updating, with the reason and who could resolve it;
- each `blocked` item and the question for the user.

## Prohibitions

- Do not document planned or unimplemented behaviour.
- Do not redesign the implementation.
- Do not write in `assess` or `audit` mode.
- Do not invent ownership, targets or generated provenance.
- Do not mark a blocked or merely attempted item resolved.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
