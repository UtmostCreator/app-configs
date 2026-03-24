---
applyTo: "<ACTIVE_PATHS>"
description: "Architecture, ownership, and layering guidance"
---

# Architecture Rules

- Read current code before proposing structural changes.
- Keep logic with its existing owner unless there is a clear architectural reason to move it.
- Prefer extending current patterns before introducing parallel abstractions.
- Ask for approval before making: `<APPROVAL_REQUIRED_CHANGES>`
- Approval means a human approver can explain each changed section well enough to own the merge.
- For migrations that drop, rename, or restructure existing data, use expand-contract.
