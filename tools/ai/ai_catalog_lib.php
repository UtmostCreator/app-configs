<?php

declare(strict_types=1);

function aiRepoRoot(): string
{
    $root = realpath(__DIR__ . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . '..');

    if ($root === false) {
        throw new RuntimeException('Could not resolve repository root.');
    }

    return $root;
}

function aiNormalizePath(string $path): string
{
    return str_replace('\\', '/', $path);
}

function aiAbsolutePath(string $root, string $relativePath): string
{
    return $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relativePath);
}

function aiNormalizeGeneratedContent(string $content): string
{
    return str_replace("\r\n", "\n", $content);
}

function aiReadFile(string $root, string $relativePath): string
{
    $content = @file_get_contents(aiAbsolutePath($root, $relativePath));

    if ($content === false) {
        throw new RuntimeException("Unable to read {$relativePath}.");
    }

    return $content;
}

function aiLoadJson(string $root, string $relativePath): array
{
    $decoded = json_decode(aiReadFile($root, $relativePath), true);

    if (!is_array($decoded)) {
        throw new RuntimeException("Invalid JSON in {$relativePath}.");
    }

    return $decoded;
}

function aiParseFrontMatter(string $content): array
{
    if (!str_starts_with($content, "---\n")) {
        return [];
    }

    $end = strpos($content, "\n---\n", 4);

    if ($end === false) {
        return [];
    }

    $block = substr($content, 4, $end - 4);
    $lines = preg_split('/\r?\n/', $block) ?: [];
    $data = [];

    foreach ($lines as $line) {
        if (!str_contains($line, ':')) {
            continue;
        }

        [$key, $value] = explode(':', $line, 2);
        $key = trim($key);
        $value = trim($value);
        $value = trim($value, " \t\n\r\0\x0B\"'");
        $data[$key] = $value;
    }

    return $data;
}

function aiExtractTitle(string $content, string $fallback): string
{
    if (preg_match('/^#\s+(.+)$/m', $content, $matches) === 1) {
        return trim($matches[1]);
    }

    return $fallback;
}

function aiSummarizeMarkdown(string $content): ?string
{
    $lines = preg_split('/\r?\n/', $content) ?: [];

    foreach ($lines as $line) {
        $trimmed = trim($line);

        if ($trimmed === '' || str_starts_with($trimmed, '#') || str_starts_with($trimmed, '---')) {
            continue;
        }

        return $trimmed;
    }

    return null;
}

function aiResource(string $scope, string $type, string $name, string $path, ?string $description = null, ?string $runtime = null, array $extra = []): array
{
    return array_merge([
        'scope' => $scope,
        'type' => $type,
        'name' => $name,
        'path' => aiNormalizePath($path),
        'runtime' => $runtime,
        'description' => $description,
    ], $extra);
}

function aiCollectCatalog(string $root): array
{
    $manifest = aiLoadJson($root, 'packages/ai-universal-rules/manifest.json');
    $resources = [];

    foreach (aiCollectRootResources($root) as $resource) {
        $resources[] = $resource;
    }

    foreach (aiCollectPackageResources($root) as $resource) {
        $resources[] = $resource;
    }

    foreach (aiCollectExampleResources($root) as $resource) {
        $resources[] = $resource;
    }

    usort(
        $resources,
        static fn (array $left, array $right): int => [$left['scope'], $left['type'], $left['path']] <=> [$right['scope'], $right['type'], $right['path']]
    );

    $counts = [];

    foreach ($resources as $resource) {
        $key = $resource['scope'] . ':' . $resource['type'];
        $counts[$key] = ($counts[$key] ?? 0) + 1;
    }

    ksort($counts);

    return [
        '$schema' => '../../.schemas/ai-catalog.schema.json',
        'generated_by' => 'php tools/ai/generate-ai-catalog.php',
        'repository' => [
            'name' => 'app-configs',
            'summary' => 'Opinionated development configuration plus a reusable cross-tool AI workflow kit.',
            'catalog_docs' => [
                'docs/ai/catalog.md',
                'packages/ai-universal-rules/docs/BROWSE.md',
                'llms.txt',
            ],
        ],
        'package' => [
            'name' => $manifest['name'],
            'version' => $manifest['version'],
            'description' => $manifest['description'],
            'supported_tools' => $manifest['supported_tools'],
            'supported_surfaces' => $manifest['supported_surfaces'],
            'generated_outputs' => $manifest['generated_outputs'],
        ],
        'counts' => $counts,
        'resources' => $resources,
        'starter_profiles' => $manifest['starter_profiles'],
    ];
}

