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

context-plan-since ref path='.' depth='1' top='25' min_code='300' min_files='2' churn_count='50':
  @bash scripts/copilot/repomix-scc-router.sh plan {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}} --changed-since {{ref}} --churn-count {{churn_count}}

context-pack:
  @bash scripts/copilot/repomix-scc-router.sh pack .

context-pack-all path='.' depth='1' top='25' min_code='300' min_files='2':
  @bash scripts/copilot/repomix-scc-router.sh all {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}}

context-pack-all-since ref path='.' depth='1' top='25' min_code='300' min_files='2' churn_count='50':
  @bash scripts/copilot/repomix-scc-router.sh all {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}} --changed-since {{ref}} --churn-count {{churn_count}}

context-plan-json path='.':
  @bash -lc 'test -f {{path}}/.repomix-context/bundle-plan.json && cat {{path}}/.repomix-context/bundle-plan.json || { echo "bundle-plan.json not found; run just context-plan or context-pack-all first" >&2; exit 1; }'

search pattern path='.' mode='default':
  @bash scripts/copilot/rg-code.sh {{pattern}} {{path}} --mode {{mode}}

agent-search mode query path='.' :
  @bash scripts/copilot/ai-search.sh {{mode}} {{query}} {{path}}

verify path='.' :
  @bash scripts/copilot/ai-verify.sh {{path}}

edit-ast lang pattern rewrite path='.' :
  @bash scripts/copilot/ai-edit.sh ast-grep {{lang}} {{pattern}} {{rewrite}} {{path}}

edit-ast-apply lang pattern rewrite path='.' :
  @APPLY=1 VERIFY=1 bash scripts/copilot/ai-edit.sh ast-grep {{lang}} {{pattern}} {{rewrite}} {{path}}

edit-text from to path='.' :
  @bash scripts/copilot/ai-edit.sh sd {{from}} {{to}} {{path}}

edit-text-apply from to path='.' :
  @APPLY=1 VERIFY=1 bash scripts/copilot/ai-edit.sh sd {{from}} {{to}} {{path}}

search-files query path='.':
  @bash scripts/copilot/fd-files.sh {{query}} {{path}}

context-since ref:
  @bash scripts/copilot/ai-diff-context.sh since {{ref}}

context-unstaged:
  @bash scripts/copilot/ai-diff-context.sh unstaged

context-pr pr:
  @bash scripts/copilot/ai-diff-context.sh pr {{pr}}

context-recent count='10':
  @bash scripts/copilot/ai-diff-context.sh recent --count {{count}}

context-touched pattern:
  @bash scripts/copilot/ai-diff-context.sh touched {{pattern}}

pr-meta pr:
  @bash scripts/copilot/gh-pr-context.sh {{pr}}

pr-review pr:
  @bash scripts/copilot/gh-pr-context.sh {{pr}} --diff --checks --reviews

rollback-list:
  @bash scripts/copilot/ai-rollback.sh list

rollback-show target:
  @bash scripts/copilot/ai-rollback.sh show {{target}}

rollback target:
  @bash scripts/copilot/ai-rollback.sh apply {{target}}

hook-run-precommit:
  @bash scripts/hooks/pre-commit.sh

hook-run-commitmsg msg:
  @bash scripts/hooks/commit-msg.sh {{msg}}

secret-scan-gitleaks:
  @gitleaks protect --staged --redact --verbose

secret-scan-trufflehog:
  @trufflehog git file://. --since-commit HEAD --results=verified,unknown --fail
