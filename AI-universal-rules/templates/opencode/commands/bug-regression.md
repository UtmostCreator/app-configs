# Bug Regression Command

Use this command as the runtime entry point for a bounded bug-fix task.

Workflow:

1. load `project-context`
2. load `bug-regression`
3. reproduce with the smallest practical check
4. apply the minimal fix
5. run `verify-change`
6. escalate to `release-safety` only when risk is `medium` or `high`

Do not use this command for broad feature work or architecture redesign.
