---
name: select-repo-commands
description: Selects commands for tasks no domain skill owns. Prefers documented commands, respects wrappers and approval gates, and reports run versus unrun checks. Does not create automation.
---

# Repository Commands

Choose the narrowest command that answers the question, respect approval gates,
and never claim a check you did not run.

## Choose This Skill When

- Deciding which repository script or command to run for a task.
- Weighing whether a command needs approval before it runs.
- Reporting what was verified and what was not.

## Choose Another Skill When

- Use `repo-search` when you are locating files, tracing references, or verifying repository wiring.

## Selection Order

1. Prefer the narrowest read-only command that answers the request.
2. Prefer a command the repository already documents (its instructions,
   `Makefile`, `package.json` scripts, task runner, CI configuration) over an
   ad-hoc invocation.
3. When the repository's instructions require a wrapper, hook or task runner,
   do not silently replace it with a raw equivalent. Use a fallback only when
   the instructions permit one, and report the unavailable required command.
4. Confirm a command exists before citing it, but do not inventory the host's
   tooling as a startup ritual.
5. Escalate to a broader or mutating command only when the narrow one cannot
   answer.

An instruction to use a particular command is guidance. A repository that
needs it enforced uses its own hook or CI check.

## Approval Gate

Ask before anything that mutates state or broadens access: file-rewriting
helpers, rollback and restore, installers and package managers, hook or policy
changes, and broad context packers. Do not ask again for an action the
user's explicit, scoped authorisation for the current task already covers; do
not require fixed phrases. Anything outside that authorisation (a new target,
a new kind of mutation, a destructive or irreversible step, another
repository) needs explicit approval. Authorisation does not carry to another
task, and never overrides a limit stated in your own instructions or a
stricter role or host limit.

`git push`, `git reset --hard` and `rm -rf` are never routine: do not run them
unless the user explicitly authorises that exact command.

## Evidence Commands

Choose one evidence command for the question at hand: current state may call
for `git status --short`; change size for `git diff --stat HEAD`; an exact
untracked-file question for `git ls-files --others --exclude-standard`. These
are alternatives, never a startup bundle. Use one diagnostic command per tool
call; do not join independent probes with `&&`, `;`, pipelines or subshells.
Narrow large output with repository-relative pathspecs, and do not repeat
equivalent status, stat and name-status views without a specific reason.

Read files with a bounded, ranged read rather than dumping whole files: a large
or generated file wastes context and can surface a secret. Check a path
against secret files (`.env`, `.env.*`, `*.pem`, `*.key`, `id_rsa*`,
`secrets.*`, `credentials.*`) before opening it.

## Reporting

State completed verification separately from recommended verification:

- `Not run: <command> — <reason>`
- `Recommended: <command> — <why>`

If the runtime lacks the interpreter or tool a command needs, record the
command as not run with that reason. Never present an unavailable command as
passing.

## Gotchas

- A command existing in documentation is not proof it exists on disk.
- Exit code 0 from the wrong scope proves nothing about the change you made;
  state the scope alongside the result.
- Re-running the code under test to check itself is not independent
  verification.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