function aiCollectRootResources(string $root): array
{
    $resources = [];

    $rootDocMap = [
        'docs/ai/copilot-getting-started.md' => ['root-doc', 'copilot-getting-started', 'Quick-start onboarding for Copilot setup, read order, and end-to-end task examples.'],
        'docs/ai/project-context.md' => ['root-doc', 'project-context-doc', 'Durable repository context for instructions, capabilities, and adapters.'],
        'docs/ai/workflow.md' => ['root-doc', 'workflow', 'Default live workflow for risk, verification, and docs sync.'],
        'docs/ai/agent-ops.md' => ['root-doc', 'agent-ops', 'AgentOps model for observability, evaluation, optimization, IAM, and architecture routing.'],
        'docs/ai/agents.md' => ['root-doc', 'agents', 'Durable live-agent reference plus package-agent index for later lookup.'],
        'docs/ai/failure-handling.md' => ['root-doc', 'failure-handling', 'Failure taxonomy, retry policy, corrected usage guidance, and logging contract.'],
        'docs/ai/agent-ops-checklist.md' => ['root-doc', 'agent-ops-checklist', 'Phased verification checklist for auditing AI workflow integration in the live repo.'],
        'docs/ai/integration-matrix.md' => ['root-doc', 'integration-matrix', 'Coverage map that tracks which AI workflow concepts are covered, partial, or missing.'],
        'docs/ai/AI-GUARDRAILS.md' => ['root-doc', 'AI Guardrails', 'Cross-tool guardrails for approval boundaries, evidence, and recurring failure modes.'],
        'docs/ai/capabilities/agent-observability-and-evidence/EVENT_SCHEMA.md' => ['root-doc', 'agent-evidence-schema', 'Structured evidence event model for traceable agent runs on supported runtimes.'],
        'docs/ai/capabilities/agent-observability-and-evidence/FAILURE_TAXONOMY.md' => ['root-doc', 'agent-failure-taxonomy', 'Normalized failure categories for agent evidence events and taxonomy mapping guidance.'],
        'docs/ai/capabilities/evaluation-and-regression/GOLDEN_TASKS.md' => ['root-doc', 'evaluation-golden-tasks', 'Golden-task patterns for behavior-regression checks in agent workflows.'],
        'docs/ai/capabilities/evaluation-and-regression/REPLAY_RULES.md' => ['root-doc', 'evaluation-replay-rules', 'Replay rules for reproducing and classifying failed or ambiguous agent runs.'],
        'docs/ai/capabilities/evaluation-and-regression/HUMAN_REVIEW_RULES.md' => ['root-doc', 'evaluation-human-review-rules', 'Human-review triggers and decision record expectations for risky agent outcomes.'],
        'docs/ai/capabilities/preview-environments/LIFECYCLE.md' => ['root-doc', 'preview-lifecycle', 'Vendor-neutral lifecycle and TTL expectations for temporary preview environments.'],
        'docs/ai/capabilities/preview-environments/DATA_AND_SECRET_RULES.md' => ['root-doc', 'preview-data-and-secrets', 'Data and secret isolation rules for preview environments.'],
        'docs/ai/capabilities/preview-environments/CHECKLIST.md' => ['root-doc', 'preview-checklist', 'Checklist for preview-environment readiness, evidence, and cleanup.'],
    ];

    foreach ($rootDocMap as $relativePath => [$type, $name, $description]) {
        if (!is_file(aiAbsolutePath($root, $relativePath))) {
            continue;
        }

        $resources[] = aiResource('root', $type, $name, $relativePath, $description, 'canonical');
    }

    $rootScriptMap = [
        'scripts/copilot/common.sh' => ['copilot-script', 'common.sh', 'Shared helper library for Copilot wrappers, logging, snapshots, and token-budget checks.'],
        'scripts/copilot/ai-search.sh' => ['copilot-script', 'ai-search.sh', 'Unified search entrypoint for text, file, tracked, all, and structural discovery.'],
        'scripts/copilot/ai-edit.sh' => ['copilot-script', 'ai-edit.sh', 'Guarded broad-edit wrapper with snapshots, dry-run behavior, visible diff, and optional verification.'],
        'scripts/copilot/ai-verify.sh' => ['copilot-script', 'ai-verify.sh', 'Project-aware verification gate for AI-driven changes across shell, PHP, JS/TS, and security checks.'],
        'scripts/copilot/ai-diff-context.sh' => ['copilot-script', 'ai-diff-context.sh', 'Incremental context packer for changed files, PR slices, recent changes, and touched areas.'],
        'scripts/copilot/ai-rollback.sh' => ['copilot-script', 'ai-rollback.sh', 'Rollback helper for explicit recovery work using session snapshots and refs.'],
        'scripts/copilot/rg-code.sh' => ['copilot-script', 'rg-code.sh', 'Mode-aware ripgrep wrapper with JSON, file-list, count, and context output modes.'],
        'scripts/copilot/gh-pr-context.sh' => ['copilot-script', 'gh-pr-context.sh', 'GitHub PR context wrapper with metadata, diff, checks, reviews, and optional PR-scoped context packing.'],
        'scripts/copilot/repomix-scc-router.sh' => ['copilot-script', 'repomix-scc-router.sh', 'Ranked context router that produces TSV and JSON bundle plans with churn-aware scoring.'],
        'scripts/copilot/watch-loop.sh' => ['copilot-script', 'watch-loop.sh', 'Watch-based verification loop with debounce and repo-local session logging.'],
        'policies/copilot/policy.yaml' => ['copilot-policy', 'policy.yaml', 'Declarative allow, deny, and confirm rules for the Copilot command policy surface.'],
        '.schemas/evidence-event.schema.json' => ['copilot-schema', 'evidence-event.schema.json', 'JSON schema for durable agent evidence events emitted by supported runtime surfaces.'],
    ];

    foreach ($rootScriptMap as $relativePath => [$type, $name, $description]) {
        if (!is_file(aiAbsolutePath($root, $relativePath))) {
            continue;
        }

        $resources[] = aiResource('root', $type, $name, $relativePath, $description, 'github-copilot');
    }

    $phpReferenceMap = [
        'reference/php/design-patterns' => ['php-reference', 'design-patterns', 'Primary local PHP design pattern corpus for agent and human lookups.'],
        'reference/php/design-principles' => ['php-reference', 'design-principles', 'Secondary PHP principles and composition examples.'],
        'reference/php/php-built-ins' => ['php-reference', 'php-built-ins', 'Supporting PHP built-in usage examples.'],
    ];

    foreach ($phpReferenceMap as $relativePath => [$type, $name, $description]) {
        if (!file_exists(aiAbsolutePath($root, $relativePath))) {
            continue;
        }

        $resources[] = aiResource('root', $type, $name, $relativePath, $description, 'php');
    }

    $capabilityPaths = glob(aiAbsolutePath($root, 'docs/ai/capabilities/*/CAPABILITY.md')) ?: [];
    sort($capabilityPaths);

    foreach ($capabilityPaths as $path) {
        $relativePath = substr(aiNormalizePath($path), strlen(aiNormalizePath($root)) + 1);
        $name = basename(dirname($path));
        $content = file_get_contents($path) ?: '';
        $resources[] = aiResource('root', 'capability', $name, $relativePath, aiSummarizeMarkdown($content), 'canonical');
    }

    $agentPaths = glob(aiAbsolutePath($root, '.github/agents/*.agent.md')) ?: [];
    sort($agentPaths);

    foreach ($agentPaths as $path) {
        $relativePath = substr(aiNormalizePath($path), strlen(aiNormalizePath($root)) + 1);
        $content = file_get_contents($path) ?: '';
        $frontMatter = aiParseFrontMatter($content);
        $resources[] = aiResource('root', 'github-copilot-agent', $frontMatter['name'] ?? basename($path), $relativePath, $frontMatter['description'] ?? null, 'github-copilot');
    }

    $instructionPaths = glob(aiAbsolutePath($root, '.github/instructions/*.instructions.md')) ?: [];
    sort($instructionPaths);

    foreach ($instructionPaths as $path) {
        $relativePath = substr(aiNormalizePath($path), strlen(aiNormalizePath($root)) + 1);
        $content = file_get_contents($path) ?: '';
        $frontMatter = aiParseFrontMatter($content);
        $resources[] = aiResource('root', 'github-copilot-instruction', basename($path, '.instructions.md'), $relativePath, $frontMatter['description'] ?? null, 'github-copilot');
    }

    if (is_file(aiAbsolutePath($root, '.github/hooks/tool-guardian.json'))) {
        $resources[] = aiResource('root', 'hook', 'tool-guardian', '.github/hooks/tool-guardian.json', 'Protects the live repo with a narrow Copilot hook guard.', 'github-copilot');
    }

    $resources[] = aiResource('root', 'validator', 'validate-ai-config', 'tools/ai/validate-ai-config.php', 'Validates the root live AI workflow layer.', 'php');
    $resources[] = aiResource('root', 'validator', 'validate-ai-catalog', 'tools/ai/validate-ai-catalog.php', 'Validates manifest, catalog, and starter profile metadata.', 'php');
    $resources[] = aiResource('root', 'generator', 'generate-ai-catalog', 'tools/ai/generate-ai-catalog.php', 'Generates catalog docs, catalog JSON, and llms.txt.', 'php');
    $resources[] = aiResource('root', 'exporter', 'export-ai-universal-rules', 'tools/ai/export-ai-universal-rules.php', 'Builds starter-profile release bundles under dist/.', 'php');

    return $resources;
}

