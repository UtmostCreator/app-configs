---
name: verify-ui-change
description: Use when an implemented user interface (web, mobile, desktop, or terminal) needs acceptance evidence for interactions, visual or layout states, accessibility, navigation, or persistence.
---

# Verify UI change

Prove user-visible behavior through an exact interaction journey on the target platform
and honest evidence. If the target interface cannot be operated, produce executable
manual instructions and mark the platform-dependent criteria `unverified`.

## Discovery

Read `review-diff` for its criteria alongside UI proof; independent patch review belongs to a separate reviewer, not to the author.

Identify the target platform first, then pick an authorized method that can operate it:

| Target | Method and evidence |
| --- | --- |
| Web application | browser automation; rendered states, navigation, requests |
| Mobile application | native or emulator UI testing; screens, lifecycle, device state |
| Desktop application | desktop UI automation; windows, dialogs, keyboard, saved settings |
| Terminal UI | an interactive terminal session; key navigation, rendered screen |
| Any platform | a human operator following the journey |

A missing browser does not block a native, desktop, or terminal interface. A plain
command-line program whose contract is output and exit status is not a UI journey:
route it to `verify-change`.

Inventory only the affected surface:

- entry points: routes, screens, windows, commands, or deep links
- controls: links, buttons, menus, fields, gestures, and keyboard interactions
- user role, fixture, prerequisites, and feature flags
- service requests and persistence effects
- loading, empty, error, retry, and permission states
- adjacent journeys that consume the changed component

Map every acceptance criterion to at least one journey step and observable result.
Reject criteria such as "works correctly" or "looks good."

## Read Alongside

- `verify-change` — reuse its verification-state semantics for UI evidence; this
  is a shared contract, not an invocation prerequisite.

## Journey contract

For each principal path, record:

1. environment, platform and version, applicable display dimensions, and source identity (commit plus any uncommitted changes, or a content digest)
2. required services, account role, fixtures, and feature flags
3. interface entry point
4. each control selected and value entered
5. expected destination or interface state, service result, and persisted state
6. a reload, restart, or reopen check, as applicable, when persistence is claimed
7. cleanup or restoration steps

For a UI bug needing implementation, route to `bug-reproduction-and-fix`; the change owner
provides baseline evidence. Verify the identical journey after the fix and compare
with that baseline. Do not implement a fix while verifying. A baseline failure
counts only when the intended observable assertion fails,
not when compilation, setup, authentication, fixtures, or an unrelated request fails.

## Relevant edge cases

Select cases from the controls and risks actually affected; do not mechanically run
every category:

| Category | Candidate checks |
| --- | --- |
| Input | empty, whitespace, bounds, Unicode, invalid format |
| Interaction | double submit, refresh, back navigation, interrupted action |
| Network | slow response, timeout, offline, relevant service errors, retry |
| State | loading, empty, partial, stale, concurrent update |
| Permission | anonymous, permitted, read-only, forbidden |
| Layout | supported viewports, resolutions, window or terminal sizes, zoom, overflow |
| Accessibility | keyboard-only, focus order, labels, accessible errors, contrast |
| Persistence | reload, restart, reopen, list/detail consistency |
| Regression | adjacent journeys using the changed component |

## Evidence

For every criterion, use the state semantics owned by `verify-change`: `pass`,
`fail`, `blocked`, `not_applicable`, or `unverified`. Record expected and observed
results, screenshot or screen-capture references, the platform's relevant diagnostics
(console, network, device, or application logs), environment, source identity,
commands, and exit status where available. Missing network logs matter only when network behavior
is part of a criterion.

Store large evidence as files only where your role allows writes (evidence that
must be kept follows `verify-change`), and reference them by path in your
report. Do not
create a parallel acceptance plan or workflow state.

## Human acceptance

Require explicit operator acceptance when the result is materially visual,
accessibility-sensitive, platform-specific, reference-dependent, or inadequately
proven by automation. Otherwise state why human acceptance is not required.

```yaml
decision: accepted | rejected | deferred
operator: <identity>
accepted_commit: <sha>
environment: <environment>
accepted_at: <timestamp>
exceptions: []
unverified_items: []
```

When required acceptance cannot be performed or obtained, use `human-handoff` to
prepare the exact manual procedure: prerequisites, expected observations, failure
conditions and evidence to return. Leave the change unaccepted until that evidence
establishes its criteria. Never infer acceptance from silence.

## Target interface unavailable

Emit the exact prerequisites, entry point, values, controls, expected results, failure
signals, and cleanup steps for a human operator. Mark diagnostic, screenshot, layout,
and interaction claims `unverified` unless evidence from the named environment exists.

## Never

- claim runtime or visual proof from a diff, build, unit test, or screenshot alone
- treat absent diagnostics as a pass
- expose credentials, session tokens, or private response bodies in evidence
- broaden implementation scope while verifying an adjacent failure
- mark a required blocked or unverified criterion as accepted
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
