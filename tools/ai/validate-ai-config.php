<?php

declare(strict_types=1);

$root = realpath(__DIR__ . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . '..');

if ($root === false) {
    fwrite(STDERR, "ERROR: could not resolve repository root\n");
    exit(1);
}

$requiredFiles = [
    'README.md',
    'AGENTS.md',
    'CLAUDE.md',
    'docs/ai/project-context.md',
    'docs/ai/workflow.md',
    'docs/ai/agents.md',
    'docs/ai/failure-handling.md',
    'docs/ai/agent-ops-checklist.md',
    'docs/ai/integration-matrix.md',
    'docs/ai/AI-GUARDRAILS.md',
    'docs/ai/catalog.md',
    'docs/ai/capabilities/README.md',
    'docs/ai/capabilities/authorization-and-tool-governance/CAPABILITY.md',
    'docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md',
    'docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md',
    'docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md',
    'docs/ai/capabilities/evaluation-and-regression/CAPABILITY.md',
    'docs/ai/capabilities/evaluation-and-regression/GOLDEN_TASKS.md',
    'docs/ai/capabilities/evaluation-and-regression/REPLAY_RULES.md',
    'docs/ai/capabilities/evaluation-and-regression/HUMAN_REVIEW_RULES.md',
    'docs/ai/capabilities/preview-environments/CAPABILITY.md',
    'docs/ai/capabilities/preview-environments/LIFECYCLE.md',
    'docs/ai/capabilities/preview-environments/DATA_AND_SECRET_RULES.md',
    'docs/ai/capabilities/preview-environments/CHECKLIST.md',
    'docs/ai/capabilities/service-boundary-patterns/CAPABILITY.md',
    '.github/copilot-instructions.md',
    '.github/instructions/php.instructions.md',
    'scripts/copilot/common.sh',
    'scripts/copilot/ai-diff-context.sh',
    'scripts/copilot/ai-search.sh',
    'scripts/copilot/ai-edit.sh',
    'scripts/copilot/ai-verify.sh',
    'scripts/copilot/ai-rollback.sh',
    'policies/copilot/policy.yaml',
    '.schemas/evidence-event.schema.json',
    '.copilot-logs/README.md',
    'packages/ai-universal-rules/manifest.json',
    'packages/ai-universal-rules/catalog.json',
    'packages/ai-universal-rules/docs/BROWSE.md',
    'llms.txt',
];

$requiredDirectories = [
    'reference/php/design-patterns',
    'reference/php/design-principles',
    'reference/php/php-built-ins',
];

$liveFiles = [
    'README.md',
    'AGENTS.md',
    'CLAUDE.md',
    'docs/ai/project-context.md',
    'docs/ai/workflow.md',
    'docs/ai/agents.md',
    'docs/ai/failure-handling.md',
    'docs/ai/agent-ops-checklist.md',
    'docs/ai/integration-matrix.md',
    'docs/ai/AI-GUARDRAILS.md',
    'docs/ai/catalog.md',
    'docs/ai/capabilities/README.md',
    '.github/copilot-instructions.md',
    '.github/instructions/ai-workflow.instructions.md',
    '.github/instructions/config.instructions.md',
    '.github/instructions/docs.instructions.md',
    '.github/agents/config-maintainer.agent.md',
    '.github/agents/workflow-auditor.agent.md',
    'docs/ai/capabilities/project-context/CAPABILITY.md',
    'docs/ai/capabilities/verify-change/CAPABILITY.md',
    'docs/ai/capabilities/review-diff/CAPABILITY.md',
    'docs/ai/capabilities/bug-regression/CAPABILITY.md',
    'docs/ai/capabilities/docs-sync/CAPABILITY.md',
    'docs/ai/capabilities/config-change-safety/CAPABILITY.md',
    'docs/ai/capabilities/authorization-and-tool-governance/CAPABILITY.md',
    'docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md',
    'docs/ai/capabilities/evaluation-and-regression/CAPABILITY.md',
    'docs/ai/capabilities/preview-environments/CAPABILITY.md',
    'docs/ai/capabilities/service-boundary-patterns/CAPABILITY.md',
    'packages/ai-universal-rules/manifest.json',
    'packages/ai-universal-rules/catalog.json',
    'packages/ai-universal-rules/docs/BROWSE.md',
    'CONTRIBUTING.md',
    'SECURITY.md',
    'SUPPORT.md',
    'llms.txt',
];