function aiCollectPackageResources(string $root): array
{
    $resources = [];
    $prefixMap = [
        'packages/ai-universal-rules/templates/core/' => ['core-template', 'canonical'],
        'packages/ai-universal-rules/templates/shared/' => ['shared-template', 'canonical'],
        'packages/ai-universal-rules/templates/capabilities/' => ['package-capability', 'canonical'],
        'packages/ai-universal-rules/templates/opencode/agents/' => ['opencode-agent-template', 'opencode'],
        'packages/ai-universal-rules/templates/opencode/commands/' => ['opencode-command-template', 'opencode'],
        'packages/ai-universal-rules/templates/opencode/skills/' => ['opencode-skill-template', 'opencode'],
        'packages/ai-universal-rules/templates/github-copilot/agents/' => ['github-copilot-agent-template', 'github-copilot'],
        'packages/ai-universal-rules/templates/github-copilot/instructions/' => ['github-copilot-instruction-template', 'github-copilot'],
        'packages/ai-universal-rules/templates/github-copilot/prompts/' => ['github-copilot-prompt-template', 'github-copilot'],
        'packages/ai-universal-rules/templates/optional/' => ['optional-template', 'optional'],
        'packages/ai-universal-rules/docs/foundations/' => ['foundation-doc', 'canonical'],
        'packages/ai-universal-rules/docs/workflows/' => ['workflow-doc', 'canonical'],
        'packages/ai-universal-rules/docs/operations/' => ['operations-doc', 'canonical'],
    ];

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator(aiAbsolutePath($root, 'packages/ai-universal-rules'), FilesystemIterator::SKIP_DOTS)
    );

    foreach ($iterator as $file) {
        if (!$file->isFile()) {
            continue;
        }

        $relativePath = substr(aiNormalizePath($file->getPathname()), strlen(aiNormalizePath($root)) + 1);

        if (in_array($relativePath, ['packages/ai-universal-rules/catalog.json', 'packages/ai-universal-rules/docs/BROWSE.md', 'packages/ai-universal-rules/manifest.json', 'packages/ai-universal-rules/manifest.yml'], true)) {
            continue;
        }

        foreach ($prefixMap as $prefix => [$type, $runtime]) {
            if (!str_starts_with($relativePath, $prefix)) {
                continue;
            }

            $content = file_get_contents($file->getPathname()) ?: '';
            $frontMatter = aiParseFrontMatter($content);
            $defaultName = pathinfo($file->getFilename(), PATHINFO_FILENAME);
            $name = $frontMatter['name'] ?? aiExtractTitle($content, $defaultName);
            $description = $frontMatter['description'] ?? aiSummarizeMarkdown($content);
            $resources[] = aiResource('package', $type, $name, $relativePath, $description, $runtime);
            break;
        }
    }

    return $resources;
}

