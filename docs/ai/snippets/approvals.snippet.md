## Approval Snippet

Ask for approval before:

- `secrets, destructive changes, NixOS system layer (sys-setup), install/apply scripts, uninstall actions`
- Approval means a human approver can explain each changed section well enough to own the merge.

Examples:

- dependency additions or removals
- schema or persistence changes
- public API changes
- auth or permission changes
- major file moves or deletions
