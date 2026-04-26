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

# Print per-file and per-directory line/size metrics. Stdout only, no files written.
repo-info path='.' large_file='500' large_dir='5000':
  @bash scripts/copilot/repo-stats.sh {{path}} --large-file {{large_file}} --large-dir {{large_dir}}

# Same as repo-info but scoped to a file extension (e.g. php,blade.php)
repo-info-ext path='.' ext='php':
  @bash scripts/copilot/repo-stats.sh {{path}} --ext {{ext}}

# Emit flat per-file JSON for downstream processing
repo-info-json path='.':
  @bash scripts/copilot/repo-stats.sh {{path}} --json

# Read-only summary for closeout reporting after context-heavy queries.
query-usage path='.' multiplier='1' label='1x' reserved='4000':
  @bash scripts/copilot/query-usage.sh {{path}} --multiplier {{multiplier}} --multiplier-label {{label}} --reserved-output {{reserved}}

# Repomix-aware recursive context planner. Use opts to pass --compress, --context-window, etc.
context-tree-analyze path='.' opts='':
  @bash -lc 'path="{{path}}"; opts="{{opts}}"; if [[ "$path" == opts=* ]] && [[ -z "$opts" ]]; then opts="${path#opts=}"; path="."; fi; bash scripts/copilot/repomix-context-tree.sh analyze "$path" $opts'

context-tree-plan path='.' opts='':
  @bash -lc 'path="{{path}}"; opts="{{opts}}"; if [[ "$path" == opts=* ]] && [[ -z "$opts" ]]; then opts="${path#opts=}"; path="."; fi; bash scripts/copilot/repomix-context-tree.sh plan "$path" $opts'

context-tree-pack path='.' opts='':
  @bash -lc 'path="{{path}}"; opts="{{opts}}"; if [[ "$path" == opts=* ]] && [[ -z "$opts" ]]; then opts="${path#opts=}"; path="."; fi; bash scripts/copilot/repomix-context-tree.sh pack "$path" $opts'

context-tree-all path='.' opts='':
  @bash -lc 'path="{{path}}"; opts="{{opts}}"; if [[ "$path" == opts=* ]] && [[ -z "$opts" ]]; then opts="${path#opts=}"; path="."; fi; bash scripts/copilot/repomix-context-tree.sh all "$path" $opts'

context-plan path='.' depth='1' top='25' min_code='300' min_files='2' min_complexity='0':
  @bash scripts/copilot/repomix-scc-router.sh plan {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}} --min-complexity {{min_complexity}}

context-plan-since ref path='.' depth='1' top='25' min_code='300' min_files='2' min_complexity='0' churn_count='50':
  @bash scripts/copilot/repomix-scc-router.sh plan {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}} --min-complexity {{min_complexity}} --changed-since {{ref}} --churn-count {{churn_count}}

context-pack:
  @bash scripts/copilot/repomix-scc-router.sh pack .

context-pack-all path='.' depth='1' top='25' min_code='300' min_files='2' min_complexity='0':
  @bash scripts/copilot/repomix-scc-router.sh all {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}} --min-complexity {{min_complexity}}

context-pack-all-since ref path='.' depth='1' top='25' min_code='300' min_files='2' min_complexity='0' churn_count='50':
  @bash scripts/copilot/repomix-scc-router.sh all {{path}} --depth {{depth}} --top {{top}} --min-code {{min_code}} --min-files {{min_files}} --min-complexity {{min_complexity}} --changed-since {{ref}} --churn-count {{churn_count}}

context-clean path='.':
  @bash scripts/copilot/repomix-scc-router.sh clean {{path}}

context-purge path='.':
  @bash scripts/copilot/repomix-scc-router.sh purge {{path}}

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

php-patterns-search query path='tools/design-patterns':
  @bash scripts/copilot/ai-search.sh text {{query}} {{path}}

php-principles-search query path='tools/design-principles':
  @bash scripts/copilot/ai-search.sh text {{query}} {{path}}

php-builtins-search query path='tools/php-built-ins':
  @bash scripts/copilot/ai-search.sh text {{query}} {{path}}

php-examples-map:
  @printf '%s\n' 'PHP example lookup order:' '1) tools/design-patterns (primary)' '2) tools/design-principles (secondary)' '3) tools/php-built-ins (supporting)'

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

health-check mode='full':
  @bash scripts/repo-health-check.sh {{mode}}

lint:
  @shellcheck -x $(git ls-files '*.sh')
  @shfmt -d $(git ls-files '*.sh')
  @actionlint
  @bash scripts/run-link-check.sh

test-php:
  @composer install --no-interaction --prefer-dist
  @vendor/bin/phpunit --colors=never

test-shell:
  @LC_ALL=C LANG=C TZ=UTC bats tests/shell/

test: test-php test-shell

ci: ai-check lint test
