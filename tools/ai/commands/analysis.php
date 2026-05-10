<?php

declare(strict_types=1);

function aiRunVerify(string $root, array $args): int
{
    $strict = in_array('--strict', $args, true);
    $jsonMode = in_array('--json', $args, true);
    $generatedDir = aiCliGeneratedDir($root);
    $logDirName = 'verify-' . date('Ymd-His');
    $logBaseDir = $generatedDir . DIRECTORY_SEPARATOR . 'logs';
    $logDir = $logBaseDir . DIRECTORY_SEPARATOR . $logDirName;
    $logDirLabel = 'docs/ai/generated/logs/' . $logDirName;
    $logFilePrefix = '';
    if (!is_dir($logDir) && !mkdir($logDir, AI_DIR_MODE, true) && !is_dir($logDir)) {
        if (is_dir($logBaseDir)) {
            $logDir = $logBaseDir;
            $logDirLabel = 'docs/ai/generated/logs';
            $logFilePrefix = $logDirName . '-';
        } else {
            $fallbackBase = rtrim(sys_get_temp_dir(), DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . 'app-configs-ai-logs';
            $fallbackDir = $fallbackBase . DIRECTORY_SEPARATOR . $logDirName;
            if (!is_dir($fallbackDir) && !mkdir($fallbackDir, AI_DIR_MODE, true) && !is_dir($fallbackDir)) {
                throw new RuntimeException('Could not create verify log dir');
            }
            $logDir = $fallbackDir;
            $logDirLabel = str_replace('\\', '/', $fallbackDir);
        }
    }

    $checks = [
        'validate-ai-config' => 'php tools/ai/validate-ai-config.php',
        'validate-ai-catalog' => 'php tools/ai/validate-ai-catalog.php',
        'generate-ai-catalog-check' => 'php tools/ai/generate-ai-catalog.php --check',
        'generate-repo-structure-check' => 'php tools/ai/generate-repo-structure.php --check --with-scc',
        'install-docs-check' => 'php tools/ai/ai.php install-docs --check',
        'advisor-check' => 'php tools/ai/ai.php advisor --check',
    ];

    $results = [];
    $failed = [];
    foreach ($checks as $name => $command) {
        $run = aiRunCommand($root, $command);
        $autoFixApplied = false;

        if ($run['exit'] !== 0 && $name === 'generate-ai-catalog-check') {
            $regen = aiRunCommand($root, 'php tools/ai/generate-ai-catalog.php');
            if ($regen['exit'] === 0) {
                $run = aiRunCommand($root, $command);
                $autoFixApplied = true;
            }
        }

        if ($run['exit'] !== 0 && $name === 'generate-repo-structure-check') {
            $regen = aiRunCommand($root, 'php tools/ai/generate-repo-structure.php --with-scc');
            if ($regen['exit'] === 0) {
                $run = aiRunCommand($root, $command);
                $autoFixApplied = true;
            }
        }

        $results[] = [
            'name' => $name,
            'command' => $command,
            'exit' => $run['exit'],
            'passed' => $run['exit'] === 0,
            'auto_fix_applied' => $autoFixApplied,
            'log' => $logDirLabel . '/' . $logFilePrefix . $name . '.log',
        ];
        file_put_contents($logDir . DIRECTORY_SEPARATOR . $logFilePrefix . $name . '.log', "STDOUT:\n" . $run['stdout'] . "\nSTDERR:\n" . $run['stderr']);
        if ($run['exit'] !== 0) {
            $failed[] = $name;
        }
    }

    $status = $failed === [] ? 'passed' : 'failed';
    $recommended = $failed === []
        ? 'Run next to choose commit or PR closeout action.'
        : 'Open verify logs and fix the first failing check before proceeding.';

    $findings = [];
    foreach ($failed as $name) {
        $findings[] = [
            'severity' => 'ERROR',
            'code' => 'CHECK_FAILED',
            'file' => null,
            'message' => 'Verification check failed: ' . $name,
            'suggested_fix' => 'Inspect docs/ai/generated logs and rerun verify.',
        ];
    }

    $placeholderArtifact = aiLoadArtifactData($root, 'placeholders.json');
    $placeholderCount = (int) (($placeholderArtifact['data']['count'] ?? 0));
    if ($placeholderCount > 0) {
        $findings[] = [
            'severity' => $strict ? 'ERROR' : 'WARNING',
            'code' => 'UNFILLED_REQUIRED_PLACEHOLDER',
            'file' => 'docs/ai',
            'message' => 'Unresolved placeholders detected.',
            'suggested_fix' => 'Run php tools/ai/ai.php placeholders --fail and update placeholders.',
        ];
        $findings[] = [
            'severity' => $strict ? 'WARNING' : 'INFO',
            'code' => 'UNFILLED_OPTIONAL_PLACEHOLDER',
            'file' => 'docs/ai',
            'message' => 'Optional placeholders may remain unresolved.',
            'suggested_fix' => 'Review placeholder list and fill values as needed for strict mode.',
        ];
    }

    $manifestPresent = is_file(aiInstallManifestPath($root));
    if (!$manifestPresent) {
        $findings[] = [
            'severity' => 'ERROR',
            'code' => 'MISSING_REQUIRED_FILE',
            'file' => '.ai-install-manifest.json',
            'message' => 'Canonical install manifest is missing.',
            'suggested_fix' => 'Run install apply to create canonical install manifest.',
        ];
    } else {
        $canonicalManifest = json_decode((string) file_get_contents(aiInstallManifestPath($root)), true);
        if (!is_array($canonicalManifest)) {
            $findings[] = [
                'severity' => 'ERROR',
                'code' => 'MISSING_REQUIRED_FILE',
                'file' => '.ai-install-manifest.json',
                'message' => 'Canonical install manifest is invalid JSON.',
                'suggested_fix' => 'Re-run install apply to regenerate manifest.',
            ];
        } else {
            $derivedManifestPath = aiInstallDerivedManifestPath($root);
            if (is_file($derivedManifestPath)) {
                if (hash_file('sha256', aiInstallManifestPath($root)) !== hash_file('sha256', $derivedManifestPath)) {
                    $findings[] = [
                        'severity' => $strict ? 'WARNING' : 'INFO',
                        'code' => 'GENERATED_DOC_OUT_OF_SYNC',
                        'file' => 'docs/ai/generated/install-manifest.json',
                        'message' => 'Derived install manifest is out of sync with canonical manifest.',
                        'suggested_fix' => 'Regenerate derived install artifacts by rerunning install or sync command.',
                    ];
                }
            }

            $manifestFiles = is_array($canonicalManifest['files'] ?? null) ? $canonicalManifest['files'] : [];
            foreach ($manifestFiles as $rel => $meta) {
                if (!is_array($meta)) {
                    continue;
                }
                $abs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, (string) $rel);
                if (!file_exists($abs)) {
                    $findings[] = [
                        'severity' => 'ERROR',
                        'code' => 'MISSING_REQUIRED_FILE',
                        'file' => (string) $rel,
                        'message' => 'Required managed file is missing.',
                        'suggested_fix' => 'Restore via install repair or rollback.',
                    ];
                    continue;
                }
                $currentHash = aiHashPath($abs);
                $installedHash = (string) ($meta['installed_hash'] ?? 'unknown');
                if ($installedHash !== 'unknown' && $currentHash !== $installedHash) {
                    $findings[] = [
                        'severity' => $strict ? 'ERROR' : 'WARNING',
                        'code' => 'HASH_DRIFT_MANAGED_FILE',
                        'file' => (string) $rel,
                        'message' => 'Managed file hash drift detected.',
                        'suggested_fix' => 'Review local customization and merge with source updates.',
                    ];
                    $findings[] = [
                        'severity' => 'INFO',
                        'code' => 'CUSTOMISED_MANAGED_FILE',
                        'file' => (string) $rel,
                        'message' => 'Managed file appears customized locally.',
                        'suggested_fix' => 'Keep or merge local changes intentionally.',
                    ];
                }
            }

            $managedPaths = is_array($canonicalManifest['managed_paths'] ?? null) ? $canonicalManifest['managed_paths'] : [];
            foreach ($managedPaths as $managedPath) {
                if (!is_string($managedPath) || $managedPath === '') {
                    continue;
                }
                $abs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $managedPath);
                if (!file_exists($abs)) {
                    $findings[] = [
                        'severity' => 'WARNING',
                        'code' => 'ORPHANED_MANAGED_FILE',
                        'file' => $managedPath,
                        'message' => 'Managed path listed in manifest is missing.',
                        'suggested_fix' => 'Reinstall managed adapters or clean manifest state.',
                    ];
                }
            }

            $sourceRepo = (string) (($canonicalManifest['package']['source_repository'] ?? 'unknown'));
            if ($sourceRepo === 'unknown' || $sourceRepo === '') {
                $findings[] = [
                    'severity' => 'ERROR',
                    'code' => 'PACKAGE_SOURCE_UNAVAILABLE',
                    'file' => '.ai-install-manifest.json',
                    'message' => 'Package source identity is missing.',
                    'suggested_fix' => 'Record source repository and ref in canonical manifest.',
                ];
            } else {
                $tags = [];
                $tagExit = 0;
                exec('git -C ' . escapeshellarg($root) . ' tag --sort=-v:refname', $tags, $tagExit);
                if ($tagExit !== 0) {
                    $findings[] = [
                        'severity' => 'WARNING',
                        'code' => 'PACKAGE_SOURCE_UNAVAILABLE',
                        'file' => '.ai-install-manifest.json',
                        'message' => 'Unable to query git tags for source-aware upgrade checks.',
                        'suggested_fix' => 'Ensure git metadata is available before upgrade.',
                    ];
                } else {
                    $installedRef = (string) (($canonicalManifest['package']['source_ref'] ?? 'unknown'));
                    $latestTag = $tags !== [] ? (string) $tags[0] : 'unknown';
                    if ($installedRef !== 'unknown' && $latestTag !== 'unknown' && $installedRef !== $latestTag) {
                        $findings[] = [
                            'severity' => 'INFO',
                            'code' => 'NEWER_PACKAGE_AVAILABLE',
                            'file' => '.ai-install-manifest.json',
                            'message' => 'A newer package tag appears available.',
                            'suggested_fix' => 'Run upgrade --dry-run and review file actions.',
                        ];
                    }
                }
            }
        }
    }

    $scriptsAiDir = $root . DIRECTORY_SEPARATOR . 'scripts' . DIRECTORY_SEPARATOR . 'ai';
    if (is_dir($scriptsAiDir)) {
        $requiredTools = ['bash', 'git', 'jq', 'rg', 'repomix', 'scc'];
        $optionalTools = ['fd', 'gh', 'fzf', 'bat', 'delta', 'yq', 'shellcheck', 'semgrep', 'ast-grep'];
        foreach ($requiredTools as $tool) {
            if (!aiCliCommandExists($tool)) {
                $findings[] = [
                    'severity' => 'ERROR',
                    'code' => 'MISSING_REQUIRED_TOOL',
                    'file' => 'scripts/ai',
                    'message' => 'Required tool missing: ' . $tool,
                    'suggested_fix' => 'Install required scripts-pack dependency.',
                ];
            }
        }
        foreach ($optionalTools as $tool) {
            if (!aiCliCommandExists($tool)) {
                $findings[] = [
                    'severity' => $strict ? 'WARNING' : 'INFO',
                    'code' => 'MISSING_OPTIONAL_TOOL',
                    'file' => 'scripts/ai',
                    'message' => 'Optional tool missing: ' . $tool,
                    'suggested_fix' => 'Install optional tooling for faster workflows.',
                ];
            }
        }
    }

    $hooksWired = is_dir($root . DIRECTORY_SEPARATOR . '.git' . DIRECTORY_SEPARATOR . 'hooks') || is_dir($root . DIRECTORY_SEPARATOR . '.husky') || is_file($root . DIRECTORY_SEPARATOR . '.lefthook.yml');
    $hookFiles = [
        $root . DIRECTORY_SEPARATOR . 'scripts' . DIRECTORY_SEPARATOR . 'hooks' . DIRECTORY_SEPARATOR . 'pre-commit.sh',
        $root . DIRECTORY_SEPARATOR . 'scripts' . DIRECTORY_SEPARATOR . 'hooks' . DIRECTORY_SEPARATOR . 'commit-msg.sh',
    ];
    $isWindows = strtoupper(substr(PHP_OS, 0, 3)) === 'WIN';
    foreach ($hookFiles as $hookFile) {
        if (!is_file($hookFile)) {
            continue;
        }
        if ($isWindows) {
            $findings[] = [
                'severity' => 'INFO',
                'code' => 'HOOK_EXEC_CHECK_PLATFORM_LIMIT',
                'file' => str_replace('\\', '/', substr($hookFile, strlen($root) + 1)),
                'message' => 'Executable bit check skipped on Windows.',
                'suggested_fix' => 'Verify hook execution manually on Windows.',
            ];
            continue;
        }
        if ($hooksWired && !is_executable($hookFile)) {
            $findings[] = [
                'severity' => 'ERROR',
                'code' => 'UNRESOLVED_MANUAL_CONFLICT',
                'file' => str_replace('\\', '/', substr($hookFile, strlen($root) + 1)),
                'message' => 'Hook file is not executable while hooks appear wired.',
                'suggested_fix' => 'Run chmod +x on hook script files.',
            ];
        } elseif (!$hooksWired && !is_executable($hookFile)) {
            $findings[] = [
                'severity' => 'WARNING',
                'code' => 'HOOK_NOT_WIRED',
                'file' => str_replace('\\', '/', substr($hookFile, strlen($root) + 1)),
                'message' => 'Hook pack files exist but hooks are not wired.',
                'suggested_fix' => 'Use php tools/ai/ai.php hooks --driver <driver>.',
            ];
        }
    }

    $counts = ['errors' => 0, 'warnings' => 0, 'info' => 0];
    foreach ($findings as $finding) {
        $sev = strtolower((string) ($finding['severity'] ?? 'info'));
        if ($sev === 'error') {
            $counts['errors']++;
        } elseif ($sev === 'warning') {
            $counts['warnings']++;
        } else {
            $counts['info']++;
        }
    }
    $verifyStatus = ($counts['errors'] > 0 || ($strict && $counts['warnings'] > 0)) ? 'failed' : 'passed';

    $data = [
        'status' => $verifyStatus,
        'mode' => $strict ? 'strict' : 'default',
        'summary' => $counts,
        'check_count' => count($results),
        'failed_checks' => $failed,
        'results' => $results,
        'findings' => $findings,
        'log_dir' => $logDirLabel,
    ];

    $written = aiCliWriteArtifact($root, 'verify', 'php tools/ai/ai.php verify --changed', $data, $verifyStatus, null, $recommended);
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    if ($jsonMode) {
        fwrite(STDOUT, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);
    }
    if ($counts['errors'] > 0) {
        return 2;
    }
    if ($strict && $counts['warnings'] > 0) {
        return 2;
    }
    return 0;
}

