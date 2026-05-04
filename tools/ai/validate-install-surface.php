<?php

declare(strict_types=1);

require_once __DIR__ . '/install/packs.php';
require_once __DIR__ . '/install/profiles.php';
require_once __DIR__ . '/install/script-registry.php';

$root = realpath(__DIR__ . '/..' . '/..');
if ($root === false) {
    fwrite(STDERR, "ERROR: repository root not found\n");
    exit(1);
}

$strict = in_array('--strict', $argv, true);
$errors = [];
$warnings = [];

$packs = aiInstallerPackRegistry();
$profiles = aiInstallerProfileDefinitions();
$scripts = aiInstallerScriptRegistry();

foreach (aiInstallerValidatePackRegistry($packs) as $error) {
    $errors[] = $error;
}

foreach ($packs as $packId => $items) {
    foreach ($items as $index => $item) {
        $type = (string) ($item['type'] ?? '');
        $source = (string) ($item['source'] ?? '');
        $target = (string) ($item['target'] ?? '');

        if (!in_array($type, ['file', 'dir'], true)) {
            $errors[] = "pack {$packId} item {$index} has unsupported type '{$type}'";
        }

        if ($source === '') {
            $errors[] = "pack {$packId} item {$index} has empty source";
        } else {
            $sourceAbs = $root . '/' . str_replace('\\', '/', $source);
            if ($type === 'file' && !is_file($sourceAbs)) {
                $errors[] = "pack {$packId} item {$index} missing file source {$source}";
            }
            if ($type === 'dir' && !is_dir($sourceAbs)) {
                $errors[] = "pack {$packId} item {$index} missing dir source {$source}";
            }
        }

        if ($target === '') {
            $errors[] = "pack {$packId} item {$index} has empty target";
        }
        if (str_starts_with($target, '/') || str_starts_with($target, './') || str_contains($target, '..')) {
            $errors[] = "pack {$packId} item {$index} has non-normalized target {$target}";
        }
    }
}

$knownProfiles = array_fill_keys(array_keys($profiles), true);
$knownPacks = array_fill_keys(array_keys($packs), true);
foreach ($profiles as $profileId => $items) {
    foreach ((array) $items as $item) {
        $key = (string) $item;
        if (!isset($knownProfiles[$key]) && !isset($knownPacks[$key])) {
            $errors[] = "profile {$profileId} references unknown pack/profile {$key}";
        }
    }

    $expanded = aiInstallerExpandProfilePacks((array) $items, $profiles, $packs);
    if ($profileId !== 'custom' && $expanded === []) {
        $errors[] = "profile {$profileId} resolves to no packs";
    }
}

$packSources = [];
$packTargets = [];
foreach ($packs as $items) {
    foreach ($items as $item) {
        $packSources[] = (string) ($item['source'] ?? '');
        $packTargets[] = (string) ($item['target'] ?? '');
    }
}

foreach ($scripts as $id => $script) {
    $pack = (string) ($script['pack'] ?? '');
    $sourcePath = (string) ($script['source_path'] ?? '');
    $installedPath = (string) ($script['installed_path'] ?? '');

    if (!isset($packs[$pack])) {
        $errors[] = "script {$id} references unknown pack {$pack}";
    }

    if ($sourcePath === '' || !is_file($root . '/' . $sourcePath)) {
        $errors[] = "script {$id} source_path missing {$sourcePath}";
    }

    if ($installedPath === '') {
        $errors[] = "script {$id} has empty installed_path";
    }

    if (!in_array($sourcePath, $packSources, true)) {
        $errors[] = "script {$id} source_path is not listed in pack registry: {$sourcePath}";
    }
    if (!in_array($installedPath, $packTargets, true)) {
        $errors[] = "script {$id} installed_path is not listed in pack registry: {$installedPath}";
    }
}

$opencodeAgentNames = collectAgentNames($root . '/packages/ai-universal-rules/templates/core/agents', '.md');
$githubAgentNames = $opencodeAgentNames;

$opencodeCommands = array_merge(
    glob($root . '/packages/ai-universal-rules/templates/workflows/*.md') ?: [],
    glob($root . '/packages/ai-universal-rules/templates/commands/*.md') ?: []
);
foreach ($opencodeCommands as $commandFile) {
    $content = (string) file_get_contents($commandFile);
    $agent = frontmatterField($content, 'agent');
    if ($agent !== null && $agent !== '' && !in_array($agent, $opencodeAgentNames, true)) {
        $errors[] = relativePath($root, $commandFile) . " references missing opencode agent '{$agent}'";
    }
}

$allowedNext = ['verify', 'user', 'planner', 'implement', 'refactorer'];