function aiCollectExampleResources(string $root): array
{
    $resources = [];

    $exampleDirectories = glob(aiAbsolutePath($root, 'packages/ai-universal-rules/examples/*'), GLOB_ONLYDIR) ?: [];
    sort($exampleDirectories);

    foreach ($exampleDirectories as $directory) {
        $relativePath = substr(aiNormalizePath($directory), strlen(aiNormalizePath($root)) + 1);
        $files = aiListFilesInDirectory($directory);

        if ($files === []) {
            continue;
        }

        $runtime = aiDetectExampleRuntime($files);
        $entrypoints = aiCollectExampleEntrypoints($files, $relativePath);
        $assetCounts = aiCountExampleAssets($files);
        $readmePath = aiFindExampleReadme($files);
        $title = aiExampleTitle($root, $relativePath, $readmePath, $files);
        $description = aiDescribeExample($root, $relativePath, $runtime, $readmePath, $files, $assetCounts);

        $resources[] = aiResource(
            'package',
            'example-repo',
            $title,
            $relativePath,
            $description,
            $runtime,
            [
                'entrypoints' => $entrypoints,
                'asset_counts' => $assetCounts,
            ]
        );
    }

    return $resources;
}

function aiRenderRootCatalogMarkdown(array $catalog): string
{
    $lines = [];
    $lines[] = '# AI Catalog';
    $lines[] = '';
    $lines[] = '_Generated by `php tools/ai/generate-ai-catalog.php`. Do not edit by hand._';
    $lines[] = '';
    $lines[] = 'This generated file is the live inventory for AI workflow assets in this repository and the reusable `packages/ai-universal-rules/` package.';
    $lines[] = '';
    $lines[] = 'Use `docs/ai/copilot-getting-started.md` for quick onboarding, then use this catalog when you need the full indexed list of agents, instructions, hooks, prompts, scripts, capabilities, and docs.';
    $lines[] = '';
    $lines[] = '## Highlights';
    $lines[] = '';
    foreach ($catalog['counts'] as $key => $count) {
        [$scope, $type] = explode(':', $key, 2);
        $lines[] = '- `' . $scope . ' / ' . $type . '` - ' . $count;
    }
    $lines[] = '';
    $lines[] = '## Live Repo Resources';
    $lines[] = '';
    $lines = array_merge($lines, aiRenderTableRows($catalog['resources'], 'root'));
    $lines[] = '';
    $lines[] = '## AI Universal Rules Package';
    $lines[] = '';
    $lines = array_merge($lines, aiRenderTableRows($catalog['resources'], 'package'));
    $lines[] = '';
    $lines[] = '## Starter Profiles';
    $lines[] = '';
    $lines[] = '| Profile | Description |';
    $lines[] = '| --- | --- |';
    foreach ($catalog['starter_profiles'] as $profile) {
        $lines[] = '| `' . $profile['id'] . '` | ' . $profile['description'] . ' |';
    }
    $lines[] = '';
    $lines[] = '## Validation Commands';
    $lines[] = '';
    $lines[] = '- `php tools/ai/validate-ai-config.php`';
    $lines[] = '- `php tools/ai/validate-ai-catalog.php`';
    $lines[] = '- `php tools/ai/generate-ai-catalog.php --check`';
    $lines[] = '- `php tools/ai/export-ai-universal-rules.php --check`';

    return implode("\n", $lines) . "\n";
}