function aiRunNext(string $root): int
{
    $generatedDir = aiCliGeneratedDir($root);
    $required = ['project-snapshot.json', 'freshness.json', 'budget.json', 'workflow.json'];
    $missing = [];
    foreach ($required as $artifact) {
        if (!is_file($generatedDir . DIRECTORY_SEPARATOR . $artifact)) {
            $missing[] = $artifact;
        }
    }
    if ($missing !== []) {
        $data = [
            'status' => 'blocked',
            'reason' => 'missing required predecessor artifacts',
            'missing_artifacts' => $missing,
        ];
        $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Run snapshot, freshness, budget, and workflow first.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    $stale = aiEvaluateStaleEntries($root);
    if ($stale !== []) {
        $artifact = $stale[0];
        $baseName = pathinfo($artifact, PATHINFO_FILENAME);
        $data = [
            'status' => 'blocked',
            'reason' => 'stale artifacts detected',
            'stale_artifacts' => $stale,
            'next_action' => 'php tools/ai/ai.php ' . $baseName,
        ];
        $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Regenerate stale artifact before continuing.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    $preflight = aiLoadArtifactData($root, 'preflight.json');
    if ($preflight !== null && ($preflight['data']['status'] ?? 'unknown') === 'failed') {
        $data = [
            'status' => 'blocked',
            'reason' => 'installer preflight failed',
            'next_action' => 'php tools/ai/ai.php preflight',
        ];
        $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Fix preflight failures before install/apply commands.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    $packageVerify = aiLoadArtifactData($root, 'package-verify.json');
    if ($packageVerify !== null && ($packageVerify['status'] ?? 'unknown') === 'failed') {
        $data = [
            'status' => 'blocked',
            'reason' => 'source package integrity mismatch',
            'next_action' => 'php tools/ai/ai.php package-lock --update && php tools/ai/ai.php package-verify',
        ];
        $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Resolve package checksum drift before installation changes.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }

    $env = aiLoadArtifactData($root, 'env-check.json');
    if ($env !== null) {
        $missingRequired = $env['data']['missing_required'] ?? [];
        if (is_array($missingRequired) && $missingRequired !== []) {
            $data = [
                'status' => 'blocked',
                'reason' => 'environment missing required tooling',
                'missing_required' => $missingRequired,
                'next_action' => 'Install required tools then rerun env-check and rebase-state.',
            ];
            $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Run env-check after installing missing tools.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }

    $ask = aiLoadArtifactData($root, 'ask.json');
    if ($ask !== null) {
        $askStatus = (string) ($ask['data']['status'] ?? '');
        if ($askStatus === 'blocked') {
            $data = [
                'status' => 'blocked',
                'reason' => 'open clarification question',
                'question_id' => $ask['data']['question_id'] ?? 'unknown',
                'question' => $ask['data']['question'] ?? 'unknown',
                'next_action' => 'Answer blocked question or accept documented default path.',
            ];
            $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Resolve ask artifact before proceeding.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }

    $budget = json_decode((string) file_get_contents($generatedDir . DIRECTORY_SEPARATOR . 'budget.json'), true);
    $remaining = (int) ($budget['data']['remaining_tokens'] ?? 0);
    if ($remaining < 0) {
        $data = [
            'status' => 'warning',
            'reason' => 'context budget exceeded',
            'remaining_tokens' => $remaining,
            'next_action' => 'php tools/ai/ai.php budget --context-window 64000',
        ];
        $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'warning', null, 'Reduce context scope before proceeding.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 0;
    }

    $autoFix = aiLoadArtifactData($root, 'auto-fix.json');
    if ($autoFix !== null) {
        $safeFixes = $autoFix['data']['safe_fixes'] ?? [];
        if (is_array($safeFixes) && $safeFixes !== []) {
            $data = [
                'status' => 'warning',
                'reason' => 'safe auto-fix opportunities detected',
                'safe_fix_count' => count($safeFixes),
                'next_action' => 'Review auto-fix --dry-run suggestions and apply deterministic regen commands.',
            ];
            $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'warning', null, 'Apply safe fixes then rerun rebase-state.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 0;
        }
    }

    $verifyPath = $generatedDir . DIRECTORY_SEPARATOR . 'verify.json';
    if (is_file($verifyPath)) {
        $verify = json_decode((string) file_get_contents($verifyPath), true);
        $verifyStatus = (string) ($verify['status'] ?? 'unknown');
        if ($verifyStatus === 'failed') {
            $failedChecks = $verify['data']['failed_checks'] ?? [];
            $first = is_array($failedChecks) && $failedChecks !== [] ? (string) $failedChecks[0] : 'unknown';
            $data = [
                'status' => 'blocked',
                'reason' => 'verification failed',
                'failed_check' => $first,
                'next_action' => 'Inspect docs/ai/generated/logs from verify output and fix the first failure.',
            ];
            $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Fix verify failures before commit or PR steps.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }

    $riskPath = $generatedDir . DIRECTORY_SEPARATOR . 'risk.json';
    if (is_file($riskPath)) {
        $risk = json_decode((string) file_get_contents($riskPath), true);
        $level = (string) ($risk['data']['risk_level'] ?? 'low');
        if ($level === 'high' && !is_file($verifyPath)) {
            $data = [
                'status' => 'blocked',
                'reason' => 'high risk change without verify evidence',
                'next_action' => 'php tools/ai/ai.php verify --changed',
            ];
            $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Run verify for high risk changes.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }

    $impact = aiLoadArtifactData($root, 'impact.json');
    if ($impact !== null) {
        $impactScore = (int) ($impact['data']['impact_score'] ?? 0);
        if ($impactScore >= 70 && !is_file($verifyPath)) {
            $data = [
                'status' => 'blocked',
                'reason' => 'high impact change without verify evidence',
                'impact_score' => $impactScore,
                'next_action' => 'php tools/ai/ai.php verify --changed',
            ];
            $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Run verify for high impact changes.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }

    $logs = aiLoadArtifactData($root, 'logs.json');
    if ($logs !== null && is_file($verifyPath)) {
        $verify = json_decode((string) file_get_contents($verifyPath), true);
        $verifyStatus = (string) ($verify['status'] ?? 'unknown');
        if ($verifyStatus === 'failed') {
            $entries = $logs['data']['entries'] ?? [];
            $data = [
                'status' => 'blocked',
                'reason' => 'verification failed; logs available for drill-down',
                'log_entries' => is_array($entries) ? $entries : [],
                'next_action' => 'php tools/ai/ai.php logs <verify-run-dir>',
            ];
            $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'blocked', null, 'Inspect logs and fix first failure.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }

    $data = [
        'status' => 'ok',
        'reason' => 'all required workflow-control artifacts are fresh and valid',
        'next_action' => 'Prepare commit message or PR summary from current diff.',
        'recommended_commands' => [
            'php tools/ai/ai.php diff-summary --base main',
            'php tools/ai/ai.php risk --base main',
            'php tools/ai/ai.php verify --changed',
        ],
    ];

    $written = aiCliWriteArtifact($root, 'next', 'php tools/ai/ai.php next', $data, 'ok', null, 'Proceed to commit-msg or pr-summary in the next phase.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunAsk(string $root, array $args): int
{
    $resolveId = aiParseArg($args, 'resolve');
    if ($resolveId !== null && $resolveId !== '') {
        $answer = aiParseArg($args, 'answer');
        if ($answer === null || $answer === '') {
            throw new RuntimeException('ask --resolve requires --answer');
        }

        $existing = aiLoadArtifactData($root, 'ask.json');
        if ($existing === null) {
            throw new RuntimeException('No existing ask artifact found to resolve');
        }

        $existingData = $existing['data'] ?? [];
        if (!is_array($existingData)) {
            throw new RuntimeException('Malformed ask artifact data');
        }

        $currentId = (string) ($existingData['question_id'] ?? '');
        if ($currentId === '' || $currentId !== $resolveId) {
            throw new RuntimeException('ask --resolve did not match current question_id');
        }

        $resolvedData = $existingData;
        $resolvedData['status'] = 'resolved';
        $resolvedData['resolved_at_utc'] = gmdate('c');
        $resolvedData['answer'] = $answer;
        $resolvedData['resolution_mode'] = 'explicit-answer';

        $written = aiCliWriteArtifact($root, 'ask', 'php tools/ai/ai.php ask --resolve ' . $resolveId . ' --answer ' . $answer, $resolvedData, 'ok', null, 'Clarification resolved; rerun next to continue orchestration.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 0;
    }

    $question = $args[0] ?? '';
    if ($question === '') {
        throw new RuntimeException('ask requires a question as the first positional argument');
    }

    $optionsRaw = aiParseArg($args, 'options') ?? '';
    $options = $optionsRaw === '' ? [] : array_values(array_filter(array_map('trim', explode(',', $optionsRaw)), static fn(string $v): bool => $v !== ''));
    $default = aiParseArg($args, 'default') ?? ($options[0] ?? 'unknown');
    $whyNeeded = aiParseArg($args, 'why-needed') ?? 'Decision ambiguity materially changes implementation direction.';
    $blocksRaw = aiParseArg($args, 'blocks') ?? 'next';
    $blocks = array_values(array_filter(array_map('trim', explode(',', $blocksRaw)), static fn(string $v): bool => $v !== ''));

    $questionId = 'q-' . gmdate('Ymd-His') . '-' . substr(md5($question), 0, 6);
    $data = [
        'status' => 'blocked',
        'question_id' => $questionId,
        'question' => $question,
        'options' => $options,
        'why_needed' => $whyNeeded,
        'default_if_unanswered' => $default,
        'blocks' => $blocks,
    ];

    $written = aiCliWriteArtifact($root, 'ask', 'php tools/ai/ai.php ask', $data, 'blocked', null, 'Resolve this question before relying on next for safe action sequencing.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunEstimate(string $root, array $args): int
{
    $task = trim(implode(' ', $args));
    if ($task === '') {
        throw new RuntimeException('estimate requires a task description');
    }

    $keywords = [
        'risk' => ['auth', 'billing', 'security', 'migration', 'installer', 'policy', 'hook'],
        'scope' => ['multi', 'cross', 'adapter', 'catalog', 'workflow', 'generated', 'package'],
    ];

    $riskScore = 20;
    $complexity = 2;
    $taskLower = strtolower($task);

    foreach ($keywords['risk'] as $word) {
        if (str_contains($taskLower, $word)) {
            $riskScore += 10;
            $complexity += 1;
        }
    }
    foreach ($keywords['scope'] as $word) {
        if (str_contains($taskLower, $word)) {
            $riskScore += 6;
            $complexity += 1;
        }
    }

    $riskScore = min(100, $riskScore);
    $complexity = min(10, $complexity);
    $level = $riskScore >= 70 ? 'high' : ($riskScore >= 40 ? 'medium' : 'low');

    $data = [
        'task' => $task,
        'complexity' => $complexity,
        'risk_score' => $riskScore,
        'risk_level' => $level,
        'suggested_first_step' => 'php tools/ai/ai.php context --task "' . addslashes($task) . '"',
        'recommended_next_action' => 'php tools/ai/ai.php diff-summary --base main',
    ];

    $written = aiCliWriteArtifact($root, 'estimate', 'php tools/ai/ai.php estimate', $data, 'ok', $riskScore, 'Use context + diff-summary before implementation.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunImpact(string $root, array $args): int
{
    $base = aiParseArg($args, 'base') ?? 'main';
    $changed = [];
    exec('git -C ' . escapeshellarg($root) . ' diff --name-only ' . escapeshellarg($base) . '...HEAD', $changed);

    $areas = [];
    $tests = [];
    foreach ($changed as $path) {
        if (str_starts_with($path, 'tools/ai/')) {
            $areas['ai-tooling'] = true;
            $tests[] = 'php tools/ai/validate-ai-config.php';
            $tests[] = 'php tools/ai/validate-ai-catalog.php';
        }
        if (str_starts_with($path, 'scripts/')) {
            $areas['automation-scripts'] = true;
            $tests[] = 'bash scripts/doctor.sh';
        }
        if (str_starts_with($path, 'docs/ai/')) {
            $areas['ai-docs'] = true;
            $tests[] = 'php tools/ai/generate-ai-catalog.php --check';
        }
        if (str_starts_with($path, 'packages/ai-universal-rules/')) {
            $areas['package-assets'] = true;
            $tests[] = 'php tools/ai/validate-ai-catalog.php';
        }
        if (str_starts_with($path, '.github/')) {
            $areas['copilot-adapter'] = true;
            $tests[] = 'bash scripts/doctor.sh';
        }
    }

    $areaList = array_keys($areas);
    sort($areaList);
    $tests = array_values(array_unique($tests));

    $impactScore = min(100, (count($areaList) * 18) + (count($changed) > 15 ? 20 : count($changed)));
    $data = [
        'base' => $base,
        'changed_files_count' => count($changed),
        'changed_files' => $changed,
        'likely_affected_areas' => $areaList,
        'related_checks' => $tests,
        'impact_score' => $impactScore,
    ];

    $written = aiCliWriteArtifact($root, 'impact', 'php tools/ai/ai.php impact --base ' . $base, $data, 'ok', $impactScore, 'Run related checks before merge or handoff.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunFreshness(string $root): int
{
    $generatedDir = aiCliGeneratedDir($root);
    $registry = aiCliLoadArtifactsRegistry($generatedDir);
    $current = aiCliCurrentCommit($root);

    $entries = [];
    $staleCount = 0;
    $artifacts = $registry['artifacts'] ?? [];
    if (!is_array($artifacts)) {
        $artifacts = [];
    }

    foreach ($artifacts as $name => $meta) {
        if (!is_array($meta)) {
            continue;
        }
        $basedOn = (string) ($meta['based_on_commit'] ?? 'unknown');
        $isStale = $basedOn !== 'unknown' && $current !== 'unknown' && $basedOn !== $current;
        if ($isStale) {
            $staleCount++;
        }
        $entries[] = [
            'artifact' => $name,
            'based_on_commit' => $basedOn,
            'current_commit' => $current,
            'stale' => $isStale,
            'recommendation' => $isStale ? 'Regenerate this artifact before using next.' : 'Current at HEAD.',
        ];
    }

    $status = $staleCount > 0 ? 'warning' : 'ok';
    $recommended = $staleCount > 0 ? 'php tools/ai/ai.php snapshot' : 'php tools/ai/ai.php next';

    $data = [
        'status' => $status,
        'stale_count' => $staleCount,
        'artifact_count' => count($entries),
        'artifacts' => $entries,
    ];

    $written = aiCliWriteArtifact($root, 'freshness', 'php tools/ai/ai.php freshness', $data, $status, null, $recommended);
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunBudget(string $root, array $args): int
{
    $contextWindow = 32000;
    $artifactFilter = null;

    for ($i = 0; $i < count($args); $i++) {
        $arg = $args[$i];
        if ($arg === '--context-window') {
            $contextWindow = (int) ($args[$i + 1] ?? $contextWindow);
            $i++;
            continue;
        }
        if (str_starts_with($arg, '--context-window=')) {
            $contextWindow = (int) substr($arg, 17);
            continue;
        }
        if ($arg === '--artifact') {
            $artifactFilter = (string) ($args[$i + 1] ?? '');
            $i++;
            continue;
        }
        if (str_starts_with($arg, '--artifact=')) {
            $artifactFilter = substr($arg, 11);
            continue;
        }
    }

    $registry = aiCliLoadArtifactsRegistry(aiCliGeneratedDir($root));
    $artifacts = $registry['artifacts'] ?? [];
    if (!is_array($artifacts)) {
        $artifacts = [];
    }

    $items = [];
    $total = 0;
    foreach ($artifacts as $name => $meta) {
        if (!is_array($meta)) {
            continue;
        }
        if ($artifactFilter !== null && $artifactFilter !== '' && $artifactFilter !== $name) {
            continue;
        }
        $tokens = (int) ($meta['estimated_tokens'] ?? 0);
        $items[] = [
            'artifact' => $name,
            'estimated_tokens' => $tokens,
            'stale' => (bool) ($meta['stale'] ?? false),
        ];
        $total += $tokens;
    }

    usort($items, static fn(array $a, array $b): int => $b['estimated_tokens'] <=> $a['estimated_tokens']);

    $remaining = $contextWindow - $total;
    $status = $remaining < 0 ? 'warning' : 'ok';
    $recommended = $remaining < 0
        ? 'Trim context by using smaller path- or changed-scoped artifacts before next.'
        : 'Context budget looks safe for a focused next step.';

    $data = [
        'context_window' => $contextWindow,
        'estimated_total_tokens' => $total,
        'remaining_tokens' => $remaining,
        'artifact_count' => count($items),
        'artifacts' => $items,
    ];

    $written = aiCliWriteArtifact($root, 'budget', 'php tools/ai/ai.php budget', $data, $status, null, $recommended);
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}