foreach (glob($root . '/packages/ai-universal-rules/templates/core/agents/*.md') ?: [] as $agentFile) {
    foreach (extractRecommendedNextSteps((string) file_get_contents($agentFile)) as $candidate) {
        if (!in_array($candidate, $allowedNext, true) && !in_array($candidate, $opencodeAgentNames, true)) {
            $errors[] = relativePath($root, $agentFile) . " has unknown Recommended Next Step '{$candidate}'";
        }
    }
}

$hasReviewerCommand = false;
foreach ($opencodeCommands as $commandFile) {
    if (basename($commandFile) === 'review-diff.md') {
        $hasReviewerCommand = true;
    }
}
if (in_array('reviewer', $opencodeAgentNames, true) && !$hasReviewerCommand) {
    $warnings[] = 'opencode reviewer agent exists but review-diff command is missing';
}

// Verify workflow template parity: every template must produce a Copilot prompt, Copilot skill, and OpenCode skill
$workflowTemplates = glob($root . '/packages/ai-universal-rules/templates/workflows/*.md') ?: [];
foreach ($workflowTemplates as $tpl) {
    $name = pathinfo($tpl, PATHINFO_FILENAME);
    $promptFile = $root . '/.github/prompts/' . $name . '.prompt.md';
    $copilotSkillDir = $root . '/.github/skills/' . $name . '/SKILL.md';
    $opencodeSkillDir = $root . '/.opencode/skills/' . $name . '/SKILL.md';
    if (!is_file($promptFile)) {
        $errors[] = "workflow template '{$name}' missing installed Copilot prompt: .github/prompts/{$name}.prompt.md";
    }
    if (!is_file($copilotSkillDir)) {
        $errors[] = "workflow template '{$name}' missing installed Copilot skill: .github/skills/{$name}/SKILL.md";
    }
    if (!is_file($opencodeSkillDir)) {
        $errors[] = "workflow template '{$name}' missing installed OpenCode skill: .opencode/skills/{$name}/SKILL.md";
    }
    $tplContent = (string) file_get_contents($tpl);
    if (str_contains($tplContent, 'compatibility: opencode')) {
        $errors[] = "workflow template '{$name}' has runtime-specific 'compatibility: opencode' which limits Copilot use — remove it";
    }
}

// Verify Copilot agent surface: every .github/agents/*.agent.md must use VS Code-native format
$copilotAgentFiles = glob($root . '/.github/agents/*.agent.md') ?: [];
foreach ($copilotAgentFiles as $agentFile) {
    $content = (string) file_get_contents($agentFile);
    $agentName = basename($agentFile);
    // Extract frontmatter block between first --- markers
    $fmBlock = '';
    if (preg_match('/^---\n([\s\S]*?)\n---/', $content, $fmMatch)) {
        $fmBlock = $fmMatch[1];
    }
    if (!preg_match('/^name:\s+\S/m', $fmBlock)) {
        $errors[] = "Copilot agent '{$agentName}' is missing 'name:' frontmatter field — must use VS Code-native format, not OpenCode format";
    }
    if (!preg_match('/^tools:\s*\[/m', $fmBlock)) {
        $errors[] = "Copilot agent '{$agentName}' is missing 'tools:' frontmatter field — add a Copilot tools list";
    }
    if (preg_match('/^tools:\s*\[[^\]]*(?:^|,\s*)["\'](read|search|edit|execute)["\'](?:\s*,|\s*$)/m', $fmBlock)) {
        $errors[] = "Copilot agent '{$agentName}' still uses broad tool aliases — switch to fine-grained VS Code tool names";
    }
    if (preg_match('/^id:\s+\S/m', $fmBlock)) {
        $errors[] = "Copilot agent '{$agentName}' has 'id:' frontmatter — this is OpenCode format; Copilot agents use 'name:'";
    }
    if (preg_match('/^permission:/m', $fmBlock)) {
        $errors[] = "Copilot agent '{$agentName}' has 'permission:' block — this is OpenCode format; remove it from Copilot agents";
    }
    // Check for unresolved SCRIPTS_ROOT placeholder
    if (str_contains($content, '<SCRIPTS_ROOT>')) {
        $errors[] = "Copilot agent '{$agentName}' still has unresolved '<SCRIPTS_ROOT>' placeholder — run install with placeholder resolution";
    }
}