$bannedTerms = [
    'Statamic',
    'Nuxt',
    'Vue 3',
    'PHPUnit 11',
];

$generatedCatalogFiles = [
    'docs/ai/catalog.md',
    'packages/ai-universal-rules/catalog.json',
    'packages/ai-universal-rules/docs/BROWSE.md',
];

$errors = [];
$warnings = [];
$oks = [];

foreach ($requiredFiles as $relativePath) {
    if (!is_file($root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath))) {
        $errors[] = "missing required file: {$relativePath}";
    }
}

foreach ($liveFiles as $relativePath) {
    $absolutePath = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath);

    if (!is_file($absolutePath)) {
        continue;
    }

    $content = file_get_contents($absolutePath);

    if ($content === false) {
        $errors[] = "unable to read file: {$relativePath}";
        continue;
    }

    if (!in_array($relativePath, $generatedCatalogFiles, true) && preg_match('/<[^>]+>/', $content) === 1) {
        $errors[] = "placeholder leak found in {$relativePath}";
    }

    foreach ($bannedTerms as $term) {
        if (stripos($content, $term) !== false) {
            $warnings[] = "unexpected stack term '{$term}' in {$relativePath}";
        }
    }

    if (in_array($relativePath, $generatedCatalogFiles, true)) {
        continue;
    }

    foreach (extractBacktickPaths($content) as $path) {
        if (shouldSkipPathCheck($path)) {
            continue;
        }

        $normalizedPath = trim($path);
        $target = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $normalizedPath);

        if (!file_exists($target)) {
            $errors[] = "broken path reference in {$relativePath}: {$path}";
        }
    }
}

$agentsContent = safeRead($root, 'AGENTS.md');
$claudeContent = safeRead($root, 'CLAUDE.md');
$readmeContent = safeRead($root, 'README.md');
$copilotContent = safeRead($root, '.github/copilot-instructions.md');
$phpInstructionsContent = safeRead($root, '.github/instructions/php.instructions.md');
$projectContextContent = safeRead($root, 'docs/ai/project-context.md');
$agentsReferenceContent = safeRead($root, 'docs/ai/agents.md');

$liveAgentPaths = glob($root . DIRECTORY_SEPARATOR . '.github' . DIRECTORY_SEPARATOR . 'agents' . DIRECTORY_SEPARATOR . '*.agent.md') ?: [];

foreach ($liveAgentPaths as $path) {
    $relativePath = str_replace(DIRECTORY_SEPARATOR, '/', substr($path, strlen($root) + 1));

    if ($agentsReferenceContent !== null && strpos($agentsReferenceContent, $relativePath) === false) {
        $errors[] = "docs/ai/agents.md must reference live agent {$relativePath}";
    }
}

foreach ($requiredDirectories as $relativePath) {
    if (!is_dir($root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath))) {
        $errors[] = "missing required directory: {$relativePath}";
    }
}

$hookTargets = [
    '.github/hooks/tool-policy.json' => [
        'scripts/copilot/pre-tool-use.sh',
        'scripts/copilot/post-tool-use.sh',
    ],
    '.github/hooks/tool-guardian.json' => [
        '.github/hooks/scripts/tool-guardian.ps1',
    ],
];

foreach ($hookTargets as $hookConfig => $targets) {
    if (!is_file($root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $hookConfig))) {
        continue;
    }

    foreach ($targets as $target) {
        if (!is_file($root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $target))) {
            $errors[] = "hook target missing for {$hookConfig}: {$target}";
        }
    }
}

if ($agentsContent !== null && strpos($agentsContent, 'docs/ai/project-context.md') === false) {
    $errors[] = 'AGENTS.md must reference docs/ai/project-context.md';
}

if ($agentsContent !== null && strpos($agentsContent, 'docs/ai/agents.md') === false) {
    $errors[] = 'AGENTS.md must reference docs/ai/agents.md';
}

if ($agentsContent !== null && strpos($agentsContent, 'docs/ai/failure-handling.md') === false) {
    $errors[] = 'AGENTS.md must reference docs/ai/failure-handling.md';
}

if ($agentsContent !== null && strpos($agentsContent, 'docs/ai/agent-ops-checklist.md') === false) {
    $warnings[] = 'AGENTS.md should reference docs/ai/agent-ops-checklist.md';
}

