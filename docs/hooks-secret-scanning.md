# Hooks + Secret Scanning: Husky vs Lefthook, Gitleaks vs TruffleHog

## Goal
Keep both hook frameworks available now, then pick one later with minimal migration cost.

## Hook framework similarity in this repo

Both Husky and Lefthook call the same shared scripts:
- `scripts/hooks/pre-commit.sh`
- `scripts/hooks/commit-msg.sh`

That gives you parity while evaluating tools.

## Husky vs Lefthook (practical)

- **Husky**
  - Node ecosystem default.
  - Great if repos already depend on `package.json` scripts.
- **Lefthook**
  - Fast, language-agnostic binary.
  - Better fit for polyglot repos without heavy Node dependence.

## Security posture recommendation (practical, low-friction)

- **Default local pre-commit scanner:** `gitleaks`
  - lower operational complexity for local blocking.
  - simple staged scan UX.
- **Optional CI/deep verification scanner:** `trufflehog`
  - stronger remote verification options.
  - useful as a second layer in CI.

> Recommendation: start with **gitleaks in local hooks**, add **trufflehog in CI** only if you need verified-result workflows.

## Suggested install commands

```bash
# macOS (Homebrew)
brew install gitleaks
brew install trufflesecurity/trufflehog/trufflehog
brew install lefthook
brew install husky   # if you specifically want Husky CLI available
```

## Suggested policy

1. Keep hook runtime under 10-20 seconds.
2. Fail on:
   - merge markers
   - PHP syntax errors
   - staged secret detection
3. Keep expensive scans in CI, not local hook path.

## About "least security issues"

There is no stable universal winner by CVE count alone because risk changes over time and depends on usage mode.
This repo recommendation is based on **smaller local attack surface + simpler ops** for developer hooks:
- local hook default: `gitleaks`
- optional CI deep scan: `trufflehog`

