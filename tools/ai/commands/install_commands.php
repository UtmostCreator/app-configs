<?php

declare(strict_types=1);

function aiPackageLockPath(string $root): string
{
    return $root . DIRECTORY_SEPARATOR . 'packages' . DIRECTORY_SEPARATOR . 'ai-universal-rules' . DIRECTORY_SEPARATOR . 'package-lock.ai.json';
}

function aiInstallManifestPath(string $root): string
{
    return $root . DIRECTORY_SEPARATOR . '.ai-install-manifest.json';
}

function aiInstallDerivedManifestPath(string $root): string
{
    return aiCliGeneratedDir($root) . DIRECTORY_SEPARATOR . 'install-manifest.json';
}

function aiHashPath(string $path): string
{
    if (is_file($path)) {
        return 'sha256:' . hash_file('sha256', $path);
    }
    if (!is_dir($path)) {
        return 'missing';
    }
    $parts = [];
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($path, FilesystemIterator::SKIP_DOTS));
    foreach ($it as $file) {
        if (!$file->isFile()) {
            continue;
        }
        $abs = $file->getPathname();
        $rel = str_replace('\\', '/', substr($abs, strlen($path) + 1));
        $parts[] = $rel . ':' . hash_file('sha256', $abs);
    }
    sort($parts);
    return 'sha256:' . hash('sha256', implode("\n", $parts));
}

function aiCollectTemplateChecksums(string $root): array
{
    $base = $root . DIRECTORY_SEPARATOR . 'packages' . DIRECTORY_SEPARATOR . 'ai-universal-rules' . DIRECTORY_SEPARATOR . 'templates';
    if (!is_dir($base)) {
        throw new RuntimeException('Missing package templates directory at packages/ai-universal-rules/templates');
    }

    $checksums = [];
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($base, FilesystemIterator::SKIP_DOTS));
    foreach ($it as $file) {
        if (!$file->isFile()) {
            continue;
        }
        $abs = $file->getPathname();
        $rel = 'templates/' . str_replace('\\', '/', substr($abs, strlen($base) + 1));
        $checksums[$rel] = 'sha256:' . hash_file('sha256', $abs);
    }
    ksort($checksums);
    return $checksums;
}

function aiRunPreflight(string $root): int
{
    $checks = [];

    $checks[] = ['name' => 'php_version', 'status' => version_compare(PHP_VERSION, '8.1.0', '>=') ? 'passed' : 'failed', 'required' => '>=8.1'];
    $checks[] = ['name' => 'ext_json', 'status' => extension_loaded('json') ? 'passed' : 'failed'];
    $checks[] = ['name' => 'ext_mbstring', 'status' => extension_loaded('mbstring') ? 'passed' : 'failed'];
    $checks[] = ['name' => 'ext_zip', 'status' => extension_loaded('zip') ? 'passed' : 'warning', 'reason' => extension_loaded('zip') ? null : 'ZipArchive unavailable; directory backup fallback will be used'];

    $gitOut = [];
    $gitExit = 0;
    exec('git --version', $gitOut, $gitExit);
    $checks[] = ['name' => 'git', 'status' => $gitExit === 0 ? 'passed' : 'failed'];

    $generated = aiCliGeneratedDir($root);
    $checks[] = ['name' => 'generated_dir_writable', 'status' => is_dir($generated) && is_writable($generated) ? 'passed' : 'failed'];

    $templates = $root . DIRECTORY_SEPARATOR . 'packages' . DIRECTORY_SEPARATOR . 'ai-universal-rules' . DIRECTORY_SEPARATOR . 'templates';
    $checks[] = ['name' => 'templates_readable', 'status' => is_dir($templates) && is_readable($templates) ? 'passed' : 'failed'];

    $failed = array_values(array_filter($checks, static fn(array $c): bool => ($c['status'] ?? 'failed') === 'failed'));
    $status = $failed === [] ? 'ok' : 'failed';
    $data = [
        'status' => $status,
        'checks' => $checks,
        'recommended_next_action' => $failed === [] ? 'Run package-verify then adapter-plan.' : 'Resolve failed checks before install/apply.',
    ];

    $written = aiCliWriteArtifact($root, 'preflight', 'php tools/ai/ai.php preflight', $data, $status, null, (string) $data['recommended_next_action']);
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $failed === [] ? 0 : 1;
}

function aiRunPackageLock(string $root, array $args): int
{
    $update = in_array('--update', $args, true);
    $check = in_array('--check', $args, true) || !$update;

    $checksums = aiCollectTemplateChecksums($root);
    $payload = [
        'schema_version' => 1,
        'package' => 'ai-universal-rules',
        'source_checksums' => $checksums,
    ];

    $path = aiPackageLockPath($root);
    if ($update) {
        file_put_contents($path, json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);
    }

    $existing = is_file($path) ? json_decode((string) file_get_contents($path), true) : null;
    $matches = is_array($existing) && ($existing['source_checksums'] ?? null) === $checksums;

    $data = [
        'path' => 'packages/ai-universal-rules/package-lock.ai.json',
        'mode' => $update ? 'update' : ($check ? 'check' : 'unknown'),
        'entry_count' => count($checksums),
        'matches' => $matches,
    ];

    $status = $matches ? 'ok' : ($update ? 'ok' : 'failed');
    $next = $matches ? 'Package lock matches template sources.' : 'Run package-lock --update to refresh checksums.';
    $written = aiCliWriteArtifact($root, 'package-lock', 'php tools/ai/ai.php package-lock', $data, $status, null, $next);
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $status === 'ok' ? 0 : 1;
}

