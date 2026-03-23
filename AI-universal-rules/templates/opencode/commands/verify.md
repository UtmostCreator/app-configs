---
description: Run the main verification workflow for the repository
agent: reviewer
---

Run the main verification commands in order and summarize failures separately.

Step 1:
!`<PRIMARY_TEST_COMMAND>`

Step 2:
!`<PRIMARY_BUILD_COMMAND>`

Step 3:
!`<PRIMARY_VERIFY_COMMAND>`

Important:

- Use the smallest relevant command first when the task is narrow.
- Build success alone is not proof of behavior correctness unless the project explicitly says so.
- If one command subsumes another in the target repo, simplify the sequence after placeholder replacement.
