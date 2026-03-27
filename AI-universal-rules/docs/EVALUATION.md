# Capability Evaluation

Use this rubric when deciding whether a capability is working well enough to keep, expand, or remove.

## Trigger Quality

- Did the right capability trigger for the request?
- Did it avoid triggering on near-miss requests?
- Is the description written in user-language rather than maintainer shorthand?

## Output Quality

- Did the capability produce the expected structure?
- Did it provide evidence instead of generic confidence?
- Did it stay within scope instead of overreaching?

## Verification Quality

- Did it choose the smallest relevant verification first?
- Did it distinguish build success from behavior proof?
- Did it report exactly what was verified?

## Maintainability

- Is the entry file short enough to scan quickly?
- Are gotchas and examples in support files instead of bloating the entry file?
- Does the capability duplicate another capability without adding value?

## Review Questions

For every high-value capability, review these regularly:

1. What user requests should trigger it?
2. What requests should not trigger it?
3. What are the top three failure modes?
4. What support file gets read most often and should that content move?
5. Can any repeated reasoning become a deterministic script or template?

## Keep, Improve, Or Remove

- Keep when the capability triggers cleanly and reduces repeated prompting.
- Improve when it is useful but misses edge cases, lacks gotchas, or has weak examples.
- Remove or merge when it duplicates another capability or fires too broadly.
