<?php

declare(strict_types=1);

require_once __DIR__ . '/profiles.php';
require_once __DIR__ . '/packs.php';
require_once __DIR__ . '/script-registry.php';
require_once __DIR__ . '/toolchain-registry.php';

function aiInstallerBuildInstalledInstructionsData(string $targetRoot, array $manifest): array
{
    $profile = (string) ($manifest['profile'] ?? 'unknown');
    $packs = is_array($manifest['packs'] ?? null) ? $manifest['packs'] : [];
    $files = is_array($manifest['files'] ?? null) ? array_keys($manifest['files']) : [];
    sort($files);

    $scripts = [];
    foreach (aiInstallerScriptRegistry() as $id => $entry) {
        if (in_array((string) ($entry['pack'] ?? ''), $packs, true)) {
            $scripts[] = [
                'id' => $id,
                'label' => (string) ($entry['label'] ?? $id),
                'path' => (string) ($entry['installed_path'] ?? ''),
                'required_tools' => $entry['required_tools'] ?? [],
            ];
        }
    }

    $toolReq = aiInstallerPackToolRequirements($packs);

    return [
        'installed_at' => (string) ($manifest['installed_at'] ?? 'unknown'),
        'profile' => $profile,
        'packs' => $packs,
        'files' => $files,
        'scripts' => $scripts,
        'required_tools' => $toolReq['required'] ?? [],
        'optional_tools' => $toolReq['optional'] ?? [],
        'commands' => [
            'verify' => 'php tools/ai/ai.php verify --json',
            'placeholders' => 'php tools/ai/ai.php placeholders --fail',
            'toolchain_check' => 'php tools/ai/ai.php toolchain --with repomix,scc --check',
            'toolchain_plan' => 'php tools/ai/ai.php toolchain --with repomix,scc --install-plan',
            'scripts_list' => 'php tools/ai/ai.php run-script --list',
        ],
    ];
}

function aiInstallerRenderInstalledInstructionsMarkdown(array $data): string
{
    $md = "# Install Instructions\n\n";
    $md .= "- Installed at: `" . ($data['installed_at'] ?? 'unknown') . "`\n";
    $md .= "- Profile: `" . ($data['profile'] ?? 'unknown') . "`\n";
    $md .= "- Packs: `" . implode(', ', $data['packs'] ?? []) . "`\n\n";

    $md .= "## Before Install\n\n";
    $md .= "1. Run dry-run first.\n";
    $md .= "2. Confirm profile and optional packs.\n";
    $md .= "3. Check required tools for selected packs.\n\n";

    $md .= "## During Install\n\n";
    $md .= "- Dry-run: `php tools/ai/ai.php install --profile " . ($data['profile'] ?? 'dual') . " --dry-run`\n";
    $md .= "- Backup: `php tools/ai/ai.php install --backup-only --apply --profile " . ($data['profile'] ?? 'dual') . "`\n";
    $md .= "- Apply: `php tools/ai/ai.php install --apply --profile " . ($data['profile'] ?? 'dual') . " --backup <backup-id>`\n\n";

    $md .= "## After Install\n\n";
    $md .= "- Verify: `" . ($data['commands']['verify'] ?? 'php tools/ai/ai.php verify --json') . "`\n";
    $md .= "- Resolve placeholders: `" . ($data['commands']['placeholders'] ?? 'php tools/ai/ai.php placeholders --fail') . "`\n";
    $md .= "- Toolchain check: `" . ($data['commands']['toolchain_check'] ?? 'php tools/ai/ai.php toolchain --check') . "`\n";
    $md .= "- Script list: `" . ($data['commands']['scripts_list'] ?? 'php tools/ai/ai.php run-script --list') . "`\n\n";

    $md .= "## Installed Scripts\n\n";
    if (($data['scripts'] ?? []) === []) {
        $md .= "- none\n";
    } else {
        foreach ($data['scripts'] as $script) {
            $md .= "- `" . ($script['id'] ?? '') . "` -> `" . ($script['path'] ?? '') . "`\n";
        }
    }

    $md .= "\n## Installed Files\n\n";
    foreach ($data['files'] ?? [] as $file) {
        $md .= "- `{$file}`\n";
    }

    return $md;
}

function aiInstallerBuildCatalogData(string $root): array
{
    $profiles = aiInstallerProfileDefinitions();
    $packs = aiInstallerPackRegistry();
    $scripts = aiInstallerScriptRegistry();
    $tools = aiInstallerToolchainRegistry();

    $packSummary = [];
    foreach ($packs as $id => $items) {
        $packSummary[] = ['id' => $id, 'item_count' => is_array($items) ? count($items) : 0];
    }

    return [
        'profiles' => $profiles,
        'packs' => $packSummary,
        'scripts' => $scripts,
        'toolchain' => $tools,
    ];
}

