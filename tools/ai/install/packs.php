<?php

declare(strict_types=1);

require_once __DIR__ . '/profiles.php';

function aiInstallerPackRegistry(): array
{
    return [
        'setup-docs' => [],
        'capabilities-core' => [],
        'base' => [
            ['type' => 'file', 'source' => 'packages/ai-universal-rules/templates/core/AGENTS.template.md', 'target' => 'AGENTS.md', 'core' => true, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'packages/ai-universal-rules/templates/core/project-context.template.md', 'target' => 'docs/ai/project-context.md', 'core' => true, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'packages/ai-universal-rules/templates/shared/guardrails/AI-GUARDRAILS.md', 'target' => 'docs/ai/AI-GUARDRAILS.md', 'core' => true, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/capabilities/project-context', 'target' => 'docs/ai/capabilities/project-context', 'core' => true, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/capabilities/verify-change', 'target' => 'docs/ai/capabilities/verify-change', 'core' => true, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/capabilities/review-diff', 'target' => 'docs/ai/capabilities/review-diff', 'core' => true, 'merge_strategy' => 'replace', 'required' => true],
        ],
        'adapter-copilot' => [
            ['type' => 'file', 'source' => 'packages/ai-universal-rules/templates/core/copilot-instructions.template.md', 'target' => '.github/copilot-instructions.md', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/github-copilot/instructions', 'target' => '.github/instructions', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/github-copilot/agents', 'target' => '.github/agents', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/github-copilot/prompts', 'target' => '.github/prompts', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
        ],
        'adapter-opencode' => [
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/opencode/agents', 'target' => '.opencode/agents', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/opencode/commands', 'target' => '.opencode/commands', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/opencode/skills', 'target' => '.opencode/skills', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
        ],
        'capabilities-extended-lite' => [
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/capabilities/bug-regression', 'target' => 'docs/ai/capabilities/bug-regression', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/capabilities/release-safety', 'target' => 'docs/ai/capabilities/release-safety', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
        ],
        'capabilities-extended-full' => [
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/capabilities/dependency-upgrade', 'target' => 'docs/ai/capabilities/dependency-upgrade', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
        ],
        'policy-pack' => [
            ['type' => 'file', 'source' => 'docs/ai/command-risk-taxonomy.md', 'target' => 'docs/ai/command-risk-taxonomy.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
            ['type' => 'file', 'source' => 'docs/ai/failure-handling.md', 'target' => 'docs/ai/failure-handling.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
            ['type' => 'file', 'source' => '.schemas/evidence-event.schema.json', 'target' => '.schemas/evidence-event.schema.json', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
        ],
        'scripts-pack' => [
            ['type' => 'file', 'source' => 'scripts/copilot/common.sh', 'target' => 'scripts/ai/common.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/ai-search.sh', 'target' => 'scripts/ai/ai-search.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/ai-diff-context.sh', 'target' => 'scripts/ai/ai-diff-context.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/ai-verify.sh', 'target' => 'scripts/ai/ai-verify.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/ai-rollback.sh', 'target' => 'scripts/ai/ai-rollback.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/ai-edit.sh', 'target' => 'scripts/ai/ai-edit.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/pack-context.sh', 'target' => 'scripts/ai/pack-context.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/pre-tool-use.sh', 'target' => 'scripts/ai/pre-tool-use.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/post-tool-use.sh', 'target' => 'scripts/ai/post-tool-use.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/run-repomix-context.sh', 'target' => 'scripts/ai/run-repomix-context.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/repomix-context-tree.sh', 'target' => 'scripts/ai/repomix-context-tree.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/repomix-scc-router.sh', 'target' => 'scripts/ai/repomix-scc-router.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/git-forensics.sh', 'target' => 'scripts/ai/git-forensics.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/gh-pr-context.sh', 'target' => 'scripts/ai/gh-pr-context.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/preview-file.sh', 'target' => 'scripts/ai/preview-file.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/query-usage.sh', 'target' => 'scripts/ai/query-usage.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/fd-files.sh', 'target' => 'scripts/ai/fd-files.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/rg-code.sh', 'target' => 'scripts/ai/rg-code.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/copilot/watch-loop.sh', 'target' => 'scripts/ai/watch-loop.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/ai/repo-tool-inventory.sh', 'target' => 'scripts/ai/repo-tool-inventory.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => false],
            ['type' => 'file', 'source' => 'scripts/ai/install-mandatory-tools.sh', 'target' => 'scripts/ai/install-mandatory-tools.sh', 'core' => false, 'merge_strategy' => 'replace', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/repo-required-tools.md', 'target' => 'docs/ai/repo-required-tools.md', 'core' => false, 'merge_strategy' => 'replace', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/mandatory-tools-install.md', 'target' => 'docs/ai/mandatory-tools-install.md', 'core' => false, 'merge_strategy' => 'replace', 'required' => false],
        ],
        'hooks-pack' => [
            ['type' => 'file', 'source' => 'scripts/hooks/pre-commit.sh', 'target' => 'scripts/hooks/pre-commit.sh', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
            ['type' => 'file', 'source' => 'scripts/hooks/commit-msg.sh', 'target' => 'scripts/hooks/commit-msg.sh', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
            ['type' => 'file', 'source' => 'docs/ai/hooks.md', 'target' => 'docs/ai/hooks.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
        ],
        'ci-pack' => [
            ['type' => 'file', 'source' => '.github/workflows/validate-ai-surface.yml', 'target' => '.github/workflows/validate-ai-surface.yml', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
            ['type' => 'file', 'source' => 'docs/ai/validation.md', 'target' => 'docs/ai/validation.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
        ],
        'evidence-pack' => [
            ['type' => 'file', 'source' => 'docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md', 'target' => 'docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
            ['type' => 'file', 'source' => 'docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md', 'target' => 'docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => true],
        ],
        'docs-reference-pack' => [
            ['type' => 'file', 'source' => 'docs/ai/agent-ops.md', 'target' => 'docs/ai/agent-ops.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/agent-ops-checklist.md', 'target' => 'docs/ai/agent-ops-checklist.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/failure-handling.md', 'target' => 'docs/ai/failure-handling.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/validation.md', 'target' => 'docs/ai/validation.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/context-packing.md', 'target' => 'docs/ai/context-packing.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/hooks.md', 'target' => 'docs/ai/hooks.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/scripts-reference.md', 'target' => 'docs/ai/scripts-reference.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'docs/ai/toolchain-requirements.md', 'target' => 'docs/ai/toolchain-requirements.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'delivery-pack' => [
            ['type' => 'file', 'source' => 'packages/ai-universal-rules/templates/optional/delivery/README.md', 'target' => 'docs/ai/delivery/README.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => 'packages/ai-universal-rules/templates/optional/delivery/slice-card.template.md', 'target' => 'docs/ai/delivery/slice-card.template.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'optional-agents-pack' => [
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/optional/opencode/agents', 'target' => '.opencode/agents-optional', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'optional-prompts-pack' => [
            ['type' => 'dir', 'source' => 'packages/ai-universal-rules/templates/optional/github-copilot/prompts', 'target' => '.github/prompts-optional', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'preview-environments-pack' => [
            ['type' => 'dir', 'source' => 'docs/ai/capabilities/preview-environments', 'target' => 'docs/ai/capabilities/preview-environments', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'evaluation-pack' => [
            ['type' => 'dir', 'source' => 'docs/ai/capabilities/evaluation-and-regression', 'target' => 'docs/ai/capabilities/evaluation-and-regression', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'service-boundary-pack' => [
            ['type' => 'dir', 'source' => 'docs/ai/capabilities/service-boundary-patterns', 'target' => 'docs/ai/capabilities/service-boundary-patterns', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'mcp-boundaries-pack' => [
            ['type' => 'file', 'source' => 'packages/ai-universal-rules/docs/operations/MCP-BOUNDARIES.md', 'target' => 'docs/ai/MCP-BOUNDARIES.md', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
        'advisor-pack' => [
            ['type' => 'dir', 'source' => 'tools/ai/advisor', 'target' => 'tools/ai/advisor', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => '.schemas/project-signals.schema.json', 'target' => '.schemas/project-signals.schema.json', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => '.schemas/project-scorecard.schema.json', 'target' => '.schemas/project-scorecard.schema.json', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
            ['type' => 'file', 'source' => '.schemas/advisor-recommendation.schema.json', 'target' => '.schemas/advisor-recommendation.schema.json', 'core' => false, 'merge_strategy' => 'skip-if-exists', 'required' => false],
        ],
    ];
}

function aiInstallerValidatePackRegistry(array $registry): array
{
    $errors = [];
    foreach ($registry as $packId => $items) {
        if (!is_array($items)) {
            $errors[] = "pack {$packId} must be a list";
            continue;
        }
        foreach ($items as $index => $item) {
            foreach (['source', 'target', 'merge_strategy', 'required'] as $field) {
                if (!array_key_exists($field, $item)) {
                    $errors[] = "pack {$packId} item {$index} missing {$field}";
                }
            }
        }
    }
    return $errors;
}

function aiInstallerResolveSelectedPacks(array $config, array $registry): array
{
    $profileDefs = aiInstallerProfileDefinitions();
    $profile = (string) ($config['profile'] ?? 'dual');
    $runtime = (string) ($config['runtime'] ?? 'both');
    $allFeatures = (bool) ($config['allFeatures'] ?? false);

    $packs = $allFeatures ? aiInstallerAllFeaturePacks() : ($profileDefs[$profile] ?? []);

    if (($config['installBase'] ?? true) && !in_array('base', $packs, true)) {
        $packs[] = 'base';
    }

    if ($runtime === 'github-copilot') {
        $packs = array_values(array_filter($packs, static fn(string $p): bool => $p !== 'adapter-opencode'));
        if (in_array($profile, ['copilot', 'dual', 'accelerated', 'full-governance'], true) && !in_array('adapter-copilot', $packs, true)) {
            $packs[] = 'adapter-copilot';
        }
    } elseif ($runtime === 'opencode') {
        $packs = array_values(array_filter($packs, static fn(string $p): bool => $p !== 'adapter-copilot'));
        if (in_array($profile, ['opencode', 'dual', 'accelerated', 'full-governance'], true) && !in_array('adapter-opencode', $packs, true)) {
            $packs[] = 'adapter-opencode';
        }
    }

    foreach (($config['withPacks'] ?? []) as $pack) {
        if (!in_array($pack, $packs, true)) {
            $packs[] = $pack;
        }
    }
    foreach (($config['withoutPacks'] ?? []) as $pack) {
        $packs = array_values(array_filter($packs, static fn(string $v): bool => $v !== $pack));
    }

    $packs = array_values(array_unique($packs));
    $packs = array_values(array_filter($packs, static fn(string $pack): bool => isset($registry[$pack])));
    return $packs;
}

function aiInstallerPackToolRequirements(array $selectedPacks): array
{
    $required = [];
    $optional = [];
    if (in_array('scripts-pack', $selectedPacks, true)) {
        $required = array_merge($required, ['bash', 'git', 'jq', 'rg', 'repomix', 'scc']);
        $optional = array_merge($optional, ['fd', 'gh', 'fzf', 'bat', 'delta', 'yq', 'shellcheck', 'semgrep', 'ast-grep']);
    }
    return [
        'required' => array_values(array_unique($required)),
        'optional' => array_values(array_unique($optional)),
    ];
}
