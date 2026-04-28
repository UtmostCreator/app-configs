---
applyTo: "<TEST_PATH_GLOB>"
description: "Testing rules for focused, deterministic, behavior-proving tests"
---

# Testing Rules

- Prefer the lowest test level that proves the behavior.
- Add regression coverage when fixing bugs.
- Keep tests deterministic where practical.
- Avoid weakening assertions to make a change pass.
- Use `<PRIMARY_TEST_COMMAND>` as the baseline test command unless a narrower command is more appropriate.
