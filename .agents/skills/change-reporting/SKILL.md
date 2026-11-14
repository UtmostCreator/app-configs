---
name: change-reporting
description: Manual invocation only. Draft developer, PR, QA, reviewer or stakeholder reports for the requested change.
disable-model-invocation: true
---

# Change Reporting

Draft audience-specific reports from existing evidence about the requested
change. Reporting presents evidence; it does not implement, verify or review.

## Activation

Direct user invocation is required. Installation, a ticket requiring reports,
quoted names or examples, completed implementation and passing reviews are not
invocation. Do not implicitly load, invoke, preload or delegate this skill.
Its presence adds no reporting obligation to any agent or other skill.
Ordinary user requests for summaries or equivalent reports may receive normal
answers without loading this skill. Existing agent reporting rules still apply.

Authorization covers only the requested report and change scope. Do not carry
it into unrelated work or generate additional reports after completing it.


The user invokes `$change-reporting qa`. The native policy disables implicit
selection; if explicit invocation does not load the actual skill, report the
host compatibility blocker rather than using an unprotected fallback.

## Modes

Resolve the internal option `target` from the invocation's arguments:

| Target | Audience and content |
|---|---|
| dev | Developer changelog, required migrations/configuration and technical caveats |
| pr | Suggested PR title, concise description, compatibility impact, verification and risks |
| qa | Ranked changed behaviors, prerequisites, exact test actions and observable expected results |
| review | Change purpose, affected contracts/consumers, inspection priorities and evidence gaps |
| nontech | Plain-language effects, benefits, required actions and material limitations |
| all | Every applicable core mode above |

Accept one mode or a comma-separated selection, including natural-language
audience selections in the explicit invocation. With no audience specified,
default to all only after activation. All includes the five core modes; do not
add release, support, operations or product modes. For an unknown or ambiguous
selection, ask a short clarification rather than broadening the audience.
Generate exactly the selected modes; omit inapplicable or empty sections.

## Evidence

Identify the exact commit, diff/range or active working-tree change. If more
than one change scope is plausible, ask which one to report on. Read only the
requirements, approved plans, actual diff, relevant source/tests/documentation
and existing verification/review evidence needed for that scope.

Requirements establish expected behavior; implementation establishes changed
behavior; execution evidence establishes verified behavior. Never describe
proposed work as completed or a recommended test as passed. If the plan and
implementation disagree, report the conflict rather than silently reconciling
it. Tie verification to its revision and scope; mark it potentially stale when
the change has moved beyond that revision. Preserve material unknowns.

## Reporting

1. Consolidate the final behavior, removing duplicates and reverted experiments.
2. Put evidenced breaking changes, data-loss risks and required migrations
   first, followed by important user/security changes, fixes, and relevant
   internal or documentation/test maintenance. Rank by impact and actionability,
   not commit order. Removed code alone does not prove a breaking contract.
3. Select details for the audience. Developers need required actions before
   optional internals; QA needs important behavior changes before test steps;
   stakeholders need effects without internal paths or implementation jargon.
4. In QA instructions, state the relevant environment/data and exact actions
   with observable expected results. Separate defect reproduction from fix
   confirmation. Include setup/cleanup only when needed; do not invent a UI
   journey for documentation-only changes or an undocumented command.
5. Separate completed verification from suggested checks. Use acceptance states
   pass, fail, blocked, not_applicable and unverified when reporting criteria;
   preserve the source test report's separate status vocabulary.
6. Keep sections concise. Do not repeat the same explanation unnecessarily or
   invent commits, versions, approvals, test results or source references.

Return drafts in the conversation, with source references where useful.
Do not create or edit files, run checks to fill evidence gaps, independently
review the change, create PRs/issues/commits, publish or deploy. Missing
evidence remains a reported gap, not authority to start another workflow.
<!-- glyphbrace:user:begin id=user -->
<!-- glyphbrace:user:end id=user -->
