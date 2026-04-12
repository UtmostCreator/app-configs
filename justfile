set shell := ["bash", "-cu"]

_default:
  @just --list

bootstrap:
  @echo "==> Basic bootstrap checks"
  @just doctor

doctor:
  @bash scripts/doctor.sh

# ------------------------------
# AI workflow placeholders
# ------------------------------
ai-review:
  @echo "==> AI review placeholder"
  @echo "Use your preferred AI tool here (Copilot Chat / Codex / Claude)."
  @echo "Example flow: summarize diff -> risk review -> test plan"

ai-fix:
  @echo "==> AI fix placeholder"
  @echo "Example flow: propose patch -> run tests -> review diff"

# ------------------------------
# Hooks + secret scans
# ------------------------------
hook-run-precommit:
  @bash scripts/hooks/pre-commit.sh

hook-run-commitmsg msg:
  @bash scripts/hooks/commit-msg.sh {{msg}}

secret-scan-gitleaks:
  @gitleaks protect --staged --redact --verbose

secret-scan-trufflehog:
  @trufflehog git file://. --since-commit HEAD~1 --results=verified,unknown --fail

# ------------------------------
# PHP helpers
# ------------------------------
php-pint:
  @if [ -x ./vendor/bin/pint ]; then ./vendor/bin/pint; else echo "vendor/bin/pint missing"; fi

php-pint-test:
  @if [ -x ./vendor/bin/pint ]; then ./vendor/bin/pint --test; else echo "vendor/bin/pint missing"; fi

php-unit:
  @if [ -x ./vendor/bin/phpunit ]; then ./vendor/bin/phpunit --testsuite=Unit; else echo "vendor/bin/phpunit missing"; fi

php-feature:
  @if [ -x ./vendor/bin/phpunit ]; then ./vendor/bin/phpunit --testsuite=Feature; else echo "vendor/bin/phpunit missing"; fi

php-test:
  @if [ -x ./vendor/bin/phpunit ]; then ./vendor/bin/phpunit; else echo "vendor/bin/phpunit missing"; fi

php-stan:
  @if [ -x ./vendor/bin/phpstan ]; then ./vendor/bin/phpstan analyse; else echo "vendor/bin/phpstan missing"; fi

sync-vscode-ext:
  @echo "==> Sync VS Code extensions"
  @echo "code --list-extensions > docs/vscode-extensions.snapshot.txt"

sync-config:
  @echo "==> Sync config placeholder"
  @echo "Add your rsync/symlink commands here for your machine"