function aiRenderBrowseMarkdown(array $catalog): string
{
    $package = $catalog['package'];
    $lines = [];
    $lines[] = '# Browse';
    $lines[] = '';
    $lines[] = '_Generated by `php tools/ai/generate-ai-catalog.php`. Do not edit by hand._';
    $lines[] = '';
    $lines[] = '`' . $package['name'] . '` v`' . $package['version'] . '` packages the reusable workflow model behind this repository.';
    $lines[] = '';
    $lines[] = '## Package Outputs';
    $lines[] = '';
    foreach ($package['generated_outputs'] as $output) {
        $lines[] = '- `' . $output . '`';
    }
    $lines[] = '';
    $lines[] = '## Package Resources';
    $lines[] = '';
    $lines = array_merge($lines, aiRenderTableRows($catalog['resources'], 'package'));
    $lines[] = '';
    $lines[] = '## Starter Profiles';
    $lines[] = '';
    $starterProfiles = $catalog['starter_profiles'];
    $starterCount = count($starterProfiles);
    foreach ($starterProfiles as $index => $profile) {
        $lines[] = '### `' . $profile['id'] . '`';
        $lines[] = '';
        $lines[] = $profile['description'];
        $lines[] = '';
        foreach ($profile['includes'] as $include) {
            $lines[] = '- `' . $include . '`';
        }
        if ($index < $starterCount - 1) {
            $lines[] = '';
        }
    }

    return implode("\n", $lines) . "\n";
}

function aiRenderLlms(array $catalog): string
{
    $lines = [];
    $lines[] = '# app-configs';
    $lines[] = '';
    $lines[] = '> Opinionated development configuration plus a reusable cross-tool AI workflow kit.';
    $lines[] = '';
    $lines[] = '## Primary Docs';
    $lines[] = '';
    $lines[] = '- [README.md](README.md): root overview, quick start, and repo layout';
    $lines[] = '- [AGENTS.md](AGENTS.md): durable repository instructions';
    $lines[] = '- [docs/ai/copilot-getting-started.md](docs/ai/copilot-getting-started.md): minimal Copilot install map and read order';
    $lines[] = '- [docs/ai/project-context.md](docs/ai/project-context.md): live repository context';
    $lines[] = '- [docs/ai/workflow.md](docs/ai/workflow.md): live task flow';
    $lines[] = '- [docs/ai/agents.md](docs/ai/agents.md): live agent reference and package agent index';
    $lines[] = '- [docs/ai/failure-handling.md](docs/ai/failure-handling.md): command-failure taxonomy and retry policy';
    $lines[] = '- [docs/ai/agent-ops-checklist.md](docs/ai/agent-ops-checklist.md): phased verification checklist for integration audits';
    $lines[] = '- [docs/ai/integration-matrix.md](docs/ai/integration-matrix.md): concept coverage map for the live workflow layer';
    $lines[] = '- [docs/ai/catalog.md](docs/ai/catalog.md): generated browse index for live and package assets';
    $lines[] = '';
    $lines[] = '## Reusable Kit';
    $lines[] = '';
    $lines[] = '- [packages/ai-universal-rules/README.md](packages/ai-universal-rules/README.md): package overview and operating model';
    $lines[] = '- [packages/ai-universal-rules/QUICKSTART.md](packages/ai-universal-rules/QUICKSTART.md): fastest install path';
    $lines[] = '- [packages/ai-universal-rules/docs/BROWSE.md](packages/ai-universal-rules/docs/BROWSE.md): generated package catalog';
    $lines[] = '- [packages/ai-universal-rules/manifest.json](packages/ai-universal-rules/manifest.json): machine-readable package manifest';
    $lines[] = '';
    $lines[] = '## Contribution And Trust';
    $lines[] = '';
    $lines[] = '- [CONTRIBUTING.md](CONTRIBUTING.md): contribution rules and generated file workflow';
    $lines[] = '- [SECURITY.md](SECURITY.md): security reporting';
    $lines[] = '- [SUPPORT.md](SUPPORT.md): support expectations and reporting guidance';
    $lines[] = '';
    $lines[] = '## Validation';
    $lines[] = '';
    $lines[] = '- `php tools/ai/validate-ai-config.php`';
    $lines[] = '- `php tools/ai/validate-ai-catalog.php`';
    $lines[] = '- `php tools/ai/generate-ai-catalog.php --check`';
    $lines[] = '- `php tools/ai/export-ai-universal-rules.php --check`';

    return implode("\n", $lines) . "\n";
}

