set shell := ["bash", "-cu"]

_default:
  @just --list

bootstrap:
  @just doctor

doctor:
  @bash scripts/doctor.sh

ai-validate-config:
  @php tools/ai/validate-ai-config.php

ai-validate-catalog:
  @php tools/ai/validate-ai-catalog.php

ai-generate-catalog:
  @php tools/ai/generate-ai-catalog.php

ai-check:
  @php tools/ai/validate-ai-config.php
  @php tools/ai/validate-ai-catalog.php
  @php tools/ai/generate-ai-catalog.php --check

hook-run-precommit:
  @bash scripts/hooks/pre-commit.sh

hook-run-commitmsg msg:
  @bash scripts/hooks/commit-msg.sh {{msg}}

secret-scan-gitleaks:
  @gitleaks protect --staged --redact --verbose

secret-scan-trufflehog:
  @trufflehog git file://. --since-commit HEAD --results=verified,unknown --fail
