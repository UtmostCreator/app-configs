# Verify Change Capability

## Purpose

Choose the smallest relevant proof for a config, docs, or workflow change and report evidence cleanly.

## Trigger When

- a change claims to be correct
- docs or commands changed
- a config edit may affect local tooling behavior

## Workflow

1. identify the changed surface
2. run the closest non-destructive validation available
3. escalate only if the slice crosses tools or leaves uncertainty
4. report exactly what was checked and what remains unverified

## Output Contract

- rationale for verification choice
- checks run
- result
- remaining risk or follow-up checks