function aiRenderTableRows(array $resources, string $scope): array
{
    $lines = [];
    $lines[] = '| Type | Name | Path | Description |';
    $lines[] = '| --- | --- | --- | --- |';

    foreach ($resources as $resource) {
        if ($resource['scope'] !== $scope) {
            continue;
        }

        $description = $resource['description'] ?? '';

        if ($resource['type'] === 'example-repo') {
            $details = [];

            if (!empty($resource['runtime'])) {
                $details[] = 'runtime: `' . $resource['runtime'] . '`';
            }

            if (!empty($resource['entrypoints']) && is_array($resource['entrypoints'])) {
                $details[] = 'entrypoints: ' . implode(', ', array_map(static fn (string $entrypoint): string => '`' . $entrypoint . '`', $resource['entrypoints']));
            }

            if (!empty($resource['asset_counts']) && is_array($resource['asset_counts'])) {
                $countParts = [];

                foreach ($resource['asset_counts'] as $key => $count) {
                    if ($count === 0) {
                        continue;
                    }

                    $countParts[] = $key . ' ' . $count;
                }

                if ($countParts !== []) {
                    $details[] = 'assets: ' . implode(', ', $countParts);
                }
            }

            if ($details !== []) {
                $description .= ' (' . implode('; ', $details) . ')';
            }
        }

        $lines[] = '| `' . $resource['type'] . '` | ' . aiEscapeTable($resource['name']) . ' | `' . $resource['path'] . '` | ' . aiEscapeTable($description) . ' |';
    }

    return $lines;
}

function aiListFilesInDirectory(string $directory): array
{
    $files = [];
    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($directory, FilesystemIterator::SKIP_DOTS)
    );

    foreach ($iterator as $file) {
        if ($file->isFile()) {
            $files[] = aiNormalizePath($file->getPathname());
        }
    }

    sort($files);

    return $files;
}

function aiDetectExampleRuntime(array $files): string
{
    $hasCopilot = false;
    $hasOpenCode = false;

    foreach ($files as $file) {
        if (str_contains($file, '/.github/')) {
            $hasCopilot = true;
        }

        if (str_contains($file, '/.opencode/')) {
            $hasOpenCode = true;
        }
    }

    if ($hasCopilot && $hasOpenCode) {
        return 'dual-runtime';
    }

    if ($hasCopilot) {
        return 'github-copilot';
    }

    if ($hasOpenCode) {
        return 'opencode';
    }

    return 'reference';
}

function aiCollectExampleEntrypoints(array $files, string $relativeDirectory): array
{
    $entrypointSuffixes = [
        '/README.md',
        '/AGENTS.md',
        '/CLAUDE.md',
        '/.github/copilot-instructions.md',
        '/docs/ai/project-context.md',
        '/docs/ai/workflow.md',
    ];
    $entrypoints = [];

    foreach ($files as $file) {
        foreach ($entrypointSuffixes as $suffix) {
            if (str_ends_with($file, $suffix)) {
                $entrypoints[] = ltrim(substr($file, strlen(aiNormalizePath(aiRepoRoot())) + 1 + strlen($relativeDirectory)), '/');
                break;
            }
        }
    }

    sort($entrypoints);

    return array_slice(array_values(array_unique($entrypoints)), 0, 6);
}

function aiCountExampleAssets(array $files): array
{
    $counts = [
        'agents' => 0,
        'instructions' => 0,
        'prompts' => 0,
        'commands' => 0,
        'skills' => 0,
        'capabilities' => 0,
    ];

    foreach ($files as $file) {
        if (str_ends_with($file, '.agent.md')) {
            $counts['agents']++;
        }

        if (str_ends_with($file, '.instructions.md')) {
            $counts['instructions']++;
        }

        if (str_ends_with($file, '.prompt.md')) {
            $counts['prompts']++;
        }

        if (str_contains($file, '/.opencode/commands/') && str_ends_with($file, '.md')) {
            $counts['commands']++;
        }

        if (str_ends_with($file, '/SKILL.md')) {
            $counts['skills']++;
        }

        if (str_ends_with($file, '/CAPABILITY.md')) {
            $counts['capabilities']++;
        }
    }

    return $counts;
}