function aiRunPackageVerify(string $root): int
{
    $path = aiPackageLockPath($root);
    if (!is_file($path)) {
        throw new RuntimeException('Missing package lock file: packages/ai-universal-rules/package-lock.ai.json');
    }

    $lock = json_decode((string) file_get_contents($path), true);
    if (!is_array($lock)) {
        throw new RuntimeException('Invalid JSON in package lock file');
    }

    $expected = $lock['source_checksums'] ?? [];
    if (!is_array($expected)) {
        throw new RuntimeException('Invalid source_checksums in package lock file');
    }
    $current = aiCollectTemplateChecksums($root);

    $mismatches = [];
    foreach ($current as $file => $hash) {
        if (!isset($expected[$file])) {
            $mismatches[] = ['path' => $file, 'reason' => 'missing_from_lock', 'current' => $hash];
            continue;
        }
        if ((string) $expected[$file] !== $hash) {
            $mismatches[] = ['path' => $file, 'reason' => 'checksum_mismatch', 'expected' => (string) $expected[$file], 'current' => $hash];
        }
    }
    foreach ($expected as $file => $hash) {
        if (!isset($current[$file])) {
            $mismatches[] = ['path' => (string) $file, 'reason' => 'missing_from_templates', 'expected' => (string) $hash];
        }
    }

    $status = $mismatches === [] ? 'ok' : 'failed';
    $data = [
        'path' => 'packages/ai-universal-rules/package-lock.ai.json',
        'mismatch_count' => count($mismatches),
        'mismatches' => $mismatches,
    ];

    $written = aiCliWriteArtifact($root, 'package-verify', 'php tools/ai/ai.php package-verify', $data, $status, null, $status === 'ok' ? 'Source package integrity verified.' : 'Refresh lock or revert unintended template drift.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $status === 'ok' ? 0 : 1;
}

function aiRunAuditInstructions(string $root): int
{
    $surfaces = [
        '.github/copilot-instructions.md',
        'AGENTS.md',
        'CLAUDE.md',
        'GEMINI.md',
        'AI.md',
    ];

    $found = [];
    foreach ($surfaces as $path) {
        if (is_file($root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $path))) {
            $found[] = ['path' => $path, 'ownership_hint' => 'mixed_or_user'];
        }
    }

    $extra = [];
    exec('git -C ' . escapeshellarg($root) . ' ls-files ".github/instructions/*.instructions.md" ".opencode/**"', $extra);
    foreach ($extra as $path) {
        $found[] = ['path' => $path, 'ownership_hint' => 'runtime_adapter'];
    }

    $data = [
        'count' => count($found),
        'entries' => $found,
        'notes' => [
            'Copilot root instructions are broadly supported; sidecar support varies by surface.',
            'OpenCode project rules primarily use AGENTS.md.',
        ],
    ];
    $written = aiCliWriteArtifact($root, 'instruction-audit', 'php tools/ai/ai.php audit-instructions', $data, 'ok', null, 'Use adapter-plan to choose safe merge or sidecar-only mode.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiInstallerConfigFromAiArgs(string $root, array $args, bool $forceDryRun = false): array
{
    $normalized = [];
    for ($i = 0; $i < count($args); $i++) {
        $arg = (string) $args[$i];
        if (in_array($arg, ['--interactive', '--backup-only', '--apply', '--reinstall', '--no-interaction', '--agent', '--ci', '--wizard', '--yes'], true)) {
            continue;
        }
        if (in_array($arg, ['--backup', '--resolve'], true)) {
            $i++;
            continue;
        }
        if ($arg === '--targets') {
            $targetsRaw = (string) ($args[$i + 1] ?? 'copilot,opencode');
            $i++;
            $targets = array_values(array_filter(array_map('trim', explode(',', $targetsRaw)), static fn(string $v): bool => $v !== ''));
            if ($targets === ['copilot']) {
                $normalized[] = '--runtime';
                $normalized[] = 'github-copilot';
            } elseif ($targets === ['opencode']) {
                $normalized[] = '--runtime';
                $normalized[] = 'opencode';
            } else {
                $normalized[] = '--runtime';
                $normalized[] = 'both';
            }
            continue;
        }
        if (str_starts_with($arg, '--targets=')) {
            $targetsRaw = substr($arg, 10);
            $targets = array_values(array_filter(array_map('trim', explode(',', $targetsRaw)), static fn(string $v): bool => $v !== ''));
            if ($targets === ['copilot']) {
                $normalized[] = '--runtime=github-copilot';
            } elseif ($targets === ['opencode']) {
                $normalized[] = '--runtime=opencode';
            } else {
                $normalized[] = '--runtime=both';
            }
            continue;
        }
        $normalized[] = $arg;
    }

    if ($forceDryRun && !in_array('--dry-run', $normalized, true)) {
        $normalized[] = '--dry-run';
    }

    $argv = array_merge(['install-ai-kit.php', '--target', $root], $normalized);
    return aiInstallerParseArgs($argv);
}

function aiInstallerTargetsFromRuntime(string $runtime): array
{
    return match ($runtime) {
        'github-copilot' => ['copilot'],
        'opencode' => ['opencode'],
        default => ['copilot', 'opencode'],
    };
}

function aiRunAdapterPlan(string $root, array $args): int
{
    $planConfig = aiInstallerConfigFromAiArgs($root, $args, true);
    $packs = aiInstallerResolveSelectedPacks($planConfig, aiInstallerPackRegistry());
    $actions = aiInstallerBuildPlan($planConfig, aiInstallerPackRegistry(), $packs);

    $creates = [];
    $conflicts = [];
    foreach ($actions as $action) {
        if ($action['action'] === 'CREATE') {
            $creates[] = $action['target'];
        }
        if ($action['action'] === 'SKIP_EXISTING_UNMANAGED') {
            $conflicts[] = $action['target'];
        }
    }

    $data = [
        'mode' => $planConfig['mergeMode'] ?? 'sidecar-only',
        'targets' => aiInstallerTargetsFromRuntime((string) $planConfig['runtime']),
        'profile' => $planConfig['profile'],
        'packs' => $packs,
        'create' => $creates,
        'modify' => [],
        'conflicts' => $conflicts,
        'actions' => $actions,
        'backup_required' => true,
        'atomic_transaction_steps' => ['preflight', 'package-verify', 'backup', 'stage', 'apply', 'validate'],
    ];

    $written = aiCliWriteArtifact($root, 'adapter-plan', 'php tools/ai/ai.php adapter-plan', $data, 'ok', null, 'Run install --dry-run then install --backup-only before apply.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunInstallWorkflow(string $root, array $args): int
{
    $runtimeMode = aiDetectRuntimeMode($args);
    $noInteraction = in_array('--no-interaction', $args, true);
    $isInteractiveEntry = in_array('--wizard', $args, true);
    if ($isInteractiveEntry) {
        return aiRunInstallWizard($root);
    }

    $preflight = aiRunPreflight($root);
    if ($preflight !== 0 && in_array('--apply', $args, true)) {
        $data = ['status' => 'blocked', 'reason' => 'preflight failed', 'next_action' => 'fix preflight and rerun install'];
        $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install', $data, 'blocked', null, 'Preflight must pass before apply.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    $installConfig = aiInstallerConfigFromAiArgs($root, $args);
    $selectedPacks = aiInstallerResolveSelectedPacks($installConfig, aiInstallerPackRegistry());
    if (is_string($installConfig['runAfterInstall'] ?? null) && $installConfig['runAfterInstall'] !== '') {
        $registry = aiInstallerScriptRegistry();
        $scriptId = (string) $installConfig['runAfterInstall'];
        if (!isset($registry[$scriptId])) {
            throw new RuntimeException('unknown post-install script id: ' . $scriptId);
        }
        $requiredPack = (string) ($registry[$scriptId]['pack'] ?? '');
        if ($requiredPack !== '' && !in_array($requiredPack, $selectedPacks, true)) {
            $data = [
                'status' => 'blocked',
                'reason' => 'post-install script requires missing pack: ' . $requiredPack,
                'script_id' => $scriptId,
                'selected_packs' => $selectedPacks,
            ];
            $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install', $data, 'blocked', null, 'Add the required pack with --with or choose a profile that includes it.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }
    if (!empty($installConfig['toolchainCheck']) || !empty($installConfig['toolchainInstallPlan']) || !empty($installConfig['toolchainApply'])) {
        $tcArgs = ['--profile', (string) $installConfig['profile'], '--runtime', (string) $installConfig['runtime'], '--check'];
        if (!empty($installConfig['toolchainInstallPlan'])) {
            $tcArgs[] = '--install-plan';
        }
        if (!empty($installConfig['toolchainApply'])) {
            $tcArgs[] = '--toolchain-apply';
        }
        if (!empty($installConfig['toolchainTools'])) {
            $tcArgs[] = '--with';
            $tcArgs[] = implode(',', (array) $installConfig['toolchainTools']);
        }
        aiRunToolchain($root, $tcArgs);
    }
    $dryRun = (bool) $installConfig['dryRun'] || !in_array('--apply', $args, true);
    $mode = (string) ($installConfig['mergeMode'] ?? 'sidecar-only');
    $reinstall = in_array('--reinstall', $args, true);
    $manifestPath = aiInstallManifestPath($root);
    $hasManifest = is_file($manifestPath);

    if ($hasManifest && !$reinstall && !$dryRun) {
        $data = [
            'status' => 'blocked',
            'reason' => 'manifest already exists; use upgrade or install --reinstall',
            'manifest_path' => '.ai-install-manifest.json',
        ];
        $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install', $data, 'blocked', null, 'Use upgrade for existing installs unless forced reinstall is intended.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    if ($dryRun) {
        $plan = aiInstallerBuildPlan($installConfig, aiInstallerPackRegistry(), aiInstallerResolveSelectedPacks($installConfig, aiInstallerPackRegistry()));
        $creates = count(array_filter($plan, static fn(array $x): bool => ($x['action'] ?? '') === 'CREATE'));
        $skips = count(array_filter($plan, static fn(array $x): bool => ($x['action'] ?? '') === 'SKIP_EXISTING_UNMANAGED'));
        $data = [
            'status' => 'planned',
            'mode' => $mode,
            'runtime_mode' => $runtimeMode,
            'profile' => $installConfig['profile'],
            'packs' => $selectedPacks,
            'apply' => false,
            'summary' => ['create' => $creates, 'skip' => $skips],
            'install_kind' => $hasManifest ? 'reinstall' : 'fresh_install',
            'required_first' => ['preflight', 'package-verify', 'adapter-plan', 'install --backup-only'],
        ];
        $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install --dry-run', $data, 'ok', null, 'Run install --backup-only before install --apply.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 0;
    }

    $backupOnly = in_array('--backup-only', $args, true);
    if ($backupOnly) {
        $planData = aiLoadArtifactData($root, 'adapter-plan.json');
        $creates = $planData['data']['create'] ?? [];
        $modifies = $planData['data']['modify'] ?? [];
        $targets = [];
        foreach ([$creates, $modifies] as $list) {
            if (!is_array($list)) {
                continue;
            }
            foreach ($list as $item) {
                if (!is_string($item) || $item === '') {
                    continue;
                }
                $targets[] = $item;
            }
        }
        $targets = array_values(array_unique($targets));

        $backupRoot = $root . DIRECTORY_SEPARATOR . '.ai-backups';
        if (!is_dir($backupRoot)) {
            mkdir($backupRoot, AI_DIR_MODE, true);
        }
        $backupId = 'install-' . gmdate('Ymd-His');
        $dir = $backupRoot . DIRECTORY_SEPARATOR . $backupId;
        mkdir($dir, AI_DIR_MODE, true);

        $zipPath = $dir . DIRECTORY_SEPARATOR . 'backup.zip';
        $filesDir = $dir . DIRECTORY_SEPARATOR . 'files';
        $zipStatus = 'skipped';
        $dirStatus = 'skipped';
        if (class_exists('ZipArchive')) {
            $zip = new ZipArchive();
            if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) === true) {
                foreach ($targets as $rel) {
                    $abs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, rtrim($rel, '/'));
                    if (is_file($abs)) {
                        $zip->addFile($abs, str_replace('\\', '/', rtrim($rel, '/')));
                    }
                }
                $zip->close();
                $zipStatus = 'created';
            }
        }

        if ($zipStatus !== 'created') {
            if (!is_dir($filesDir)) {
                mkdir($filesDir, AI_DIR_MODE, true);
            }
            foreach ($targets as $rel) {
                $abs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, rtrim($rel, '/'));
                $snapshot = $filesDir . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, rtrim($rel, '/'));
                if (is_file($abs)) {
                    $parent = dirname($snapshot);
                    if (!is_dir($parent)) {
                        mkdir($parent, AI_DIR_MODE, true);
                    }
                    copy($abs, $snapshot);
                }
            }
            $dirStatus = 'created';
        }

        $manifest = [
            'backup_id' => $backupId,
            'created_at_utc' => gmdate('c'),
            'zip_status' => $zipStatus,
            'directory_status' => $dirStatus,
            'targets' => $targets,
        ];
        file_put_contents($dir . DIRECTORY_SEPARATOR . 'manifest.json', json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);

        $data = [
            'status' => 'ok',
            'mode' => $mode,
            'runtime_mode' => $runtimeMode,
            'backup_id' => $backupId,
            'backup_dir' => '.ai-backups/' . $backupId,
            'zip_status' => $zipStatus,
            'directory_status' => $dirStatus,
            'target_count' => count($targets),
        ];
        $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install --backup-only', $data, 'ok', null, 'Backup created; proceed to install --apply once transaction apply is enabled.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 0;
    }

    $backupId = aiParseArg($args, 'backup') ?? '';
    if ($backupId === '' && empty($installConfig['force'])) {
        $data = [
            'status' => 'blocked',
            'mode' => $mode,
            'runtime_mode' => $runtimeMode,
            'reason' => 'apply requires explicit backup id (use --force to skip)',
            'next_action' => 'php tools/ai/ai.php install --backup-only --apply --mode ' . $mode,
        ];
        $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install --apply', $data, 'blocked', null, 'Create backup first, then rerun apply with --backup <backup-id>. Use --force to bypass backup requirement.');
        fwrite(STDERR, "Error: backup is mandatory for install --apply. Create a backup first or use --force to skip." . PHP_EOL);
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }
    if ($backupId !== '') {
        $backupManifestPath = $root . DIRECTORY_SEPARATOR . '.ai-backups' . DIRECTORY_SEPARATOR . $backupId . DIRECTORY_SEPARATOR . 'manifest.json';
        if (!is_file($backupManifestPath)) {
            throw new RuntimeException('backup manifest not found for apply backup id: ' . $backupId);
        }
    }

    $transactionId = 'install-' . gmdate('Ymd-His');
    $stagingDir = '.ai-tmp/' . $transactionId;
    $tx = [
        'transaction_id' => $transactionId,
        'status' => 'prepared',
        'staging_dir' => $stagingDir,
        'mode' => $mode,
        'runtime_mode' => $runtimeMode,
    ];
    aiCliWriteArtifact($root, 'install-transaction', 'php tools/ai/ai.php install --apply', $tx, 'ok', null, 'Transaction prepared; apply command execution follows.');

    $runtime = (string) $installConfig['runtime'];
    $cmd = 'php tools/ai/install-ai-kit.php --target . --runtime ' . escapeshellarg($runtime) . ' --profile ' . escapeshellarg((string) $installConfig['profile']);
    if ($mode === 'sidecar-only') {
        $cmd .= ' --no-base';
    }
    if (!empty($installConfig['force'])) {
        $cmd .= ' --force';
    }
    if (!empty($installConfig['allowCoreOverwrite'])) {
        $cmd .= ' --allow-core-overwrite';
    }
    if (!empty($installConfig['allFeatures'])) {
        $cmd .= ' --all-features';
    }
    if (!empty($installConfig['withPacks'])) {
        $cmd .= ' --with ' . escapeshellarg(implode(',', $installConfig['withPacks']));
    }
    if (!empty($installConfig['withoutPacks'])) {
        $cmd .= ' --without ' . escapeshellarg(implode(',', $installConfig['withoutPacks']));
    }
    if (!empty($installConfig['allowPlaceholders'])) {
        $cmd .= ' --allow-placeholders';
    }

    $run = aiRunCommand($root, $cmd);
    $status = $run['exit'] === 0 ? 'ok' : 'failed';

    $postInstallScript = ['requested' => $installConfig['runAfterInstall'] ?? null, 'executed' => false, 'reason' => null, 'exit' => null];
    if ($status === 'ok') {
        $plan = aiLoadArtifactData($root, 'adapter-plan.json');
        $managed = [];
        if (is_array($plan) && is_array($plan['data']['create'] ?? null)) {
            foreach ($plan['data']['create'] as $item) {
                if (is_string($item) && $item !== '') {
                    $managed[] = $item;
                }
            }
        }
        $manifest = [
            'schema_version' => 1,
            'installer_version' => '0.2.0',
            'installed_at' => gmdate('c'),
            'updated_at' => gmdate('c'),
            'profile' => (string) $installConfig['profile'],
            'mode' => $mode,
            'runtime' => $runtime,
            'package' => [
                'name' => 'ai-universal-rules',
                'distribution' => 'git-tag',
                'source_repository' => 'UtmostCreator/app-configs',
                'source_remote' => 'origin',
                'source_ref' => 'unknown',
                'source_commit' => 'unknown',
                'installed_version' => 'unknown',
            ],
            'managed_paths' => $managed,
            'packs' => $selectedPacks,
            'toolchain' => [
                'checked' => !empty($installConfig['toolchainCheck']),
                'install_plan_printed' => !empty($installConfig['toolchainInstallPlan']),
                'applied' => !empty($installConfig['toolchainApply']),
            ],
            'post_install_script' => $postInstallScript,
            'package_lock_sha256' => is_file(aiPackageLockPath($root)) ? 'sha256:' . hash_file('sha256', aiPackageLockPath($root)) : 'unknown',
        ];
        $manifestJson = json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
        file_put_contents($manifestPath, $manifestJson);
        $derivedDir = dirname(aiInstallDerivedManifestPath($root));
        if (!is_dir($derivedDir)) {
            mkdir($derivedDir, AI_DIR_MODE, true);
        }
        file_put_contents(aiInstallDerivedManifestPath($root), $manifestJson);

        if (!empty($installConfig['verifyAfter'])) {
            $verifyExit = aiRunVerify($root, []);
            if ($verifyExit !== 0) {
                $status = 'failed';
                $postInstallScript['reason'] = 'skipped_verify_failed';
            }
        }

        if ($status === 'ok' && is_string($installConfig['runAfterInstall'] ?? null) && $installConfig['runAfterInstall'] !== '') {
            $runScript = aiRunScriptById($root, (string) $installConfig['runAfterInstall'], ['--apply'], $selectedPacks);
            $postInstallScript['executed'] = $runScript['exit'] === 0;
            $postInstallScript['reason'] = $runScript['exit'] === 0 ? 'executed' : (($runScript['error'] ?? 'failed'));
            $postInstallScript['exit'] = $runScript['exit'];
            if (($runScript['exit'] ?? 1) !== 0) {
                $status = 'failed';
            }
        } elseif ($status === 'ok' && is_string($installConfig['runAfterInstall'] ?? null) && $installConfig['runAfterInstall'] !== '') {
            $postInstallScript['reason'] = 'skipped_install_not_ok';
        }

        $manifest['post_install_script'] = $postInstallScript;
        $manifestJson = json_encode($manifest, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
        file_put_contents($manifestPath, $manifestJson);
        file_put_contents(aiInstallDerivedManifestPath($root), $manifestJson);
    }

    $data = [
        'status' => $status,
        'mode' => $mode,
        'runtime_mode' => $runtimeMode,
        'backup_id' => $backupId,
        'transaction_id' => $transactionId,
        'installer_command' => $cmd,
        'installer_exit' => $run['exit'],
        'installer_stdout_preview' => substr($run['stdout'], 0, 3000),
        'installer_stderr_preview' => substr($run['stderr'], 0, 3000),
        'post_install_script' => $postInstallScript,
    ];
    $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install --apply', $data, $status, null, $status === 'ok' ? 'Install apply completed; run adapter-validate next.' : 'Inspect installer output and rerun install after fixing errors.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $status === 'ok' ? 0 : 1;
}

function aiRunInstallWizard(string $root): int
{
    fwrite(STDOUT, "AI Installer Wizard\n");
    fwrite(STDOUT, "Select runtime target and install profile with optional packs.\n\n");

    $target = strtolower(aiPromptLine('Select targets: [1] both, [2] copilot, [3] opencode (default 1): '));
    $runtime = 'both';
    if ($target === '2' || $target === 'copilot') {
        $runtime = 'github-copilot';
    } elseif ($target === '3' || $target === 'opencode') {
        $runtime = 'opencode';
    }

    $profileMap = ['1' => 'minimal', '2' => 'copilot', '3' => 'opencode', '4' => 'dual', '5' => 'accelerated', '6' => 'full-governance', '7' => 'custom'];
    $profileInput = strtolower(aiPromptLine('Select profile: [1] minimal, [2] copilot, [3] opencode, [4] dual, [5] accelerated, [6] full-governance, [7] custom (default 4): '));
    $profile = $profileMap[$profileInput] ?? 'dual';

    $allFeatures = aiPromptYesNo('Install all available AI feature packs?', true);
    $with = [];
    if (!$allFeatures) {
        $customize = aiPromptYesNo('Customize optional packs?', true);
        if ($customize || $profile === 'custom') {
            foreach (['scripts-pack', 'policy-pack', 'hooks-pack', 'ci-pack', 'evidence-pack', 'docs-reference-pack', 'capabilities-extended-full', 'delivery-pack', 'optional-agents-pack', 'optional-prompts-pack'] as $pack) {
                if (aiPromptYesNo('Install ' . $pack . '?', true)) {
                    $with[] = $pack;
                }
            }
        }
    }

    $hookDriver = 'none';
    if (in_array('hooks-pack', $with, true) || $allFeatures || in_array($profile, ['full-governance'], true)) {
        $wire = strtolower(aiPromptLine('Wire hooks now? [1] no, [2] husky, [3] lefthook, [4] native git hooks (default 1): '));
        $hookDriver = match ($wire) {
            '2', 'husky' => 'husky',
            '3', 'lefthook' => 'lefthook',
            '4', 'native' => 'native',
            default => 'none',
        };
    }

    $modeInput = strtolower(aiPromptLine('Select mode: [1] sidecar-only, [2] safe-merge (default 1): '));
    $mode = ($modeInput === '2' || $modeInput === 'safe-merge') ? 'safe-merge' : 'sidecar-only';

    $planArgs = ['--runtime', $runtime, '--profile', $profile, '--mode', $mode, '--no-interaction'];
    if ($allFeatures) {
        $planArgs[] = '--all-features';
    }
    if ($with !== []) {
        $planArgs[] = '--with';
        $planArgs[] = implode(',', $with);
    }
    if ($hookDriver !== 'none') {
        $planArgs[] = '--hook-driver';
        $planArgs[] = $hookDriver;
    }

    $cfg = aiInstallerConfigFromAiArgs($root, $planArgs, true);
    $registry = aiInstallerPackRegistry();
    $packs = aiInstallerResolveSelectedPacks($cfg, $registry);
    $toolchainCheck = false;
    $toolchainPlan = false;
    $toolchainApply = false;
    if (in_array('scripts-pack', $packs, true)) {
        $toolchainCheck = aiPromptYesNo('Run toolchain check for scripts-pack?', false);
        if ($toolchainCheck) {
            $toolchainPlan = aiPromptYesNo('Print tool install plan?', true);
            $toolchainApply = aiPromptYesNo('Apply safe tool installs (repomix only)?', true);
            if ($toolchainCheck) {
                $planArgs[] = '--toolchain-check';
            }
            if ($toolchainPlan) {
                $planArgs[] = '--toolchain-install-plan';
            }
            if ($toolchainApply) {
                $planArgs[] = '--toolchain-apply';
            }
        }
    }
    $actions = aiInstallerBuildPlan($cfg, $registry, $packs);
    $dep = aiInstallerPackToolRequirements($packs);

    $missingRequired = [];
    $missingOptional = [];
    foreach ($dep['required'] as $tool) {
        if (!aiCliCommandExists((string) $tool)) {
            $missingRequired[] = $tool;
        }
    }
    foreach ($dep['optional'] as $tool) {
        if (!aiCliCommandExists((string) $tool)) {
            $missingOptional[] = $tool;
        }
    }

    $createCount = count(array_filter($actions, static fn(array $a): bool => ($a['action'] ?? '') === 'CREATE'));
    $updateCount = count(array_filter($actions, static fn(array $a): bool => ($a['action'] ?? '') === 'OVERWRITE_MANAGED'));
    $skipCount = count(array_filter($actions, static fn(array $a): bool => str_starts_with((string) ($a['action'] ?? ''), 'SKIP')));
    $conflictCount = count(array_filter($actions, static fn(array $a): bool => ($a['action'] ?? '') === 'SKIP_EXISTING_UNMANAGED'));

    fwrite(STDOUT, "\nInstall summary\n\n");
    fwrite(STDOUT, "Runtime: {$runtime}\n");
    fwrite(STDOUT, "Profile: {$profile}\n");
    fwrite(STDOUT, "Selected packs:\n- " . implode("\n- ", $packs) . "\n");
    fwrite(STDOUT, "Files to create: {$createCount}\n");
    fwrite(STDOUT, "Files to update: {$updateCount}\n");
    fwrite(STDOUT, "Files skipped: {$skipCount}\n");
    fwrite(STDOUT, "Manual conflicts: {$conflictCount}\n");
    fwrite(STDOUT, "Required tools missing: " . count($missingRequired) . "\n");
    fwrite(STDOUT, "Optional tools missing: " . count($missingOptional) . "\n");

    $runAfterInstall = 'none';
    if (in_array('scripts-pack', $packs, true)) {
        fwrite(STDOUT, "Run a script after install? [0] none, [1] repomix-context, [2] repomix-tree, [3] repomix-scc-router, [4] pack-context\n");
        $sel = strtolower(aiPromptLine('Selection (default 0): '));
        $runAfterInstall = match ($sel) {
            '1', 'repomix-context' => 'repomix-context',
            '2', 'repomix-tree' => 'repomix-tree',
            '3', 'repomix-scc-router' => 'repomix-scc-router',
            '4', 'pack-context' => 'pack-context',
            default => 'none',
        };
        if ($runAfterInstall !== 'none') {
            $planArgs[] = '--run-after-install';
            $planArgs[] = $runAfterInstall;
        }
    }

    fwrite(STDOUT, "\nFinal action\n[1] Dry-run\n[2] Backup only\n[3] Apply with backup\n[4] Cancel\n");
    $final = strtolower(aiPromptLine('Selection (default 1): '));
    if ($final === '' || $final === '1' || $final === 'dry-run') {
        aiRunInstallWorkflow($root, array_merge($planArgs, ['--dry-run']));
        if ($toolchainCheck) {
            $tcArgs = ['--profile', $profile, '--runtime', $runtime, '--check'];
            if ($toolchainPlan) {
                $tcArgs[] = '--install-plan';
            }
            if ($toolchainApply) {
                $tcArgs[] = '--toolchain-apply';
            }
            aiRunToolchain($root, $tcArgs);
        }
        return 0;
    }

    if ($final === '2' || $final === 'backup') {
        aiRunInstallWorkflow($root, array_merge($planArgs, ['--backup-only', '--apply']));
        $backupId = aiLatestBackupId($root);
        if ($backupId !== null) {
            fwrite(STDOUT, "OK: created backup .ai-backups/{$backupId}/\n");
        }
        return 0;
    }

    if ($final === '3' || $final === 'apply') {
        aiRunInstallWorkflow($root, array_merge($planArgs, ['--backup-only', '--apply']));
        $backupId = aiLatestBackupId($root);
        if ($backupId === null) {
            fwrite(STDERR, "Error: no backup found. Create backup first with install --backup-only.\n");
            return 1;
        }
        $exit = aiRunInstallWorkflow($root, array_merge($planArgs, ['--apply', '--backup', $backupId]));
        aiRunAdapterValidate($root);
        if (aiPromptYesNo('Run verify now?', false)) {
            aiRunVerify($root, []);
        }
        return $exit;
    }

    $data = [
        'status' => 'planned',
        'interactive' => true,
        'runtime' => $runtime,
        'profile' => $profile,
        'packs' => $packs,
        'mode' => $mode,
        'next_action' => 'Run install --apply with backup after reviewing dry-run.',
    ];
    $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install --interactive', $data, 'ok', null, 'Wizard exited before apply; no installation changes made.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunUpgradeWorkflow(string $root, array $args): int
{
    $manifestPath = aiInstallManifestPath($root);
    if (!is_file($manifestPath)) {
        $data = [
            'status' => 'blocked',
            'reason' => 'no install manifest found; run install first',
            'manifest_path' => '.ai-install-manifest.json',
        ];
        $written = aiCliWriteArtifact($root, 'upgrade', 'php tools/ai/ai.php upgrade', $data, 'blocked', null, 'Install workflow must create manifest before upgrade.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    $manifest = json_decode((string) file_get_contents($manifestPath), true);
    if (!is_array($manifest)) {
        throw new RuntimeException('Invalid install manifest JSON at .ai-install-manifest.json');
    }

    $dryRun = in_array('--dry-run', $args, true) || !in_array('--apply', $args, true);
    $targetRef = aiParseArg($args, 'to') ?? '';
    $verifyExit = aiRunPackageVerify($root);
    $verify = aiLoadArtifactData($root, 'package-verify.json');

    $changes = [];
    if ($verifyExit !== 0) {
        $changes[] = [
            'type' => 'source_checksum_drift',
            'action' => 'review package-lock and template changes',
        ];
    }

    $sourceRef = (string) (($manifest['package']['source_ref'] ?? 'unknown'));
    $tags = [];
    $tagExit = 0;
    exec('git -C ' . escapeshellarg($root) . ' tag --sort=-v:refname', $tags, $tagExit);
    $latestTag = $tagExit === 0 && $tags !== [] ? (string) $tags[0] : 'unknown';
    if ($latestTag !== 'unknown' && $sourceRef !== 'unknown' && $latestTag !== $sourceRef) {
        $changes[] = [
            'type' => 'newer_package_available',
            'current_ref' => $sourceRef,
            'latest_ref' => $latestTag,
            'action' => 'review upgrade plan and apply with backup',
        ];
    }

    $files = is_array($manifest['files'] ?? null) ? $manifest['files'] : [];
    $fileActions = [];
    foreach ($files as $target => $meta) {
        if (!is_array($meta)) {
            continue;
        }
        $sourceRel = (string) ($meta['source'] ?? '');
        $sourceAbs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $sourceRel);
        $targetAbs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, (string) $target);
        $sourceCurrentHash = aiHashPath($sourceAbs);
        $installedAtInstall = (string) ($meta['installed_hash'] ?? 'unknown');
        $sourceAtInstall = (string) ($meta['source_hash'] ?? 'unknown');
        $targetCurrentHash = aiHashPath($targetAbs);

        $status = 'unchanged';
        $action = 'skip';
        if ($targetCurrentHash === 'missing') {
            $status = 'missing';
            $action = 'restore or remove from manifest';
        } elseif ($sourceCurrentHash !== $sourceAtInstall && $targetCurrentHash === $installedAtInstall) {
            $status = 'source-updated';
            $action = 'auto-update';
        } elseif ($sourceCurrentHash === $sourceAtInstall && $targetCurrentHash !== $installedAtInstall) {
            $status = 'local-customised';
            $action = 'preserve and review';
        } elseif ($sourceCurrentHash !== $sourceAtInstall && $targetCurrentHash !== $installedAtInstall) {
            $status = 'both-changed';
            $action = 'merge-required';
        }

        $fileActions[] = [
            'file' => (string) $target,
            'status' => $status,
            'action' => $action,
            'source' => $sourceRel,
        ];
    }

    if ($dryRun) {
        $data = [
            'status' => $changes === [] ? 'ok' : 'warning',
            'mode' => 'dry-run',
            'manifest_runtime' => $manifest['runtime'] ?? 'unknown',
            'manifest_mode' => $manifest['mode'] ?? 'unknown',
            'package_source_ref' => $sourceRef,
            'latest_available_tag' => $latestTag,
            'target_ref' => $targetRef !== '' ? $targetRef : null,
            'detected_changes' => $changes,
            'file_actions' => $fileActions,
            'package_verify_status' => $verify['status'] ?? 'unknown',
        ];
        $written = aiCliWriteArtifact($root, 'upgrade', 'php tools/ai/ai.php upgrade --dry-run', $data, $changes === [] ? 'ok' : 'warning', null, 'If changes look safe, run upgrade --apply.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 0;
    }

    $mode = (string) ($manifest['mode'] ?? 'sidecar-only');
    $backupId = aiParseArg($args, 'backup') ?? '';
    if ($backupId === '') {
        $data = [
            'status' => 'blocked',
            'reason' => 'upgrade apply requires explicit backup id',
            'next_action' => 'php tools/ai/ai.php install --backup-only --apply --mode ' . $mode,
        ];
        $written = aiCliWriteArtifact($root, 'upgrade', 'php tools/ai/ai.php upgrade --apply', $data, 'blocked', null, 'Create backup first, then rerun upgrade --apply --backup <id>.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    $installArgs = ['--apply', '--reinstall', '--mode', $mode, '--backup', $backupId, '--no-interaction'];
    if (in_array('--agent', $args, true)) {
        $installArgs[] = '--agent';
    }
    if (in_array('--ci', $args, true)) {
        $installArgs[] = '--ci';
    }
    $exit = aiRunInstallWorkflow($root, $installArgs);
    $install = aiLoadArtifactData($root, 'install.json');
    $status = $exit === 0 ? 'ok' : 'failed';
    $data = [
        'status' => $status,
        'mode' => 'apply',
        'backup_id' => $backupId,
        'target_ref' => $targetRef !== '' ? $targetRef : null,
        'file_actions_preview' => $fileActions,
        'install_status' => $install['status'] ?? 'unknown',
    ];
    $written = aiCliWriteArtifact($root, 'upgrade', 'php tools/ai/ai.php upgrade --apply', $data, $status, null, $status === 'ok' ? 'Upgrade apply completed; run adapter-validate.' : 'Upgrade apply failed; inspect install artifact.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $exit;
}

function aiRunAdapterValidate(string $root): int
{
    $lock = aiLoadArtifactData($root, 'package-verify.json');
    $manifestPath = aiInstallManifestPath($root);
    $derivedManifestPath = aiInstallDerivedManifestPath($root);
    $manifestExists = is_file($manifestPath);
    $derivedExists = is_file($derivedManifestPath);
    $derivedMatches = false;
    if ($manifestExists && $derivedExists) {
        $derivedMatches = hash_file('sha256', $manifestPath) === hash_file('sha256', $derivedManifestPath);
    }
    $status = ($lock['status'] ?? 'unknown') === 'ok' && $manifestExists ? 'ok' : 'warning';
    if ($manifestExists && $derivedExists && !$derivedMatches) {
        $status = 'warning';
    }
    $data = [
        'status' => $status,
        'package_verify_status' => $lock['status'] ?? 'unknown',
        'install_manifest_present' => $manifestExists,
        'derived_install_manifest_present' => $derivedExists,
        'manifest_drift_detected' => $manifestExists && $derivedExists ? !$derivedMatches : null,
        'checks' => ['package-verify artifact', 'instruction-audit artifact', 'install manifest present', 'derived manifest drift'],
    ];
    $written = aiCliWriteArtifact($root, 'adapter-validate', 'php tools/ai/ai.php adapter-validate', $data, $status, null, 'Run package-verify and audit-instructions first if missing.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunRollbackWorkflow(string $root, array $args): int
{
    $backupId = aiParseArg($args, 'backup') ?? '';
    if ($backupId === '') {
        throw new RuntimeException('rollback requires --backup <backup-id>');
    }

    $dryRun = in_array('--dry-run', $args, true) || !in_array('--apply', $args, true);
    $base = $root . DIRECTORY_SEPARATOR . '.ai-backups' . DIRECTORY_SEPARATOR . $backupId;
    $manifestPath = $base . DIRECTORY_SEPARATOR . 'manifest.json';
    if (!is_file($manifestPath)) {
        throw new RuntimeException('backup manifest not found for backup id: ' . $backupId);
    }
    $manifest = json_decode((string) file_get_contents($manifestPath), true);
    if (!is_array($manifest)) {
        throw new RuntimeException('invalid backup manifest JSON for backup id: ' . $backupId);
    }

    $targets = $manifest['targets'] ?? [];
    $zipPath = $base . DIRECTORY_SEPARATOR . 'backup.zip';
    $filesDir = $base . DIRECTORY_SEPARATOR . 'files';
    $restored = [];
    if (!$dryRun && is_file($zipPath) && class_exists('ZipArchive')) {
        $zip = new ZipArchive();
        if ($zip->open($zipPath) === true) {
            $zip->extractTo($root);
            $zip->close();
            $restored = is_array($targets) ? $targets : [];
        }
    }
    if (!$dryRun && $restored === [] && is_dir($filesDir)) {
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($filesDir, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::SELF_FIRST);
        foreach ($it as $item) {
            $rel = str_replace('\\', '/', substr($item->getPathname(), strlen($filesDir) + 1));
            $dest = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $rel);
            if ($item->isDir()) {
                if (!is_dir($dest)) {
                    mkdir($dest, AI_DIR_MODE, true);
                }
                continue;
            }
            $parent = dirname($dest);
            if (!is_dir($parent)) {
                mkdir($parent, AI_DIR_MODE, true);
            }
            copy($item->getPathname(), $dest);
            $restored[] = $rel;
        }
    }

    $data = [
        'status' => 'ok',
        'backup' => $backupId,
        'dry_run' => $dryRun,
        'target_count' => is_array($targets) ? count($targets) : 0,
        'restored_targets' => $restored,
    ];
    $written = aiCliWriteArtifact($root, 'rollback', 'php tools/ai/ai.php rollback --backup ' . $backupId, $data, 'ok', null, $dryRun ? 'Dry-run complete; use --apply to restore from backup.' : 'Rollback applied from backup snapshot.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunPacks(string $root, array $args): int
{
    $registry = aiInstallerPackRegistry();
    $errors = aiInstallerValidatePackRegistry($registry);
    $profiles = aiInstallerProfileDefinitions();
    $data = [
        'profiles' => $profiles,
        'all_features' => aiInstallerAllFeaturePacks(),
        'available_packs' => array_keys($registry),
        'registry_errors' => $errors,
        'validation_requested' => in_array('--validate', $args, true),
        'notes' => ['docs-reference is optional add-on only'],
    ];
    $status = $errors === [] ? 'ok' : 'failed';
    $written = aiCliWriteArtifact($root, 'packs', 'php tools/ai/ai.php packs', $data, $status, null, $errors === [] ? 'Pack contracts validated.' : 'Fix pack registry contract errors.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $errors === [] ? 0 : 1;
}

function aiRunVersion(string $root): int
{
    $manifestPath = aiInstallManifestPath($root);
    $data = ['manifest_path' => '.ai-install-manifest.json', 'present' => is_file($manifestPath)];
    if (is_file($manifestPath)) {
        $manifest = json_decode((string) file_get_contents($manifestPath), true);
        if (is_array($manifest)) {
            $data['package'] = $manifest['package'] ?? [];
            $data['installer_version'] = $manifest['installer_version'] ?? 'unknown';
            $data['schema_version'] = $manifest['schema_version'] ?? 'unknown';
        }
    }
    $status = ($data['present'] ?? false) ? 'ok' : 'warning';
    $written = aiCliWriteArtifact($root, 'version', 'php tools/ai/ai.php version', $data, $status, null, is_file($manifestPath) ? 'Canonical install manifest loaded.' : 'Install manifest missing; run install first.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return is_file($manifestPath) ? 0 : 1;
}

function aiRunPlaceholders(string $root, array $args): int
{
    $fail = in_array('--fail', $args, true);
    $interactive = in_array('--interactive', $args, true);
    $setValues = [];
    foreach ($args as $arg) {
        if (str_starts_with($arg, '--set')) {
            $value = '';
            if ($arg === '--set') {
                continue;
            }
            if (str_starts_with($arg, '--set=')) {
                $value = substr($arg, 6);
            }
            if ($value !== '' && str_contains($value, '=')) {
                [$k, $v] = explode('=', $value, 2);
                $setValues['<' . strtoupper(trim($k)) . '>'] = $v;
            }
        }
    }

    $paths = ['AGENTS.md', 'docs/ai', '.github', '.opencode'];
    $hits = [];
    foreach ($paths as $path) {
        $abs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $path);
        if (is_file($abs)) {
            aiApplyPlaceholderSetsToFile($abs, $setValues);
            $content = (string) file_get_contents($abs);
            if (preg_match_all('/<[A-Z0-9_]+>/', $content, $m) === 1 || (isset($m[0]) && $m[0] !== [])) {
                $hits[] = ['path' => $path, 'placeholders' => array_values(array_unique($m[0]))];
            }
            continue;
        }
        if (!is_dir($abs)) {
            continue;
        }
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($abs, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $file) {
            if (!$file->isFile() || strtolower($file->getExtension()) !== 'md') {
                continue;
            }
            aiApplyPlaceholderSetsToFile($file->getPathname(), $setValues);
            $content = (string) file_get_contents($file->getPathname());
            if (preg_match_all('/<[A-Z0-9_]+>/', $content, $m) === 1 || (isset($m[0]) && $m[0] !== [])) {
                $rel = str_replace('\\', '/', substr($file->getPathname(), strlen($root) + 1));
                $hits[] = ['path' => $rel, 'placeholders' => array_values(array_unique($m[0]))];
            }
        }
    }

    if ($interactive && $hits !== []) {
        $all = [];
        foreach ($hits as $hit) {
            foreach ($hit['placeholders'] as $ph) {
                $all[$ph] = true;
            }
        }
        foreach (array_keys($all) as $token) {
            $input = aiPromptLine("Set {$token} (leave blank to skip): ");
            if ($input === '') {
                continue;
            }
            aiReplaceTokenAcrossPaths($root, $paths, $token, $input);
        }
    }

    $data = ['count' => count($hits), 'items' => $hits, 'mode' => $fail ? 'fail' : 'scan'];
    $status = $hits === [] ? 'ok' : ($fail ? 'failed' : 'warning');
    $written = aiCliWriteArtifact($root, 'placeholders', 'php tools/ai/ai.php placeholders', $data, $status, null, $hits === [] ? 'No unresolved placeholders found.' : 'Resolve placeholders before strict verification.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $status === 'failed' ? 1 : 0;
}

function aiApplyPlaceholderSetsToFile(string $filePath, array $setValues): void
{
    if ($setValues === []) {
        return;
    }
    $content = (string) file_get_contents($filePath);
    $updated = str_replace(array_keys($setValues), array_values($setValues), $content);
    if ($updated !== $content) {
        file_put_contents($filePath, $updated);
    }
}

function aiReplaceTokenAcrossPaths(string $root, array $paths, string $token, string $value): void
{
    foreach ($paths as $path) {
        $abs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $path);
        if (is_file($abs)) {
            aiApplyPlaceholderSetsToFile($abs, [$token => $value]);
            continue;
        }
        if (!is_dir($abs)) {
            continue;
        }
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($abs, FilesystemIterator::SKIP_DOTS));
        foreach ($it as $file) {
            if (!$file->isFile() || strtolower($file->getExtension()) !== 'md') {
                continue;
            }
            aiApplyPlaceholderSetsToFile($file->getPathname(), [$token => $value]);
        }
    }
}

function aiRunHooks(string $root, array $args): int
{
    $driver = aiParseArg($args, 'driver') ?? 'none';
    $install = in_array('install', $args, true);
    $commands = [];
    if ($install) {
        if ($driver === 'husky') {
            $commands[] = 'npx husky add .husky/pre-commit "bash scripts/hooks/pre-commit.sh"';
            $commands[] = 'npx husky add .husky/commit-msg "bash scripts/hooks/commit-msg.sh"';
        } elseif ($driver === 'lefthook') {
            $commands[] = 'Map scripts/hooks/pre-commit.sh and commit-msg.sh in .lefthook.yml';
        } elseif ($driver === 'native') {
            $commands[] = 'cp scripts/hooks/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit';
            $commands[] = 'cp scripts/hooks/commit-msg.sh .git/hooks/commit-msg && chmod +x .git/hooks/commit-msg';
        }
    }
    $data = [
        'status' => $install ? 'manual-required' : 'planned',
        'install_requested' => $install,
        'driver' => $driver,
        'supported_drivers' => ['husky', 'lefthook', 'native'],
        'wiring_commands' => $commands,
        'note' => 'Hook wiring remains explicit and opt-in.',
    ];
    $written = aiCliWriteArtifact($root, 'hooks', 'php tools/ai/ai.php hooks', $data, 'ok', null, 'Install hooks explicitly per selected driver.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunToolchain(string $root, array $args): int
{
    $withRaw = aiParseArg($args, 'with') ?? aiParseArg($args, 'toolchain-tools') ?? '';
    $with = $withRaw === '' ? [] : array_values(array_filter(array_map('trim', explode(',', $withRaw)), static fn(string $v): bool => $v !== ''));
    $profile = aiParseArg($args, 'profile') ?? 'dual';
    $runtime = aiParseArg($args, 'runtime') ?? 'both';
    $check = in_array('--check', $args, true) || in_array('--toolchain-check', $args, true) || !in_array('--install-plan', $args, true);
    $installPlan = in_array('--install-plan', $args, true) || in_array('--toolchain-install-plan', $args, true);
    $apply = in_array('--toolchain-apply', $args, true);
    $assumeYes = in_array('--yes', $args, true);

    $cfg = aiInstallerConfigFromAiArgs($root, ['--profile', $profile, '--runtime', $runtime, '--dry-run']);
    $packs = aiInstallerResolveSelectedPacks($cfg, aiInstallerPackRegistry());
    $tools = aiInstallerSelectedToolList($packs, $with);
    $report = aiInstallerToolchainReport($tools);

    $platform = aiInstallerPlatformKey();
    $installActions = [];
    foreach ($report as $row) {
        if (($row['present'] ?? false) === true) {
            continue;
        }
        $hints = $row['install_hints'] ?? [];
        $hint = (string) ($hints[$platform] ?? ($hints['npm'] ?? 'manual install required'));
        $installActions[] = ['tool' => $row['tool'], 'hint' => $hint, 'safe_auto_install' => (bool) ($row['safe_auto_install'] ?? false)];
    }

    $applied = [];
    if ($apply) {
        if (!$assumeYes) {
            fwrite(STDOUT, "Toolchain apply is about to run safe auto-install commands (if any).\n");
            if (!aiPromptYesNo('Continue with toolchain apply?', true)) {
                $data = [
                    'status' => 'blocked',
                    'reason' => 'toolchain apply cancelled by user',
                    'profile' => $profile,
                    'runtime' => $runtime,
                    'packs' => $packs,
                    'apply_requested' => true,
                ];
                $written = aiCliWriteArtifact($root, 'toolchain', 'php tools/ai/ai.php toolchain', $data, 'blocked', null, 'Re-run with --yes to apply non-interactively.');
                fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
                return 1;
            }
        }

        foreach ($report as $row) {
            if (($row['present'] ?? false)) {
                continue;
            }
            if (!($row['safe_auto_install'] ?? false)) {
                $hints = $row['install_hints'] ?? [];
                $hint = (string) ($hints[$platform] ?? ($hints['npm'] ?? 'manual install required'));
                $applied[] = ['tool' => $row['tool'], 'status' => 'blocked', 'reason' => 'auto-install not approved', 'hint' => $hint];
                continue;
            }
            $requires = is_array($row['requires_before_install'] ?? null) ? $row['requires_before_install'] : [];
            $missingReq = aiInstallerMissingTools($requires);
            if ($missingReq !== []) {
                $applied[] = ['tool' => $row['tool'], 'status' => 'blocked', 'reason' => 'missing prerequisite tools: ' . implode(', ', $missingReq)];
                continue;
            }
            $commands = $row['install_commands'] ?? [];
            $cmd = is_array($commands['npm'] ?? null) ? $commands['npm'] : [];
            if ($cmd === []) {
                $applied[] = ['tool' => $row['tool'], 'status' => 'blocked', 'reason' => 'no safe install command'];
                continue;
            }
            $result = aiInstallerRunArgv($cmd, $root);
            $applied[] = ['tool' => $row['tool'], 'status' => $result['exit'] === 0 ? 'installed' : 'failed', 'exit' => $result['exit']];
        }
    }

    $data = [
        'status' => 'ok',
        'profile' => $profile,
        'runtime' => $runtime,
        'packs' => $packs,
        'check_requested' => $check,
        'install_plan_requested' => $installPlan,
        'apply_requested' => $apply,
        'tools' => $report,
        'install_actions' => $installActions,
        'apply_results' => $applied,
    ];
    $written = aiCliWriteArtifact($root, 'toolchain', 'php tools/ai/ai.php toolchain', $data, 'ok', null, 'Review missing tools and rerun with --toolchain-apply only when needed.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunScriptById(string $root, string $scriptId, array $args, ?array $selectedPacks = null): array
{
    $registry = aiInstallerScriptRegistry();
    if (!isset($registry[$scriptId])) {
        return ['exit' => 1, 'error' => 'unknown script id: ' . $scriptId];
    }
    $entry = $registry[$scriptId];
    $requiredPack = (string) ($entry['pack'] ?? '');
    if (is_array($selectedPacks) && $requiredPack !== '' && !in_array($requiredPack, $selectedPacks, true)) {
        return ['exit' => 1, 'error' => 'script requires missing pack: ' . $requiredPack, 'required_pack' => $requiredPack];
    }
    $scriptPath = aiInstallerResolveScriptPath($root, $entry);
    if ($scriptPath === null) {
        return ['exit' => 1, 'error' => 'script file not found for id: ' . $scriptId];
    }

    $requiredTools = is_array($entry['required_tools'] ?? null) ? $entry['required_tools'] : [];
    $missing = aiInstallerMissingTools($requiredTools);
    if ($missing !== []) {
        return ['exit' => 1, 'error' => 'missing required tools: ' . implode(', ', $missing), 'missing_tools' => $missing];
    }

    $dryRun = in_array('--dry-run', $args, true) || !in_array('--apply', $args, true);
    $scriptArgs = aiArgsAfterDoubleDash($args);
    $argv = array_merge(['bash', $scriptPath], $scriptArgs);
    if ($dryRun) {
        return ['exit' => 0, 'dry_run' => true, 'argv' => $argv, 'script_id' => $scriptId, 'script_path' => str_replace('\\', '/', substr($scriptPath, strlen($root) + 1))];
    }

    $run = aiInstallerRunArgv($argv, $root);
    return [
        'exit' => $run['exit'],
        'dry_run' => false,
        'argv' => $argv,
        'script_id' => $scriptId,
        'script_path' => str_replace('\\', '/', substr($scriptPath, strlen($root) + 1)),
        'stdout_preview' => substr((string) ($run['stdout'] ?? ''), 0, 3000),
        'stderr_preview' => substr((string) ($run['stderr'] ?? ''), 0, 3000),
    ];
}

function aiRunScriptCommand(string $root, array $args): int
{
    if (in_array('--list', $args, true)) {
        $registry = aiInstallerScriptRegistry();
        $items = [];
        foreach ($registry as $id => $entry) {
            $items[] = ['id' => $id, 'label' => $entry['label'] ?? $id, 'pack' => $entry['pack'] ?? 'unknown'];
        }
        $written = aiCliWriteArtifact($root, 'scripts', 'php tools/ai/ai.php run-script --list', ['scripts' => $items], 'ok', null, 'Run one with: php tools/ai/ai.php run-script <id> --dry-run');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 0;
    }

    $scriptId = '';
    foreach ($args as $arg) {
        if ($arg !== '' && $arg[0] !== '-') {
            $scriptId = $arg;
            break;
        }
    }
    if ($scriptId === '') {
        throw new RuntimeException('run-script requires script id or --list');
    }

    $run = aiRunScriptById($root, $scriptId, $args, null);
    $status = ($run['exit'] ?? 1) === 0 ? 'ok' : 'failed';
    $written = aiCliWriteArtifact($root, 'scripts', 'php tools/ai/ai.php run-script ' . $scriptId, $run, $status, null, $status === 'ok' ? 'Script run completed.' : 'Fix script/tool errors and retry.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $status === 'ok' ? 0 : 1;
}

function aiRunInstallDocs(string $root, array $args): int
{
    $check = in_array('--check', $args, true);
    $write = in_array('--write', $args, true) || !$check;
    $target = aiParseArg($args, 'target') ?? $root;
    $targetRoot = realpath($target);
    if ($targetRoot === false || !is_dir($targetRoot)) {
        throw new RuntimeException('target directory not found: ' . $target);
    }

    $manifestPath = aiInstallerCanonicalManifestPath($targetRoot);
    $installDocDrift = [];

    if ($check) {
        if (is_file($manifestPath)) {
            $manifest = json_decode((string) file_get_contents($manifestPath), true);
            if (is_array($manifest)) {
                $generated = $targetRoot . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'generated';
                $jsonPath = $generated . DIRECTORY_SEPARATOR . 'install-instructions.json';
                $mdPath = $generated . DIRECTORY_SEPARATOR . 'install-instructions.md';
                $data = aiInstallerBuildInstalledInstructionsData($targetRoot, $manifest);
                $expectedJson = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL;
                $expectedMd = aiInstallerRenderInstalledInstructionsMarkdown($data);
                if (!is_file($jsonPath) || (string) file_get_contents($jsonPath) !== $expectedJson) {
                    $installDocDrift[] = 'docs/ai/generated/install-instructions.json';
                }
                if (!is_file($mdPath) || (string) file_get_contents($mdPath) !== $expectedMd) {
                    $installDocDrift[] = 'docs/ai/generated/install-instructions.md';
                }
            }
        }

        $catalogCheck = aiInstallerCheckCatalogDocs($root);
        $drift = array_values(array_unique(array_merge($installDocDrift, $catalogCheck['drift'] ?? [])));
        $status = $drift === [] ? 'ok' : 'failed';
        $data = [
            'status' => $status,
            'mode' => 'check',
            'target' => $targetRoot,
            'drift' => $drift,
        ];
        $written = aiCliWriteArtifact($root, 'install-docs', 'php tools/ai/ai.php install-docs --check', $data, $status, null, $status === 'ok' ? 'Install docs are up to date.' : 'Run install-docs --write to regenerate install docs.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return $status === 'ok' ? 0 : 1;
    }

    $writtenPaths = [];
    if (is_file($manifestPath)) {
        $manifest = json_decode((string) file_get_contents($manifestPath), true);
        if (is_array($manifest)) {
            $out = aiInstallerWriteInstallDocs($targetRoot, $manifest);
            $writtenPaths[] = aiCliToRelative($root, $out['json']);
            $writtenPaths[] = aiCliToRelative($root, $out['md']);
        }
    }
    $catalog = aiInstallerWriteCatalogDocs($root);
    $writtenPaths[] = aiCliToRelative($root, $catalog['json']);
    $writtenPaths[] = aiCliToRelative($root, $catalog['md']);
    $writtenPaths[] = aiCliToRelative($root, $catalog['package_md']);

    $data = [
        'status' => 'ok',
        'mode' => 'write',
        'target' => $targetRoot,
        'written' => array_values(array_unique($writtenPaths)),
        'manifest_found' => is_file($manifestPath),
    ];
    $written = aiCliWriteArtifact($root, 'install-docs', 'php tools/ai/ai.php install-docs --write', $data, 'ok', null, 'Run install-docs --check in CI to prevent drift.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}