// Verify stronger Copilot enforcement files are present when Copilot agents are installed.
if ($copilotAgentFiles !== []) {
    $scriptRegistryMd = $root . '/docs/ai/script-registry.md';
    $scriptRegistryJson = $root . '/docs/ai/script-registry.json';
    $toolPolicyFile = $root . '/.github/hooks/tool-policy.json';
    $workspaceSettingsFile = $root . '/.vscode/settings.json';

    if (!is_file($scriptRegistryMd)) {
        $errors[] = 'docs/ai/script-registry.md is missing — Copilot script allowlisting docs are required for the stronger enforcement surface';
    }
    if (!is_file($scriptRegistryJson)) {
        $errors[] = 'docs/ai/script-registry.json is missing — Copilot script allowlisting data is required for the stronger enforcement surface';
    }
    if (!is_file($toolPolicyFile)) {
        $errors[] = '.github/hooks/tool-policy.json is missing — Copilot hook policy is required for stronger terminal enforcement';
    }
    if (!is_file($workspaceSettingsFile)) {
        $warnings[] = '.vscode/settings.json is missing — VS Code sandbox and terminal auto-approval defaults are not installed';
    } else {
        $workspaceSettings = (string) file_get_contents($workspaceSettingsFile);
        foreach ([
            'chat.tools.terminal.ignoreDefaultAutoApproveRules',
            'chat.tools.terminal.blockDetectedFileWrites',
            'chat.agent.sandbox.enabled',
            'chat.agent.networkFilter',
        ] as $settingKey) {
            if (!str_contains($workspaceSettings, $settingKey)) {
                $warnings[] = ".vscode/settings.json should set {$settingKey} for a stronger Copilot enforcement posture";
            }
        }
    }
}

// Prompt files should not widen tool grants beyond the selected agent.
$copilotPromptFiles = glob($root . '/.github/prompts/*.prompt.md') ?: [];
foreach ($copilotPromptFiles as $promptFile) {
    $promptContent = (string) file_get_contents($promptFile);
    $promptName = basename($promptFile);
    if (preg_match('/^tools:\s*\[[^\]]*(?:^|,\s*)["\'](\*|read|search|edit|execute|agent|web|todo)["\'](?:\s*,|\s*$)/m', $promptContent)) {
        $errors[] = "Copilot prompt '{$promptName}' declares broad tools — prompt files must not widen the target agent tool surface";
    }
}

// Verify tools.instructions.md is present for Copilot
$toolsInstructionsFile = $root . '/.github/instructions/tools.instructions.md';
if (!is_file($toolsInstructionsFile) && is_dir($root . '/.github/instructions')) {
    $warnings[] = 'tools.instructions.md is missing from .github/instructions/ — tool enforcement may not be active';
}

foreach ($warnings as $warning) {
    fwrite(STDOUT, "WARN: {$warning}\n");
}
foreach ($errors as $error) {
    fwrite(STDERR, "ERROR: {$error}\n");
}

if ($errors === []) {
    fwrite(STDOUT, "OK: install surface validation passed\n");
}

exit(($errors !== [] || ($strict && $warnings !== [])) ? 1 : 0);

function collectAgentNames(string $directory, string $suffix): array
{
    $names = [];
    foreach (glob($directory . '/*' . $suffix) ?: [] as $path) {
        $filename = basename($path);
        $names[] = str_ends_with($filename, $suffix)
            ? substr($filename, 0, -strlen($suffix))
            : $filename;
    }
    sort($names);
    return array_values(array_unique($names));
}

function frontmatterField(string $content, string $field): ?string
{
    if (preg_match('/^---\R(.*?)\R---\R/s', $content, $matches) !== 1) {
        return null;
    }

    if (preg_match('/^' . preg_quote($field, '/') . ':\s*(.+)$/m', $matches[1], $fieldMatch) !== 1) {
        return null;
    }

    return trim((string) $fieldMatch[1], " \t\n\r\0\x0B\"'");
}

function extractRecommendedNextSteps(string $content): array
{
    $lines = preg_split('/\R/', $content) ?: [];
    $capture = false;
    $steps = [];

    foreach ($lines as $line) {
        if (preg_match('/^##\s+Recommended Next Step\b/i', $line) === 1) {
            $capture = true;
            continue;
        }

        if ($capture && preg_match('/^##\s+/', $line) === 1) {
            break;
        }

        if (!$capture) {
            continue;
        }

        if (preg_match('/^\s*-\s+(.+)$/', $line, $m) !== 1) {
            continue;
        }

        $value = trim((string) $m[1]);
        $value = preg_replace('/\s+if\s+blocked.*$/i', '', $value) ?? $value;
        $value = trim($value);
        if ($value !== '' && preg_match('/^[a-z][a-z-]*$/', $value) === 1) {
            $steps[] = $value;
        }
    }

    return array_values(array_unique($steps));
}

function relativePath(string $root, string $absolute): string
{
    return str_replace('\\', '/', substr($absolute, strlen($root) + 1));
}