function aiFindExampleReadme(array $files): ?string
{
    foreach ($files as $file) {
        if (str_ends_with($file, '/README.md')) {
            return $file;
        }
    }

    return null;
}

function aiExampleTitle(string $root, string $relativeDirectory, ?string $readmePath, array $files): string
{
    $slug = basename($relativeDirectory);
    $preferredTitles = [
        'generic-placeholder-repo' => 'Generic Placeholder Starter',
        'expanded-placeholder-repo' => 'Expanded Placeholder Blueprint',
        'worked-opencode-repo' => 'Acme Orders OpenCode Service',
        'worked-copilot-repo' => 'Acme Web Copilot Workspace',
        'worked-dual-tool-repo' => 'Acme Commerce Dual-Tool Monorepo',
    ];

    if (isset($preferredTitles[$slug])) {
        return $preferredTitles[$slug];
    }

    if ($readmePath !== null) {
        $content = file_get_contents($readmePath) ?: '';
        $title = aiExtractTitle($content, '');

        if ($title !== '' && preg_match('/<[^>]+>/', $title) !== 1) {
            return aiNormalizeExampleTitle($title);
        }
    }

    foreach ($files as $file) {
        if (!str_ends_with($file, '/AGENTS.md')) {
            continue;
        }

        $content = file_get_contents($file) ?: '';
        $title = aiExtractTitle($content, '');

        if ($title !== '' && preg_match('/<[^>]+>/', $title) !== 1) {
            return aiNormalizeExampleTitle($title);
        }
    }

    return aiPrettifyExampleSlug($slug);
}

function aiDescribeExample(string $root, string $relativeDirectory, string $runtime, ?string $readmePath, array $files, array $assetCounts): string
{
    $slug = basename($relativeDirectory);

    if ($readmePath !== null) {
        $content = file_get_contents($readmePath) ?: '';
        $summary = aiSummarizeMarkdown($content);

        if ($summary !== null && preg_match('/<[^>]+>/', $summary) !== 1) {
            return $summary;
        }
    }

    foreach ($files as $file) {
        if (!str_ends_with($file, '/AGENTS.md')) {
            continue;
        }

        $content = file_get_contents($file) ?: '';
        $summary = aiSummarizeMarkdown($content);

        if ($summary !== null && preg_match('/<[^>]+>/', $summary) !== 1) {
            return $summary;
        }
    }

    $fallbacks = [
        'generic-placeholder-repo' => 'Minimal placeholder example that shows folder placement for a shared dual-runtime starter.',
        'expanded-placeholder-repo' => 'Expanded placeholder example that shows the richer filled-out structure without becoming project-specific.',
        'worked-opencode-repo' => 'Worked OpenCode-first service example with staged agents, commands, and capability-driven verification.',
        'worked-copilot-repo' => 'Worked GitHub Copilot example with repo instructions, path guidance, staged agents, and prompt entry points.',
        'worked-dual-tool-repo' => 'Worked dual-runtime monorepo example with one shared capability layer adapted to OpenCode and GitHub Copilot.',
    ];

    if (isset($fallbacks[$slug])) {
        return $fallbacks[$slug];
    }

    $assetBits = [];

    foreach ($assetCounts as $key => $count) {
        if ($count > 0) {
            $assetBits[] = $count . ' ' . $key;
        }
    }

    if ($runtime === 'dual-runtime') {
        return 'Worked dual-runtime example with both Copilot and OpenCode adapters' . ($assetBits !== [] ? ' across ' . implode(', ', $assetBits) : '') . '.';
    }

    if ($runtime === 'github-copilot') {
        return 'Worked GitHub Copilot example for the reusable workflow kit' . ($assetBits !== [] ? ' across ' . implode(', ', $assetBits) : '') . '.';
    }

    if ($runtime === 'opencode') {
        return 'Worked OpenCode example for the reusable workflow kit' . ($assetBits !== [] ? ' across ' . implode(', ', $assetBits) : '') . '.';
    }

    return 'Reference example `' . $slug . '` for package structure and placeholder layout.';
}

function aiNormalizeExampleTitle(string $title): string
{
    $normalized = trim($title);
    $normalized = preg_replace('/\s*-\s*Repository Instructions$/', '', $normalized) ?? $normalized;
    $normalized = preg_replace('/\s*-\s*Shared Agent Guidance$/', '', $normalized) ?? $normalized;

    return $normalized;
}

