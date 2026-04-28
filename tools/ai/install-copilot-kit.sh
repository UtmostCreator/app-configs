#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  tools/ai/install-copilot-kit.sh [options]

Options:
  --target <dir>      Target repository root (default: .)
  --profile <name>    Install profile: minimal|copilot|copilot-guarded (default: minimal)
  --runtime <name>    Runtime adapter (default: github-copilot)
  --project-name <n>  Override inferred project name
  --force             Overwrite existing files
  --dry-run           Print planned actions only
  --help              Show this help

Notes:
  - This script installs a starter kit from AI-universal-rules templates.
  - Placeholder values are adapted to the target repo before write.
  - Canonical install is GitHub Copilot focused for now.
EOF
}

log() {
    printf '[install-copilot-kit] %s\n' "$*"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

TARGET='.'
PROFILE='minimal'
RUNTIME='github-copilot'
PROJECT_NAME=''
FORCE=0
DRY_RUN=0

while (($# > 0)); do
    case "$1" in
    --target)
        TARGET="$2"
        shift 2
        ;;
    --target=*)
        TARGET="${1#*=}"
        shift
        ;;
    --profile)
        PROFILE="$2"
        shift 2
        ;;
    --profile=*)
        PROFILE="${1#*=}"
        shift
        ;;
    --runtime)
        RUNTIME="$2"
        shift 2
        ;;
    --runtime=*)
        RUNTIME="${1#*=}"
        shift
        ;;
    --project-name)
        PROJECT_NAME="$2"
        shift 2
        ;;
    --project-name=*)
        PROJECT_NAME="${1#*=}"
        shift
        ;;
    --force)
        FORCE=1
        shift
        ;;
    --dry-run)
        DRY_RUN=1
        shift
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    *)
        die "unknown option '$1'"
        ;;
    esac
done

case "$PROFILE" in
minimal | copilot | copilot-guarded) ;;
*) die "unsupported profile '$PROFILE'" ;;
esac

if [[ "$RUNTIME" != 'github-copilot' ]]; then
    die "runtime '$RUNTIME' is not yet supported by this installer"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET_ROOT="$(cd "$TARGET" && pwd)"

[[ -d "$TARGET_ROOT" ]] || die "target directory not found: $TARGET_ROOT"

if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME="$(basename "$TARGET_ROOT")"
fi

detect_project_type() {
    if [[ -f "$TARGET_ROOT/composer.json" ]]; then
        printf 'php project\n'
        return 0
    fi

    if [[ -f "$TARGET_ROOT/package.json" ]]; then
        printf 'node project\n'
        return 0
    fi

    if [[ -f "$TARGET_ROOT/go.mod" ]]; then
        printf 'go project\n'
        return 0
    fi

    printf 'repository\n'
}

detect_primary_language() {
    if command -v scc >/dev/null 2>&1; then
        local summary
        summary="$(scc "$TARGET_ROOT" 2>/dev/null | awk '($1 !~ /^[-]/ && $1 != "Language" && $1 != "Total" && $2 ~ /^[0-9,]+$/) { code=$6; gsub(",", "", code); print $1"\t"code }' | sort -k2,2nr | head -n 1 || true)"
        if [[ -n "$summary" ]]; then
            printf '%s\n' "${summary%%$'\t'*}"
            return 0
        fi
    fi

    printf 'unknown\n'
}

collect_active_paths() {
    if git -C "$TARGET_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$TARGET_ROOT" ls-files | awk -F/ '{print (NF>1?$1:"_root")}' | sort -u | paste -sd, -
        return 0
    fi

    printf '_root\n'
}

PROJECT_TYPE="$(detect_project_type)"
PRIMARY_LANGUAGE="$(detect_primary_language)"
ACTIVE_PATHS="$(collect_active_paths)"

if [[ -z "$ACTIVE_PATHS" ]]; then
    ACTIVE_PATHS='_root'
fi

declare -A PLACEHOLDERS=()
PLACEHOLDERS[PROJECT_NAME]="$PROJECT_NAME"
PLACEHOLDERS[PROJECT_SUMMARY]="AI workflow starter for $PROJECT_NAME"
PLACEHOLDERS[PROJECT_TYPE]="$PROJECT_TYPE"
PLACEHOLDERS[PRIMARY_LANGUAGE]="$PRIMARY_LANGUAGE"
PLACEHOLDERS[PRIMARY_RUNTIME]="unknown"
PLACEHOLDERS[ACTIVE_PATHS]="$ACTIVE_PATHS"
PLACEHOLDERS[INACTIVE_PATHS]="unknown"
PLACEHOLDERS[PRIMARY_ENTRYPOINTS]="README.md, docs/ai/project-context.md"
PLACEHOLDERS[PRIMARY_VERIFY_COMMAND]="unknown"
PLACEHOLDERS[PRIMARY_BUILD_COMMAND]="unknown"
PLACEHOLDERS[PRIMARY_TEST_COMMAND]="unknown"
PLACEHOLDERS[PROJECT_CONTEXT_PATH]="docs/ai/project-context.md"
PLACEHOLDERS[AVAILABLE_CAPABILITIES]="project-context, verify-change, review-diff"
PLACEHOLDERS[REVIEW_PRIORITIES]="correctness, regressions, configuration drift"
PLACEHOLDERS[APPROVAL_REQUIRED_CHANGES]="secrets, destructive changes, auth or billing changes"
PLACEHOLDERS[TARGET_PLATFORMS]="unknown"
PLACEHOLDERS[ARCHITECTURE_NOTES]="Keep policy and capability docs canonical; keep runtime adapters thin."
PLACEHOLDERS[RISK_AREAS]="stale docs, adapter drift, unsafe command usage"
PLACEHOLDERS[NARROW_VERIFY_GUIDANCE]="start with the narrowest repo-local check and escalate only if needed"
PLACEHOLDERS[CAPABILITY_COMPOSITION_NOTES]="start with project-context, then verify-change, then review-diff"
PLACEHOLDERS[RELEASE_SAFETY_NOTES]="define rollback posture for medium/high risk changes"
PLACEHOLDERS[KNOWN_GOTCHA_THEMES]="stale paths, broad edits without evidence, guessed behavior"
PLACEHOLDERS[COPILOT_SURFACE]="VS Code, CLI, GitHub.com"
PLACEHOLDERS[SUPPORTED_FEATURES]="repo instructions, path instructions"
PLACEHOLDERS[OPTIONAL_FEATURES]="prompt files, custom agents, hooks, MCP"
PLACEHOLDERS[INSTRUCTION_PRECEDENCE_NOTES]="Nearest AGENTS.md wins for agent instructions."
PLACEHOLDERS[CONFLICT_AVOIDANCE_NOTES]="Keep repo-wide and path-specific guidance complementary."
PLACEHOLDERS[GLOBAL_OR_SHARED_RULE_SOURCES]="organization instructions, user-level instructions"
PLACEHOLDERS[OPTIONAL_VERIFY_COMMAND]="unknown"