if ($agentsContent !== null && strpos($agentsContent, 'docs/ai/integration-matrix.md') === false) {
    $warnings[] = 'AGENTS.md should reference docs/ai/integration-matrix.md';
}

if ($copilotContent !== null && strpos($copilotContent, 'docs/ai/') === false) {
    $errors[] = '.github/copilot-instructions.md must reference docs/ai/';
}

if ($copilotContent !== null && stripos($copilotContent, 'approval-free') === false) {
    $warnings[] = '.github/copilot-instructions.md should document approval-free read-only commands';
}

if ($copilotContent !== null && strpos($copilotContent, 'docs/ai/failure-handling.md') === false) {
    $warnings[] = '.github/copilot-instructions.md should reference docs/ai/failure-handling.md';
}

if ($copilotContent !== null && strpos($copilotContent, 'docs/ai/agent-ops-checklist.md') === false) {
    $warnings[] = '.github/copilot-instructions.md should reference docs/ai/agent-ops-checklist.md';
}

if ($copilotContent !== null && strpos($copilotContent, 'docs/ai/integration-matrix.md') === false) {
    $warnings[] = '.github/copilot-instructions.md should reference docs/ai/integration-matrix.md';
}

if ($copilotContent !== null && strpos($copilotContent, 'docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md') === false) {
    $warnings[] = '.github/copilot-instructions.md should reference docs/ai/capabilities/agent-observability-and-evidence/CAPABILITY.md for traceable agent output expectations';
}

if ($copilotContent !== null && strpos($copilotContent, 'docs/ai/capabilities/evaluation-and-regression/CAPABILITY.md') === false) {
    $warnings[] = '.github/copilot-instructions.md should reference docs/ai/capabilities/evaluation-and-regression/CAPABILITY.md for behavior-regression expectations';
}

if ($copilotContent !== null && strpos($copilotContent, 'docs/ai/capabilities/preview-environments/CAPABILITY.md') === false) {
    $warnings[] = '.github/copilot-instructions.md should reference docs/ai/capabilities/preview-environments/CAPABILITY.md for temporary environment validation guidance';
}

if ($copilotContent !== null) {
    foreach (['reference/php/design-patterns/', 'reference/php/design-principles/', 'reference/php/php-built-ins/'] as $phpReferencePath) {
        if (strpos($copilotContent, $phpReferencePath) === false) {
            $warnings[] = ".github/copilot-instructions.md should reference {$phpReferencePath} for PHP guidance routing";
        }
    }
}

if ($phpInstructionsContent !== null) {
    foreach (['reference/php/design-patterns/', 'reference/php/design-principles/', 'reference/php/php-built-ins/'] as $phpReferencePath) {
        if (strpos($phpInstructionsContent, $phpReferencePath) === false) {
            $warnings[] = ".github/instructions/php.instructions.md should reference {$phpReferencePath}";
        }
    }
}

if ($projectContextContent !== null) {
    foreach (['reference/php/design-patterns/', 'reference/php/design-principles/', 'reference/php/php-built-ins/'] as $phpReferencePath) {
        if (strpos($projectContextContent, $phpReferencePath) === false) {
            $warnings[] = "docs/ai/project-context.md should reference {$phpReferencePath}";
        }
    }
}

$copilotToolingContent = safeRead($root, 'docs/ai/copilot-tooling.md');

if ($copilotToolingContent !== null) {
    foreach (['scripts/copilot/common.sh', 'scripts/copilot/ai-search.sh', 'scripts/copilot/ai-edit.sh', 'scripts/copilot/ai-verify.sh', 'scripts/copilot/ai-diff-context.sh', 'scripts/copilot/ai-rollback.sh', 'scripts/copilot/rg-code.sh', 'scripts/copilot/gh-pr-context.sh'] as $scriptReference) {
        if (strpos($copilotToolingContent, $scriptReference) === false) {
            $warnings[] = "docs/ai/copilot-tooling.md should reference {$scriptReference}";
        }
    }

    foreach (['bundle-plan.json', 'WATCH_DEBOUNCE_MS', 'failureCategory'] as $capabilityReference) {
        if (strpos($copilotToolingContent, $capabilityReference) === false) {
            $warnings[] = "docs/ai/copilot-tooling.md should mention {$capabilityReference} now that the stronger tool layer supports it";
        }
    }
}

$justfileContent = safeRead($root, 'justfile');

