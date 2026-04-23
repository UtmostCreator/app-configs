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

context-stats path='.' depth='1':
  @bash scripts/copilot/repomix-scc-router.sh stats {{path}} --depth {{depth}}

context-plan path='.' depth='1' top='25' min_code='300' min_files='2':
  @bash scripts/copilot/repomix-scc-router.sh plan {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}}

context-pack:
  @bash scripts/copilot/repomix-scc-router.sh pack .

context-pack-all path='.' depth='1' top='25' min_code='300' min_files='2':
  @bash scripts/copilot/repomix-scc-router.sh all {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}}

hook-run-precommit:
  @bash scripts/hooks/pre-commit.sh

hook-run-commitmsg msg:
  @bash scripts/hooks/commit-msg.sh {{msg}}

secret-scan-gitleaks:
  @gitleaks protect --staged --redact --verbose

secret-scan-trufflehog:
  @trufflehog git file://. --since-commit HEAD --results=verified,unknown --fail