copy_file() {
    local src_rel="$1"
    local dest_rel="$2"
    local src="$SOURCE_ROOT/$src_rel"
    local dest="$TARGET_ROOT/$dest_rel"

    [[ -f "$src" ]] || die "missing source file: $src_rel"

    if [[ -f "$dest" && "$FORCE" -ne 1 ]]; then
        log "skip existing file (use --force to overwrite): $dest_rel"
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "copy file: $src_rel -> $dest_rel"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    log "copied file: $dest_rel"
}

copy_dir() {
    local src_rel="$1"
    local dest_rel="$2"
    local src="$SOURCE_ROOT/$src_rel"
    local dest="$TARGET_ROOT/$dest_rel"

    [[ -d "$src" ]] || die "missing source directory: $src_rel"

    if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
        log "skip existing directory (use --force to overwrite): $dest_rel"
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "copy directory: $src_rel -> $dest_rel"
        return 0
    fi

    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -R "$src" "$dest"
    log "copied directory: $dest_rel"
}

apply_placeholders_to_file() {
    local file="$1"
    local content
    content="$(<"$file")"

    local key
    for key in "${!PLACEHOLDERS[@]}"; do
        content="${content//<$key>/${PLACEHOLDERS[$key]}}"
    done

    printf '%s' "$content" >"$file"
}

apply_placeholders() {
    local path

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "placeholder substitution planned for markdown files under AGENTS.md, docs/ai, .github"
        return 0
    fi

    for path in "$TARGET_ROOT/AGENTS.md" "$TARGET_ROOT/docs/ai" "$TARGET_ROOT/.github"; do
        [[ -e "$path" ]] || continue

        if [[ -f "$path" ]]; then
            apply_placeholders_to_file "$path"
            continue
        fi

        while IFS= read -r -d '' file; do
            apply_placeholders_to_file "$file"
        done < <(find "$path" -type f -name '*.md' -print0)
    done

    log 'applied placeholders'
}

install_base() {
    copy_file 'packages/ai-universal-rules/templates/core/AGENTS.template.md' 'AGENTS.md'
    copy_file 'packages/ai-universal-rules/templates/core/project-context.template.md' 'docs/ai/project-context.md'
    copy_file 'packages/ai-universal-rules/templates/core/copilot-instructions.template.md' '.github/copilot-instructions.md'
    copy_file 'packages/ai-universal-rules/templates/shared/guardrails/AI-GUARDRAILS.md' 'docs/ai/AI-GUARDRAILS.md'
    copy_dir 'packages/ai-universal-rules/templates/capabilities/project-context' 'docs/ai/capabilities/project-context'
    copy_dir 'packages/ai-universal-rules/templates/capabilities/verify-change' 'docs/ai/capabilities/verify-change'
    copy_dir 'packages/ai-universal-rules/templates/capabilities/review-diff' 'docs/ai/capabilities/review-diff'
}

install_copilot_profile() {
    copy_dir 'packages/ai-universal-rules/templates/github-copilot/instructions' '.github/instructions'
    copy_dir 'packages/ai-universal-rules/templates/github-copilot/agents' '.github/agents'
    copy_dir 'packages/ai-universal-rules/templates/github-copilot/prompts' '.github/prompts'
}

install_guarded_profile() {
    copy_dir '.github/hooks' '.github/hooks'
    copy_dir 'scripts/copilot' 'scripts/copilot'
}

log "source root: $SOURCE_ROOT"
log "target root: $TARGET_ROOT"
log "profile: $PROFILE"
log "runtime: $RUNTIME"
log "project name: $PROJECT_NAME"
log "project type: $PROJECT_TYPE"
log "primary language: $PRIMARY_LANGUAGE"
log "active paths: $ACTIVE_PATHS"

install_base

if [[ "$PROFILE" == 'copilot' || "$PROFILE" == 'copilot-guarded' ]]; then
    install_copilot_profile
fi

if [[ "$PROFILE" == 'copilot-guarded' ]]; then
    install_guarded_profile
fi

apply_placeholders

if [[ "$DRY_RUN" -eq 1 ]]; then
    log 'dry-run complete; no files were changed'
else
    log 'install complete'
    log 'next steps:'
    log '1) review AGENTS.md and docs/ai/project-context.md'
    log '2) run your repo checks'
    log '3) resolve any remaining placeholder tokens if present'
fi