function aiPrettifyExampleSlug(string $slug): string
{
    $words = array_map(
        static fn (string $part): string => ucfirst($part),
        preg_split('/-+/', $slug) ?: []
    );

    return implode(' ', $words);
}

function aiEscapeTable(string $value): string
{
    return str_replace('|', '\\|', $value);
}

function aiWriteIfChanged(string $absolutePath, string $content): bool
{
    $existing = is_file($absolutePath) ? file_get_contents($absolutePath) : false;

    if ($existing === $content) {
        return false;
    }

    $directory = dirname($absolutePath);

    if (!is_dir($directory) && !mkdir($directory, 0777, true) && !is_dir($directory)) {
        throw new RuntimeException("Unable to create {$directory}.");
    }

    file_put_contents($absolutePath, $content);

    return true;
}

function aiCompareOrWrite(string $root, string $relativePath, string $content, bool $checkOnly, array &$messages): bool
{
    $absolutePath = aiAbsolutePath($root, $relativePath);
    $existing = is_file($absolutePath) ? file_get_contents($absolutePath) : false;
    $normalizedContent = aiNormalizeGeneratedContent($content);

    if ($existing !== false && aiNormalizeGeneratedContent($existing) === $normalizedContent) {
        $messages[] = "OK: {$relativePath} is up to date";
        return true;
    }

    if ($checkOnly) {
        $messages[] = "ERROR: {$relativePath} is out of date";
        return false;
    }

    aiWriteIfChanged($absolutePath, $normalizedContent);
    $messages[] = "OK: regenerated {$relativePath}";

    return true;
}

function aiValidateManifest(array $manifest, string $root): array
{
    $errors = [];

    foreach (['name', 'version', 'description', 'supported_tools', 'supported_surfaces', 'workflow_layers', 'required_templates', 'runtime_entrypoints', 'generated_outputs', 'starter_profiles', 'release'] as $key) {
        if (!array_key_exists($key, $manifest)) {
            $errors[] = "manifest.json missing {$key}";
        }
    }

    foreach ($manifest['required_templates'] ?? [] as $path) {
        if (!file_exists(aiAbsolutePath($root, 'packages/ai-universal-rules/' . ltrim($path, '/')))) {
            $errors[] = "manifest.json references missing template {$path}";
        }
    }

    foreach ($manifest['generated_outputs'] ?? [] as $path) {
        if (!is_string($path) || $path === '') {
            $errors[] = 'manifest.json generated_outputs entries must be non-empty strings';
        }
    }

    foreach ($manifest['starter_profiles'] ?? [] as $profile) {
        if (!is_array($profile) || !isset($profile['id'], $profile['description'], $profile['includes'])) {
            $errors[] = 'manifest.json starter_profiles entries must contain id, description, and includes';
            continue;
        }

        foreach ($profile['includes'] as $include) {
            if (!file_exists(aiAbsolutePath($root, 'packages/ai-universal-rules/' . ltrim($include, '/')))) {
                $errors[] = "starter profile {$profile['id']} references missing path {$include}";
            }
        }
    }

    return $errors;
}

function aiReadManifestYamlSummary(string $root): array
{
    $content = aiReadFile($root, 'packages/ai-universal-rules/manifest.yml');
    $summary = [];

    foreach (preg_split('/\r?\n/', $content) ?: [] as $line) {
        if (preg_match('/^(name|version|description):\s*(.+)$/', trim($line), $matches) === 1) {
            if (!array_key_exists($matches[1], $summary)) {
                $summary[$matches[1]] = trim($matches[2]);
            }
        }
    }

    return $summary;
}

function aiCopyPath(string $source, string $destination): void
{
    if (is_file($source)) {
        $parent = dirname($destination);

        if (!is_dir($parent) && !mkdir($parent, 0777, true) && !is_dir($parent)) {
            throw new RuntimeException("Unable to create {$parent}.");
        }

        copy($source, $destination);
        return;
    }

    if (!is_dir($source)) {
        throw new RuntimeException("Missing export source {$source}.");
    }

    if (!is_dir($destination) && !mkdir($destination, 0777, true) && !is_dir($destination)) {
        throw new RuntimeException("Unable to create {$destination}.");
    }

    $iterator = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator($source, FilesystemIterator::SKIP_DOTS),
        RecursiveIteratorIterator::SELF_FIRST
    );

    foreach ($iterator as $item) {
        $target = $destination . DIRECTORY_SEPARATOR . $iterator->getSubPathName();

        if ($item->isDir()) {
            if (!is_dir($target)) {
                mkdir($target, 0777, true);
            }

            continue;
        }

        $parent = dirname($target);

        if (!is_dir($parent)) {
            mkdir($parent, 0777, true);
        }

        copy($item->getPathname(), $target);
    }
}
