<?php

declare(strict_types=1);

function aiInstallerScriptRegistry(): array
{
    return [
        'repomix-context' => [
            'label' => 'Generate Repomix context bundle',
            'source_path' => 'scripts/ai/run-repomix-context.sh',
            'installed_path' => 'scripts/ai/run-repomix-context.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'repomix'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
        'repomix-tree' => [
            'label' => 'Generate Repomix context tree',
            'source_path' => 'scripts/ai/repomix-context-tree.sh',
            'installed_path' => 'scripts/ai/repomix-context-tree.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'repomix'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
        'repomix-scc-router' => [
            'label' => 'Generate SCC-ranked Repomix context',
            'source_path' => 'scripts/ai/repomix-scc-router.sh',
            'installed_path' => 'scripts/ai/repomix-scc-router.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'jq', 'rg', 'repomix', 'scc'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
        'pack-context' => [
            'label' => 'Pack AI context bundle',
            'source_path' => 'scripts/ai/pack-context.sh',
            'installed_path' => 'scripts/ai/pack-context.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git', 'jq', 'rg'],
            'risk' => 'read-only',
            'supports_dry_run' => true,
            'default_args' => [],
        ],
        'repo-tool-inventory' => [
            'label' => 'Generate/check required tools inventory doc',
            'source_path' => 'scripts/ai/repo-tool-inventory.sh',
            'installed_path' => 'scripts/ai/repo-tool-inventory.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash', 'git'],
            'risk' => 'read-only',
            'supports_dry_run' => false,
            'default_args' => [],
        ],
        'install-mandatory-tools' => [
            'label' => 'Install mandatory CLI tools by OS',
            'source_path' => 'scripts/ai/install-mandatory-tools.sh',
            'installed_path' => 'scripts/ai/install-mandatory-tools.sh',
            'pack' => 'scripts-pack',
            'required_tools' => ['bash'],
            'risk' => 'mutating',
            'supports_dry_run' => true,
            'default_args' => ['--dry-run'],
        ],
    ];
}