function aiInstallerRenderCatalogMarkdown(array $data): string
{
    $md = "# Install Catalog\n\n";
    $md .= "Deterministic catalog generated from installer registries.\n\n";
    $md .= "## Profiles\n\n";
    foreach (($data['profiles'] ?? []) as $id => $packs) {
        $md .= "- `{$id}`: `" . implode(', ', (array) $packs) . "`\n";
    }
    $md .= "\n## Packs\n\n";
    foreach (($data['packs'] ?? []) as $pack) {
        $md .= "- `" . ($pack['id'] ?? '') . "` (" . (int) ($pack['item_count'] ?? 0) . " items)\n";
    }
    $md .= "\n## Script IDs\n\n";
    foreach (($data['scripts'] ?? []) as $id => $script) {
        $md .= "- `{$id}` -> `" . (string) ($script['installed_path'] ?? '') . "`\n";
    }
    $md .= "\n## Toolchain\n\n";
    foreach (($data['toolchain'] ?? []) as $id => $tool) {
        $md .= "- `{$id}`";
        if (!empty($tool['safe_auto_install'])) {
            $md .= " (safe auto-install)";
        }
        $md .= "\n";
    }
    return $md;
}

function aiInstallerWriteInstallDocs(string $targetRoot, array $manifest): array
{
    $docsRoot = $targetRoot . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai';
    $generated = $docsRoot . DIRECTORY_SEPARATOR . 'generated';
    aiInstallerMkdir($docsRoot);
    aiInstallerMkdir($generated);

    $data = aiInstallerBuildInstalledInstructionsData($targetRoot, $manifest);
    $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
    $md = aiInstallerRenderInstalledInstructionsMarkdown($data);

    $jsonPath = $generated . DIRECTORY_SEPARATOR . 'install-instructions.json';
    $mdPath = $generated . DIRECTORY_SEPARATOR . 'install-instructions.md';
    file_put_contents($jsonPath, $json);
    file_put_contents($mdPath, $md);

    return ['json' => $jsonPath, 'md' => $mdPath, 'data' => $data];
}

function aiInstallerWriteCatalogDocs(string $root): array
{
    $generated = $root . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'generated';
    aiInstallerMkdir($generated);
    aiInstallerMkdir($root . DIRECTORY_SEPARATOR . 'packages' . DIRECTORY_SEPARATOR . 'ai-universal-rules' . DIRECTORY_SEPARATOR . 'docs');

    $data = aiInstallerBuildCatalogData($root);
    $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
    $md = aiInstallerRenderCatalogMarkdown($data);

    $jsonPath = $generated . DIRECTORY_SEPARATOR . 'install-catalog.json';
    $mdPath = $generated . DIRECTORY_SEPARATOR . 'install-catalog.md';
    $pkgMdPath = $root . DIRECTORY_SEPARATOR . 'packages' . DIRECTORY_SEPARATOR . 'ai-universal-rules' . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'INSTALL-CATALOG.md';
    file_put_contents($jsonPath, $json);
    file_put_contents($mdPath, $md);
    file_put_contents($pkgMdPath, $md);

    return ['json' => $jsonPath, 'md' => $mdPath, 'package_md' => $pkgMdPath, 'data' => $data];
}

function aiInstallerCheckCatalogDocs(string $root): array
{
    $generated = $root . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'generated';
    $jsonPath = $generated . DIRECTORY_SEPARATOR . 'install-catalog.json';
    $mdPath = $generated . DIRECTORY_SEPARATOR . 'install-catalog.md';
    $pkgMdPath = $root . DIRECTORY_SEPARATOR . 'packages' . DIRECTORY_SEPARATOR . 'ai-universal-rules' . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'INSTALL-CATALOG.md';

    $data = aiInstallerBuildCatalogData($root);
    $jsonExpected = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
    $mdExpected = aiInstallerRenderCatalogMarkdown($data);

    $drift = [];
    if (!is_file($jsonPath) || (string) file_get_contents($jsonPath) !== $jsonExpected) {
        $drift[] = 'docs/ai/generated/install-catalog.json';
    }
    if (!is_file($mdPath) || (string) file_get_contents($mdPath) !== $mdExpected) {
        $drift[] = 'docs/ai/generated/install-catalog.md';
    }
    if (!is_file($pkgMdPath) || (string) file_get_contents($pkgMdPath) !== $mdExpected) {
        $drift[] = 'packages/ai-universal-rules/docs/INSTALL-CATALOG.md';
    }

    return ['drift' => $drift, 'data' => $data];
}
