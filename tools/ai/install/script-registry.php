<?php

declare(strict_types=1);

function aiInstallerScriptRegistry(): array
{
    return [
        'repomix-context' => [
            'label' => 'Generate Repomix context bundle',
            'source_path' => 'scripts/copilot/run-repomix-context.sh',
            'installed_path' => 'scripts/ai/run-repomix-context.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'repomix'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
        'repomix-tree' => [
            'label' => 'Generate Repomix context tree',
            'source_path' => 'scripts/copilot/repomix-context-tree.sh',
            'installed_path' => 'scripts/ai/repomix-context-tree.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'repomix'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
        'repomix-scc-router' => [
            'label' => 'Generate SCC-ranked Repomix context',
            'source_path' => 'scripts/copilot/repomix-scc-router.sh',
            'installed_path' => 'scripts/ai/repomix-scc-router.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'jq', 'rg', 'repomix', 'scc'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
        'pack-context' => [
            'label' => 'Pack AI context bundle',
            'source_path' => 'scripts/copilot/pack-context.sh',
            'installed_path' => 'scripts/ai/pack-context.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'jq', 'rg'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
    ];
}