if ($justfileContent !== null) {
    foreach (['scripts/copilot/ai-search.sh', 'scripts/copilot/ai-edit.sh', 'scripts/copilot/ai-verify.sh', 'scripts/copilot/ai-diff-context.sh', 'scripts/copilot/ai-rollback.sh', 'scripts/copilot/gh-pr-context.sh', 'scripts/copilot/rg-code.sh', 'scripts/copilot/repomix-scc-router.sh'] as $scriptReference) {
        if (strpos($justfileContent, $scriptReference) === false) {
            $warnings[] = "justfile should expose {$scriptReference} when the script is part of the supported tool layer";
        }
    }

    foreach (['context-plan-since', 'context-pack-all-since', 'context-plan-json', 'verify', 'rollback-list'] as $recipeReference) {
        if (strpos($justfileContent, $recipeReference) === false) {
            $warnings[] = "justfile should expose {$recipeReference} for the stronger guarded tool surface";
        }
    }

    foreach (['php-patterns-search', 'php-principles-search', 'php-builtins-search', 'php-examples-map'] as $recipeReference) {
        if (strpos($justfileContent, $recipeReference) === false) {
            $warnings[] = "justfile should expose {$recipeReference} for PHP example corpus navigation";
        }
    }
}

if ($readmeContent !== null) {
    if (stripos($readmeContent, 'AI workflow') === false) {
        $warnings[] = 'README.md should describe the repo AI workflow purpose';
    }

    if (stripos($readmeContent, 'configuration') === false) {
        $warnings[] = 'README.md should describe the repo config purpose';
    }

    foreach (['reference/php/design-patterns/', 'reference/php/design-principles/', 'reference/php/php-built-ins/'] as $phpReferencePath) {
        if (strpos($readmeContent, $phpReferencePath) === false) {
            $warnings[] = "README.md should reference {$phpReferencePath} in AI workflow and tooling guidance";
        }
    }
}

if ($claudeContent !== null && strpos($claudeContent, 'docs/ai/') === false) {
    $warnings[] = 'CLAUDE.md should point back to canonical docs/ai guidance';
}

if ($claudeContent !== null && strpos($claudeContent, 'docs/ai/failure-handling.md') === false) {
    $warnings[] = 'CLAUDE.md should reference docs/ai/failure-handling.md';
}

if ($claudeContent !== null && strpos($claudeContent, 'docs/ai/agent-ops-checklist.md') === false) {
    $warnings[] = 'CLAUDE.md should reference docs/ai/agent-ops-checklist.md';
}

if ($claudeContent !== null && strpos($claudeContent, 'docs/ai/integration-matrix.md') === false) {
    $warnings[] = 'CLAUDE.md should reference docs/ai/integration-matrix.md';
}

if ($errors === [] && $warnings === []) {
    $oks[] = 'root AI workflow validation passed';
}

foreach ($oks as $message) {
    fwrite(STDOUT, "OK: {$message}\n");
}

foreach ($warnings as $message) {
    fwrite(STDOUT, "WARN: {$message}\n");
}

foreach ($errors as $message) {
    fwrite(STDERR, "ERROR: {$message}\n");
}

exit($errors === [] ? 0 : 1);

function safeRead(string $root, string $relativePath): ?string
{
    $absolutePath = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath);

    if (!is_file($absolutePath)) {
        return null;
    }

    $content = file_get_contents($absolutePath);

    return $content === false ? null : $content;
}

function extractBacktickPaths(string $content): array
{
    preg_match_all('/`([^`]+)`/', $content, $matches);

    $paths = [];

    foreach ($matches[1] as $candidate) {
        $trimmed = trim($candidate);

        if (
            str_contains($trimmed, '/') ||
            str_ends_with($trimmed, '.md') ||
            str_ends_with($trimmed, '.json') ||
            str_ends_with($trimmed, '.php') ||
            str_ends_with($trimmed, '.ps1')
        ) {
            $paths[] = $trimmed;
        }
    }

    return array_values(array_unique($paths));
}

function shouldSkipPathCheck(string $path): bool
{
    if ($path === '' || preg_match('/\s/', $path) === 1) {
        return true;
    }

    foreach (['*', '{', '}', '<', '>', 'http://', 'https://', ',', '->'] as $fragment) {
        if (str_contains($path, $fragment)) {
            return true;
        }
    }

    return false;
}
