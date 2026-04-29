<?php

declare(strict_types=1);

require_once __DIR__ . '/ai_output_lib.php';
require_once __DIR__ . '/install/core.php';
require_once __DIR__ . '/advisor/scanner.php';
require_once __DIR__ . '/advisor/scorer.php';
require_once __DIR__ . '/advisor/validator.php';
require_once __DIR__ . '/advisor/secret-scan.php';
require_once __DIR__ . '/advisor/packer.php';
require_once __DIR__ . '/advisor/token-budget.php';
require_once __DIR__ . '/advisor/prompt-builder.php';
require_once __DIR__ . '/advisor/drift.php';
require_once __DIR__ . '/advisor/submitter.php';

function aiUsage(): void
{
    $usage = <<<'TXT'
Usage:
  php tools/ai/ai.php <command> [options]

Commands:
  list           List available AI workflow commands
  diff-summary   Summarize current branch diff and changed files
  risk           Score changed-slice risk using deterministic rules
  verify         Run repository AI verification digest
  next           Recommend the next required action
  rebase-state   Run snapshot->diff->risk->verify->freshness->budget->next
  decision       Add architecture/workflow decision records
  why            Show decision rationale history
  session-resume Build concise continuation summary from artifacts
  commit-msg     Generate commit message suggestion from artifacts
  pr-summary     Generate PR summary from artifacts
  logs           List or read generated verify logs
  env-check      Report environment/tooling readiness for AI workflow scripts
  file-context   Build focused context artifact for one file
  orphans        Detect possibly unreferenced/orphan workflow files
  auto-fix       Preview deterministic safe fixes (dry-run only)
  impact         Generate deterministic change impact map
  ask            Record structured blocking clarification questions
  estimate       Estimate task complexity/risk with deterministic heuristics
  conflicts      Summarize merge conflict state and suggested resolution posture
  find           Search tracked files by deterministic path/content match
  symbols        Extract top-level code symbols from tracked source files
  preflight      Check installer prerequisites and environment readiness
  package-lock   Check or update source template checksum lock
  package-verify Verify source templates against checksum lock
  audit-instructions Audit local instruction surfaces and ownership hints
  adapter-plan   Generate deterministic install/upgrade plan preview
  plan           Alias of adapter-plan
  install        Run installer workflow (dry-run/default safe)
  upgrade        Preview or apply manifest-aware upgrades (planned)
  adapter-validate Validate installed adapter state and managed assets
  rollback       Restore from installer backup artifacts
  packs          List installer profiles and packs
  placeholders   Scan and manage unresolved placeholders
  hooks          Hook wiring and status helpers (compatibility surface)
  toolchain      Check/install-plan/apply safe AI toolchain dependencies
  run-script     Run approved scripts-pack helper scripts by registry id
  install-docs   Generate or check install instructions and catalog docs
  advisor        Project intelligence advisor pipeline commands
  version        Show installer/package identity from canonical manifest
  freshness      Evaluate generated artifact freshness
  budget         Estimate context token budget from generated artifacts
  workflow       Show workflow dependency graph summary
  snapshot       Generate current repository snapshot
  help           Show this help

Examples:
  php tools/ai/ai.php list
  php tools/ai/ai.php freshness
  php tools/ai/ai.php budget --context-window 32000
  php tools/ai/ai.php workflow
  php tools/ai/ai.php snapshot
  php tools/ai/ai.php diff-summary --base main
  php tools/ai/ai.php risk --base main
  php tools/ai/ai.php verify --changed
  php tools/ai/ai.php next
  php tools/ai/ai.php rebase-state
  php tools/ai/ai.php decision add --file tools/ai/ai.php --reason "added workflow dispatcher"
  php tools/ai/ai.php why
  php tools/ai/ai.php session-resume
  php tools/ai/ai.php commit-msg
  php tools/ai/ai.php pr-summary
  php tools/ai/ai.php logs
  php tools/ai/ai.php env-check
  php tools/ai/ai.php file-context tools/ai/ai.php
  php tools/ai/ai.php orphans
  php tools/ai/ai.php auto-fix --dry-run
  php tools/ai/ai.php impact --base main
  php tools/ai/ai.php ask "Which runtime adapter is in scope?" --options "copilot,opencode,both" --default both
  php tools/ai/ai.php estimate "add workflow-control command"
  php tools/ai/ai.php conflicts
  php tools/ai/ai.php find workflow
  php tools/ai/ai.php symbols aiRun
  php tools/ai/ai.php preflight
  php tools/ai/ai.php package-lock --check
  php tools/ai/ai.php package-verify
  php tools/ai/ai.php install --dry-run --mode sidecar-only
  php tools/ai/ai.php plan --targets copilot,opencode
  php tools/ai/ai.php packs --validate
  php tools/ai/ai.php toolchain --with repomix,scc --install-plan
  php tools/ai/ai.php run-script --list
  php tools/ai/ai.php install-docs --check
  php tools/ai/ai.php advisor --all
  php tools/ai/ai.php placeholders --fail
  php tools/ai/ai.php version
TXT;

    fwrite(STDOUT, $usage . PHP_EOL);
}

function aiRunList(string $root): int
{
    $data = [
        'commands' => [
            'list',
            'freshness',
            'budget',
            'workflow',
            'snapshot',
            'diff-summary',
            'risk',
            'verify',
            'next',
            'rebase-state',
            'decision',
            'why',
            'session-resume',
            'commit-msg',
            'pr-summary',
            'logs',
            'env-check',
            'file-context',
            'orphans',
            'auto-fix',
            'impact',
            'ask',
            'estimate',
            'conflicts',
            'find',
            'symbols',
            'preflight',
            'package-lock',
            'package-verify',
            'audit-instructions',
            'adapter-plan',
            'plan',
            'install',
            'upgrade',
            'adapter-validate',
            'rollback',
            'packs',
            'placeholders',
            'hooks',
            'toolchain',
            'run-script',
            'install-docs',
            'advisor',
            'version',
        ],
    ];

    $written = aiCliWriteArtifact($root, 'ai-commands', 'php tools/ai/ai.php list', $data, 'ok');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunCommand(string $root, string $command): array
{
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $env = [
        'HOME' => sys_get_temp_dir(),
        'XDG_CONFIG_HOME' => sys_get_temp_dir(),
        'GIT_CONFIG_GLOBAL' => '/dev/null',
        'PATH' => (string) getenv('PATH'),
    ];

    if (str_starts_with($command, 'php ')) {
        $phpBin = defined('PHP_BINARY') ? (string) PHP_BINARY : 'php';
        $command = escapeshellarg($phpBin) . substr($command, 3);
    }

    $process = proc_open($command, $descriptors, $pipes, $root, $env);
    if (!is_resource($process)) {
        throw new RuntimeException('Failed to run command: ' . $command);
    }

    fclose($pipes[0]);
    $stdout = (string) stream_get_contents($pipes[1]);
    $stderr = (string) stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $exit = proc_close($process);

    return [
        'command' => $command,
        'stdout' => $stdout,
        'stderr' => $stderr,
        'exit' => (int) $exit,
    ];
}

function aiCliCommandExists(string $command): bool
{
    $out = [];
    $exit = 0;
    if (PHP_OS_FAMILY === 'Windows') {
        exec('where ' . escapeshellarg($command) . ' >NUL 2>&1', $out, $exit);
        if ($exit === 0) {
            return true;
        }
        $user = getenv('USERPROFILE');
        if (is_string($user) && $user !== '') {
            $base = $user . DIRECTORY_SEPARATOR . 'AppData' . DIRECTORY_SEPARATOR . 'Local' . DIRECTORY_SEPARATOR . 'Microsoft' . DIRECTORY_SEPARATOR . 'WinGet' . DIRECTORY_SEPARATOR . 'Packages';
            if (is_dir($base)) {
                $wanted = strtolower($command . '.exe');
                $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($base, FilesystemIterator::SKIP_DOTS));
                foreach ($it as $entry) {
                    if (!$entry->isFile()) {
                        continue;
                    }
                    if (strtolower($entry->getFilename()) === $wanted) {
                        $dir = (string) $entry->getPath();
                        $path = (string) getenv('PATH');
                        $parts = preg_split('/;/', $path) ?: [];
                        $hasDir = false;
                        foreach ($parts as $part) {
                            if (strcasecmp(trim($part), $dir) === 0) {
                                $hasDir = true;
                                break;
                            }
                        }
                        if (!$hasDir) {
                            $newPath = $dir . ';' . $path;
                            putenv('PATH=' . $newPath);
                            $_SERVER['PATH'] = $newPath;
                            $_ENV['PATH'] = $newPath;
                        }
                        return true;
                    }
                }
            }
        }
        return false;
    }
    exec('command -v ' . escapeshellarg($command) . ' >/dev/null 2>&1', $out, $exit);
    return $exit === 0;
}

function aiEvaluateStaleEntries(string $root): array
{
    $registry = aiCliLoadArtifactsRegistry(aiCliGeneratedDir($root));
    $current = aiCliCurrentCommit($root);
    $stale = [];

    $artifacts = $registry['artifacts'] ?? [];
    if (!is_array($artifacts)) {
        return [];
    }

    foreach ($artifacts as $name => $meta) {
        if (!is_array($meta)) {
            continue;
        }
        $basedOn = (string) ($meta['based_on_commit'] ?? 'unknown');
        if ($basedOn !== 'unknown' && $current !== 'unknown' && $basedOn !== $current) {
            $stale[] = $name;
        }
    }

    return $stale;
}

function aiRunDiffSummary(string $root, array $args): int
{
    $base = 'main';
    for ($i = 0; $i < count($args); $i++) {
        $arg = $args[$i];
        if ($arg === '--base') {
            $base = (string) ($args[$i + 1] ?? $base);
            $i++;
            continue;
        }
        if (str_starts_with($arg, '--base=')) {
            $base = (string) substr($arg, 7);
        }
    }

    $changed = [];
    exec('git -C ' . escapeshellarg($root) . ' diff --name-only ' . escapeshellarg($base) . '...HEAD', $changed);
    $staged = [];
    exec('git -C ' . escapeshellarg($root) . ' diff --name-only --cached', $staged);
    $unstaged = [];
    exec('git -C ' . escapeshellarg($root) . ' diff --name-only', $unstaged);

    $classify = static function (string $path): string {
        if (str_starts_with($path, 'docs/')) {
            return 'docs';
        }
        if (str_starts_with($path, 'scripts/')) {
            return 'script';
        }
        if (str_starts_with($path, 'tools/')) {
            return 'tool';
        }
        if (str_starts_with($path, '.github/')) {
            return 'adapter';
        }
        if (str_starts_with($path, 'packages/')) {
            return 'package';
        }
        return 'other';
    };

    $byType = [];
    foreach ($changed as $path) {
        $type = $classify($path);
        if (!isset($byType[$type])) {
            $byType[$type] = [];
        }
        $byType[$type][] = $path;
    }

    $data = [
        'base' => $base,
        'changed_files_count' => count($changed),
        'changed_files' => $changed,
        'staged_files_count' => count($staged),
        'unstaged_files_count' => count($unstaged),
        'changed_by_type' => $byType,
    ];

    $written = aiCliWriteArtifact(
        $root,
        'diff-summary',
        'php tools/ai/ai.php diff-summary --base ' . $base,
        $data,
        'ok',
        null,
        'Run risk and verify on this diff.'
    );
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunRisk(string $root, array $args): int
{
    $base = 'main';
    for ($i = 0; $i < count($args); $i++) {
        $arg = $args[$i];
        if ($arg === '--base') {
            $base = (string) ($args[$i + 1] ?? $base);
            $i++;
            continue;
        }
        if (str_starts_with($arg, '--base=')) {
            $base = (string) substr($arg, 7);
        }
    }

    $changed = [];
    exec('git -C ' . escapeshellarg($root) . ' diff --name-only ' . escapeshellarg($base) . '...HEAD', $changed);

    $score = 0;
    $reasons = [];
    foreach ($changed as $path) {
        if (str_starts_with($path, 'scripts/copilot/pre-tool-use.sh')) {
            $score += 30;
            $reasons[] = 'command approval policy changed';
            continue;
        }
        if (str_starts_with($path, 'tools/ai/install-ai-kit.php') || str_starts_with($path, 'tools/ai/install-copilot-kit.sh')) {
            $score += 25;
            $reasons[] = 'installer behavior changed';
            continue;
        }
        if (str_starts_with($path, '.schemas/')) {
            $score += 20;
            $reasons[] = 'schema contract changed';
            continue;
        }
        if (str_starts_with($path, 'docs/ai/generated/')) {
            $score += 10;
            $reasons[] = 'generated output touched';
            continue;
        }
        if (str_starts_with($path, 'docs/ai/')) {
            $score += 8;
            $reasons[] = 'ai workflow docs changed';
            continue;
        }
        if (str_starts_with($path, 'packages/ai-universal-rules/manifest.json')) {
            $score += 20;
            $reasons[] = 'package manifest changed';
            continue;
        }
        $score += 3;
    }

    $score = min(100, $score);
    $level = $score >= 70 ? 'high' : ($score >= 35 ? 'medium' : 'low');

    $data = [
        'base' => $base,
        'risk_score' => $score,
        'risk_level' => $level,
        'changed_files_count' => count($changed),
        'risk_reasons' => array_values(array_unique($reasons)),
    ];

    $written = aiCliWriteArtifact(
        $root,
        'risk',
        'php tools/ai/ai.php risk --base ' . $base,
        $data,
        'ok',
        $score,
        'Run verify to validate this risk posture with command evidence.'
    );
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunVerify(string $root, array $args): int
{
    $strict = in_array('--strict', $args, true);
    $jsonMode = in_array('--json', $args, true);
    $generatedDir = aiCliGeneratedDir($root);
    $logDir = $generatedDir . DIRECTORY_SEPARATOR . 'logs' . DIRECTORY_SEPARATOR . 'verify-' . date('Ymd-His');
    if (!is_dir($logDir) && !mkdir($logDir, 0777, true) && !is_dir($logDir)) {
        throw new RuntimeException('Could not create verify log dir');
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
            'log' => 'docs/ai/generated/logs/' . basename($logDir) . '/' . $name . '.log',
        ];
        file_put_contents($logDir . DIRECTORY_SEPARATOR . $name . '.log', "STDOUT:\n" . $run['stdout'] . "\nSTDERR:\n" . $run['stderr']);
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
        'log_dir' => 'docs/ai/generated/logs/' . basename($logDir),
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

function aiRunConflicts(string $root): int
{
    $statusOut = [];
    exec('git -C ' . escapeshellarg($root) . ' status --porcelain', $statusOut);
    $conflicts = [];
    foreach ($statusOut as $line) {
        $prefix = substr($line, 0, 2);
        if (in_array($prefix, ['UU', 'AA', 'DD', 'AU', 'UA', 'DU', 'UD'], true)) {
            $conflicts[] = [
                'status' => $prefix,
                'path' => trim(substr($line, 3)),
            ];
        }
    }

    $status = $conflicts === [] ? 'ok' : 'conflicts_found';
    $data = [
        'status' => $status,
        'conflict_count' => count($conflicts),
        'files' => $conflicts,
    ];

    $written = aiCliWriteArtifact($root, 'conflicts', 'php tools/ai/ai.php conflicts', $data, $status, null, $conflicts === [] ? 'No merge conflicts detected.' : 'Resolve conflicts, then run rebase-state.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $conflicts === [] ? 0 : 1;
}

function aiRunFind(string $root, array $args): int
{
    $query = trim(implode(' ', $args));
    if ($query === '') {
        throw new RuntimeException('find requires a search query');
    }

    $files = [];
    exec('git -C ' . escapeshellarg($root) . ' ls-files', $files);
    $files = array_values(array_filter($files, static fn(string $f): bool => $f !== ''));

    $pathMatches = [];
    $q = strtolower($query);
    foreach ($files as $path) {
        $pathLower = strtolower($path);
        if (str_contains($pathLower, $q)) {
            $score = str_starts_with(strtolower(basename($path)), $q) ? 100 : 70;
            $pathMatches[] = ['path' => $path, 'score' => $score, 'match' => 'path'];
        }
    }
    usort($pathMatches, static fn(array $a, array $b): int => $b['score'] <=> $a['score']);
    $pathMatches = array_slice($pathMatches, 0, 80);

    $contentMatchesRaw = [];
    exec('git -C ' . escapeshellarg($root) . ' grep -n -I -- ' . escapeshellarg($query) . ' -- 2>NUL', $contentMatchesRaw);
    $contentMatches = [];
    foreach (array_slice($contentMatchesRaw, 0, 120) as $line) {
        $parts = explode(':', $line, 3);
        if (count($parts) < 3) {
            continue;
        }
        $contentMatches[] = [
            'path' => $parts[0],
            'line' => (int) $parts[1],
            'preview' => trim($parts[2]),
        ];
    }

    $data = [
        'query' => $query,
        'path_matches_count' => count($pathMatches),
        'path_matches' => $pathMatches,
        'content_matches_count' => count($contentMatches),
        'content_matches' => $contentMatches,
    ];

    $written = aiCliWriteArtifact($root, 'find', 'php tools/ai/ai.php find ' . $query, $data, 'ok', null, 'Open highest scoring match first, then refine query if needed.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunSymbols(string $root, array $args): int
{
    $filter = trim(implode(' ', $args));
    $files = [];
    exec('git -C ' . escapeshellarg($root) . ' ls-files "*.php" "*.sh" "*.md" "*.json" "*.yml" "*.yaml"', $files);

    $symbols = [];
    foreach ($files as $relPath) {
        $absPath = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relPath);
        if (!is_file($absPath)) {
            continue;
        }
        $lines = file($absPath, FILE_IGNORE_NEW_LINES);
        if ($lines === false) {
            continue;
        }

        foreach ($lines as $idx => $line) {
            $name = null;
            $kind = null;

            if (preg_match('/^\s*function\s+([A-Za-z0-9_]+)\s*\(/', $line, $m) === 1) {
                $name = $m[1];
                $kind = 'function';
            } elseif (preg_match('/^\s*class\s+([A-Za-z0-9_]+)/', $line, $m) === 1) {
                $name = $m[1];
                $kind = 'class';
            } elseif (preg_match('/^\s*(?:public|private|protected)?\s*function\s+([A-Za-z0-9_]+)\s*\(/', $line, $m) === 1) {
                $name = $m[1];
                $kind = 'method';
            } elseif (preg_match('/^#\s+(.+)$/', $line, $m) === 1) {
                $name = trim($m[1]);
                $kind = 'heading';
            }

            if ($name === null || $kind === null) {
                continue;
            }
            if ($filter !== '' && stripos($name, $filter) === false) {
                continue;
            }

            $symbols[] = [
                'path' => $relPath,
                'line' => $idx + 1,
                'kind' => $kind,
                'name' => $name,
            ];
            if (count($symbols) >= 300) {
                break 2;
            }
        }
    }

    $data = [
        'filter' => $filter === '' ? null : $filter,
        'count' => count($symbols),
        'symbols' => $symbols,
    ];

    $written = aiCliWriteArtifact($root, 'symbols', 'php tools/ai/ai.php symbols' . ($filter === '' ? '' : ' ' . $filter), $data, 'ok', null, 'Jump to symbol locations directly for faster edits.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunRebaseState(string $root): int
{
    $commands = [
        'php tools/ai/ai.php snapshot',
        'php tools/ai/ai.php diff-summary --base main',
        'php tools/ai/ai.php risk --base main',
        'php tools/ai/ai.php verify --changed',
        'php tools/ai/ai.php freshness',
        'php tools/ai/ai.php budget',
        'php tools/ai/ai.php next',
    ];

    $runs = [];
    foreach ($commands as $command) {
        $result = aiRunCommand($root, $command);
        $runs[] = [
            'command' => $command,
            'exit' => $result['exit'],
        ];
        if ($result['exit'] !== 0 && !str_contains($command, 'next')) {
            $data = [
                'status' => 'failed',
                'failed_command' => $command,
                'runs' => $runs,
            ];
            aiCliWriteArtifact($root, 'rebase-state', 'php tools/ai/ai.php rebase-state', $data, 'failed', null, 'Fix the failed step and rerun rebase-state.');
            fwrite(STDOUT, 'Error: rebase-state failed at command: ' . $command . PHP_EOL);
            return 2;
        }
    }

    $data = [
        'status' => 'ok',
        'runs' => $runs,
        'next_artifact' => 'docs/ai/generated/next.json',
    ];
    $written = aiCliWriteArtifact($root, 'rebase-state', 'php tools/ai/ai.php rebase-state', $data, 'ok', null, 'Open next.json and execute the recommended action.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiDecisionsMarkdownPath(string $root): string
{
    return $root . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'decisions.md';
}

function aiDecisionsJsonlPath(string $root): string
{
    return $root . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'decisions.jsonl';
}

function aiEnsureDecisionsStore(string $root): void
{
    $md = aiDecisionsMarkdownPath($root);
    $jsonl = aiDecisionsJsonlPath($root);
    if (!is_file($md)) {
        file_put_contents($md, "# AI Decisions Log\n\n");
    }
    if (!is_file($jsonl)) {
        file_put_contents($jsonl, '');
    }
}

function aiParseArg(array $args, string $name): ?string
{
    for ($i = 0; $i < count($args); $i++) {
        $arg = $args[$i];
        if ($arg === '--' . $name) {
            return isset($args[$i + 1]) ? (string) $args[$i + 1] : null;
        }
        if (str_starts_with($arg, '--' . $name . '=')) {
            return (string) substr($arg, strlen($name) + 3);
        }
    }

    return null;
}

function aiRunDecision(string $root, array $args): int
{
    $sub = $args[0] ?? '';
    if ($sub !== 'add') {
        throw new RuntimeException('decision command supports only: add');
    }

    aiEnsureDecisionsStore($root);
    $file = aiParseArg($args, 'file') ?? 'unknown';
    $reason = aiParseArg($args, 'reason') ?? '';
    if ($reason === '') {
        throw new RuntimeException('decision add requires --reason');
    }

    $entry = [
        'timestamp' => aiCliIsoNow(),
        'commit' => aiCliCurrentCommit($root),
        'branch' => aiCliCurrentBranch($root),
        'file' => $file,
        'reason' => $reason,
    ];

    $encoded = json_encode($entry, JSON_UNESCAPED_SLASHES);
    if ($encoded === false) {
        throw new RuntimeException('Failed to encode decision entry.');
    }
    file_put_contents(aiDecisionsJsonlPath($root), $encoded . PHP_EOL, FILE_APPEND);

    $mdBlock = "## {$entry['timestamp']} — {$file}\n\n";
    $mdBlock .= "Decision reason:\n\n- {$reason}\n\n";
    $mdBlock .= "Context:\n\n- commit: `{$entry['commit']}`\n- branch: `{$entry['branch']}`\n\n";
    file_put_contents(aiDecisionsMarkdownPath($root), $mdBlock, FILE_APPEND);

    $data = [
        'status' => 'ok',
        'entry' => $entry,
        'decision_files' => [
            'docs/ai/decisions.md',
            'docs/ai/decisions.jsonl',
        ],
    ];

    $written = aiCliWriteArtifact($root, 'decision-add', 'php tools/ai/ai.php decision add', $data, 'ok', null, 'Use why to inspect decision history.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunWhy(string $root, array $args): int
{
    aiEnsureDecisionsStore($root);
    $filter = $args[0] ?? null;

    $lines = file(aiDecisionsJsonlPath($root), FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
    $entries = [];
    foreach ($lines as $line) {
        $decoded = json_decode($line, true);
        if (!is_array($decoded)) {
            continue;
        }
        if ($filter !== null && $filter !== '' && (string) ($decoded['file'] ?? '') !== $filter) {
            continue;
        }
        $entries[] = $decoded;
    }

    $data = [
        'filter' => $filter,
        'count' => count($entries),
        'entries' => $entries,
        'source' => [
            'docs/ai/decisions.md',
            'docs/ai/decisions.jsonl',
        ],
    ];

    $written = aiCliWriteArtifact($root, 'why', 'php tools/ai/ai.php why', $data, 'ok', null, 'Use session-resume for cross-artifact continuation context.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiLoadArtifactData(string $root, string $artifactName): ?array
{
    $path = aiCliGeneratedDir($root) . DIRECTORY_SEPARATOR . $artifactName;
    if (!is_file($path)) {
        return null;
    }
    $decoded = json_decode((string) file_get_contents($path), true);
    return is_array($decoded) ? $decoded : null;
}

function aiRunSessionResume(string $root): int
{
    $snapshot = aiLoadArtifactData($root, 'project-snapshot.json');
    $diff = aiLoadArtifactData($root, 'diff-summary.json');
    $risk = aiLoadArtifactData($root, 'risk.json');
    $verify = aiLoadArtifactData($root, 'verify.json');
    $next = aiLoadArtifactData($root, 'next.json');
    $freshness = aiLoadArtifactData($root, 'freshness.json');

    $data = [
        'snapshot' => [
            'branch' => $snapshot['data']['branch'] ?? 'unknown',
            'commit' => $snapshot['data']['commit'] ?? 'unknown',
            'dirty' => $snapshot['data']['dirty'] ?? null,
            'changed_files_count' => $snapshot['data']['changed_files_count'] ?? null,
        ],
        'diff' => [
            'changed_files_count' => $diff['data']['changed_files_count'] ?? null,
            'base' => $diff['data']['base'] ?? 'unknown',
        ],
        'risk' => [
            'risk_level' => $risk['data']['risk_level'] ?? 'unknown',
            'risk_score' => $risk['data']['risk_score'] ?? null,
        ],
        'verify' => [
            'status' => $verify['data']['status'] ?? 'unknown',
            'failed_checks' => $verify['data']['failed_checks'] ?? [],
        ],
        'freshness' => [
            'stale_count' => $freshness['data']['stale_count'] ?? null,
        ],
        'next' => [
            'status' => $next['data']['status'] ?? 'unknown',
            'next_action' => $next['data']['next_action'] ?? null,
        ],
    ];

    $written = aiCliWriteArtifact($root, 'session-resume', 'php tools/ai/ai.php session-resume', $data, 'ok', null, 'Resume work from next_action and current verify/risk posture.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunCommitMsg(string $root): int
{
    $diff = aiLoadArtifactData($root, 'diff-summary.json');
    $risk = aiLoadArtifactData($root, 'risk.json');
    $verify = aiLoadArtifactData($root, 'verify.json');

    $changedCount = (int) ($diff['data']['changed_files_count'] ?? 0);
    $riskLevel = (string) ($risk['data']['risk_level'] ?? 'unknown');
    $verifyStatus = (string) ($verify['data']['status'] ?? 'unknown');

    $prefix = 'chore(ai)';
    if ($riskLevel === 'high') {
        $prefix = 'feat(ai)';
    } elseif ($riskLevel === 'medium') {
        $prefix = 'refactor(ai)';
    }

    $message = sprintf('%s update workflow artifacts and checks (%d files, verify:%s)', $prefix, $changedCount, $verifyStatus);
    $txtPath = aiCliGeneratedDir($root) . DIRECTORY_SEPARATOR . 'commit-msg.txt';
    file_put_contents($txtPath, $message . PHP_EOL);

    $data = [
        'message' => $message,
        'changed_files_count' => $changedCount,
        'risk_level' => $riskLevel,
        'verify_status' => $verifyStatus,
        'output' => 'docs/ai/generated/commit-msg.txt',
    ];

    $written = aiCliWriteArtifact($root, 'commit-msg', 'php tools/ai/ai.php commit-msg', $data, 'ok', null, 'Use suggested commit message or adapt to final diff intent.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunPrSummary(string $root): int
{
    $diff = aiLoadArtifactData($root, 'diff-summary.json');
    $risk = aiLoadArtifactData($root, 'risk.json');
    $verify = aiLoadArtifactData($root, 'verify.json');

    $changed = (int) ($diff['data']['changed_files_count'] ?? 0);
    $riskLevel = (string) ($risk['data']['risk_level'] ?? 'unknown');
    $riskScore = $risk['data']['risk_score'] ?? null;
    $verifyStatus = (string) ($verify['data']['status'] ?? 'unknown');

    $summaryMd = "## Summary\n\n";
    $summaryMd .= "- Updated AI workflow artifacts and automation surfaces for current diff.\n";
    $summaryMd .= "- Changed files: {$changed}.\n\n";
    $summaryMd .= "## Risk\n\n";
    $summaryMd .= "- Risk level: {$riskLevel}" . ($riskScore !== null ? " ({$riskScore}/100)" : '') . "\n\n";
    $summaryMd .= "## Verification\n\n";
    $summaryMd .= "- Verify status: {$verifyStatus}\n";

    $prMdPath = aiCliGeneratedDir($root) . DIRECTORY_SEPARATOR . 'pr-summary.md';
    file_put_contents($prMdPath, $summaryMd);

    $data = [
        'summary_markdown_path' => 'docs/ai/generated/pr-summary.md',
        'changed_files_count' => $changed,
        'risk_level' => $riskLevel,
        'risk_score' => $riskScore,
        'verify_status' => $verifyStatus,
    ];

    $written = aiCliWriteArtifact($root, 'pr-summary', 'php tools/ai/ai.php pr-summary', $data, 'ok', null, 'Use generated PR summary as base and refine task-specific details.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunLogs(string $root, array $args): int
{
    $logsDir = aiCliGeneratedDir($root) . DIRECTORY_SEPARATOR . 'logs';
    if (!is_dir($logsDir)) {
        throw new RuntimeException('No logs directory found at docs/ai/generated/logs');
    }

    $target = $args[0] ?? null;
    if ($target === null || $target === '') {
        $entries = array_values(array_filter(scandir($logsDir) ?: [], static fn(string $e): bool => $e !== '.' && $e !== '..'));
        sort($entries);
        $data = [
            'log_root' => 'docs/ai/generated/logs',
            'entries' => $entries,
            'count' => count($entries),
        ];
        $written = aiCliWriteArtifact($root, 'logs', 'php tools/ai/ai.php logs', $data, 'ok', null, 'Use logs <entry-or-file> to inspect details.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 0;
    }

    $candidate = $logsDir . DIRECTORY_SEPARATOR . $target;
    if (!file_exists($candidate)) {
        throw new RuntimeException('Log target not found: ' . $target);
    }

    if (is_dir($candidate)) {
        $files = array_values(array_filter(scandir($candidate) ?: [], static fn(string $e): bool => $e !== '.' && $e !== '..'));
        sort($files);
        $data = [
            'target' => 'docs/ai/generated/logs/' . $target,
            'files' => $files,
        ];
    } else {
        $content = (string) file_get_contents($candidate);
        $data = [
            'target' => 'docs/ai/generated/logs/' . $target,
            'bytes' => strlen($content),
            'preview' => substr($content, 0, 4000),
        ];
    }

    $written = aiCliWriteArtifact($root, 'logs', 'php tools/ai/ai.php logs ' . $target, $data, 'ok', null, 'Inspect verify digest and resolve first failing check.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunEnvCheck(string $root): int
{
    $required = ['bash', 'git', 'php', 'rg'];
    $contextRequired = ['repomix', 'scc', 'jq'];
    $optional = ['just', 'yq', 'shellcheck', 'shfmt', 'actionlint', 'lychee', 'gitleaks'];

    $check = static function (string $bin): array {
        $path = '';
        if (stripos(PHP_OS_FAMILY, 'Windows') !== false) {
            $out = [];
            $exit = 0;
            exec('where.exe ' . escapeshellarg($bin) . ' 2>NUL', $out, $exit);
            if ($exit === 0 && $out !== []) {
                $path = trim((string) $out[0]);
            }
        } else {
            $path = trim((string) shell_exec('command -v ' . escapeshellarg($bin) . ' 2>/dev/null'));
        }

        return ['tool' => $bin, 'found' => $path !== '', 'path' => $path === '' ? null : $path];
    };

    $req = array_map($check, $required);
    $ctx = array_map($check, $contextRequired);
    $opt = array_map($check, $optional);

    $missingRequired = array_values(array_filter($req, static fn(array $r): bool => $r['found'] === false));
    $status = $missingRequired === [] ? 'ok' : 'warning';
    $next = $missingRequired === [] ? 'Environment is ready for core AI workflow commands.' : 'Install missing required tools before running full workflow.';

    $data = [
        'required' => $req,
        'context_required' => $ctx,
        'optional' => $opt,
        'missing_required' => array_map(static fn(array $r): string => $r['tool'], $missingRequired),
    ];

    $written = aiCliWriteArtifact($root, 'env-check', 'php tools/ai/ai.php env-check', $data, $status, null, $next);
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunFileContext(string $root, array $args): int
{
    $target = $args[0] ?? '';
    if ($target === '') {
        throw new RuntimeException('file-context requires a target path argument');
    }
    $path = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $target);
    if (!is_file($path)) {
        throw new RuntimeException('file-context target not found: ' . $target);
    }

    $content = (string) file_get_contents($path);
    $lines = substr_count($content, "\n") + 1;
    $bytes = strlen($content);

    $related = [];
    exec('git -C ' . escapeshellarg($root) . ' grep -n ' . escapeshellarg(basename($target)) . ' -- 2>NUL', $related);
    $related = array_slice($related, 0, 30);

    $data = [
        'target' => $target,
        'bytes' => $bytes,
        'lines' => $lines,
        'estimated_tokens' => aiCliEstimateTokens($content),
        'related_references_preview' => $related,
        'content_preview' => substr($content, 0, 4000),
    ];

    $written = aiCliWriteArtifact($root, 'file-context', 'php tools/ai/ai.php file-context ' . $target, $data, 'ok', null, 'Read this file first, then open top related references if needed.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunOrphans(string $root): int
{
    $candidates = [];
    exec('git -C ' . escapeshellarg($root) . ' ls-files "scripts/*.sh" "scripts/copilot/*.sh" "tools/ai/*" "docs/ai/*.md"', $candidates);

    $possiblyOrphan = [];
    foreach ($candidates as $path) {
        if (str_starts_with($path, 'docs/ai/generated/')) {
            continue;
        }
        $refs = [];
        exec('git -C ' . escapeshellarg($root) . ' grep -n ' . escapeshellarg($path) . ' -- "README.md" "justfile" "docs" "scripts" "tools" ".github" 2>NUL', $refs);
        $refs = array_values(array_filter($refs, static fn(string $line): bool => !str_contains($line, $path . ':')));
        if ($refs === []) {
            $possiblyOrphan[] = [
                'path' => $path,
                'reason' => 'no references found in key surfaces',
                'confidence' => 70,
            ];
        }
    }

    $status = $possiblyOrphan === [] ? 'ok' : 'warning';
    $data = [
        'orphan_score' => count($possiblyOrphan),
        'findings' => $possiblyOrphan,
    ];

    $written = aiCliWriteArtifact($root, 'orphans', 'php tools/ai/ai.php orphans', $data, $status, null, 'Review orphan candidates before deletion or context inclusion changes.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunAutoFix(string $root, array $args): int
{
    $dryRun = in_array('--dry-run', $args, true);
    if (!$dryRun) {
        throw new RuntimeException('auto-fix currently supports only --dry-run');
    }

    $actions = [];
    $status = aiRunCommand($root, 'php tools/ai/generate-ai-catalog.php --check');
    if ($status['exit'] !== 0) {
        $actions[] = [
            'type' => 'generated-output',
            'action' => 'php tools/ai/generate-ai-catalog.php',
            'reason' => 'catalog drift detected',
            'safe' => true,
        ];
    }

    $status2 = aiRunCommand($root, 'php tools/ai/generate-repo-structure.php --check --with-scc');
    if ($status2['exit'] !== 0) {
        $actions[] = [
            'type' => 'generated-output',
            'action' => 'php tools/ai/generate-repo-structure.php --with-scc',
            'reason' => 'repo-structure drift detected',
            'safe' => true,
        ];
    }

    $data = [
        'mode' => 'dry-run',
        'safe_fixes' => $actions,
        'unsafe_fixes_skipped' => [
            [
                'type' => 'logic-change',
                'reason' => 'auto-fix does not modify production/workflow logic in this phase',
            ],
        ],
    ];

    $written = aiCliWriteArtifact($root, 'auto-fix', 'php tools/ai/ai.php auto-fix --dry-run', $data, 'ok', null, 'Apply listed safe regeneration commands manually, then run rebase-state.');
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

function aiRunWorkflow(string $root): int
{
    $graphPath = $root . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'workflow-graph.json';
    if (!is_file($graphPath)) {
        throw new RuntimeException('Missing docs/ai/workflow-graph.json');
    }

    $decoded = json_decode((string) file_get_contents($graphPath), true);
    if (!is_array($decoded)) {
        throw new RuntimeException('Invalid JSON in docs/ai/workflow-graph.json');
    }

    $commands = $decoded['commands'] ?? [];
    $count = is_array($commands) ? count($commands) : 0;
    $data = [
        'workflow_graph' => 'docs/ai/workflow-graph.json',
        'command_count' => $count,
        'commands' => $commands,
    ];

    $written = aiCliWriteArtifact($root, 'workflow', 'php tools/ai/ai.php workflow', $data, 'ok', null, 'Use workflow dependencies to choose the next required command.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

function aiRunSnapshot(string $root): int
{
    $statusOut = [];
    $exit = 0;
    exec('git -C ' . escapeshellarg($root) . ' status --short', $statusOut, $exit);
    $dirty = $exit === 0 && $statusOut !== [];

    $data = [
        'branch' => aiCliCurrentBranch($root),
        'commit' => aiCliCurrentCommit($root),
        'dirty' => $dirty,
        'changed_files_count' => count($statusOut),
        'changed_files' => $statusOut,
    ];

    $written = aiCliWriteArtifact($root, 'project-snapshot', 'php tools/ai/ai.php snapshot', $data, 'ok', null, 'Run freshness, budget, then next.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

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

    if ($hasManifest && !$reinstall) {
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
            mkdir($backupRoot, 0777, true);
        }
        $backupId = 'install-' . gmdate('Ymd-His');
        $dir = $backupRoot . DIRECTORY_SEPARATOR . $backupId;
        mkdir($dir, 0777, true);

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
                mkdir($filesDir, 0777, true);
            }
            foreach ($targets as $rel) {
                $abs = $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, rtrim($rel, '/'));
                $snapshot = $filesDir . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, rtrim($rel, '/'));
                if (is_file($abs)) {
                    $parent = dirname($snapshot);
                    if (!is_dir($parent)) {
                        mkdir($parent, 0777, true);
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
    if ($backupId === '') {
        $data = [
            'status' => 'blocked',
            'mode' => $mode,
            'runtime_mode' => $runtimeMode,
            'reason' => 'apply requires explicit backup id',
            'next_action' => 'php tools/ai/ai.php install --backup-only --apply --mode ' . $mode,
        ];
        $written = aiCliWriteArtifact($root, 'install', 'php tools/ai/ai.php install --apply', $data, 'blocked', null, 'Create backup first, then rerun apply with --backup <backup-id>.');
        fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
        return 1;
    }
    $backupManifestPath = $root . DIRECTORY_SEPARATOR . '.ai-backups' . DIRECTORY_SEPARATOR . $backupId . DIRECTORY_SEPARATOR . 'manifest.json';
    if (!is_file($backupManifestPath)) {
        throw new RuntimeException('backup manifest not found for apply backup id: ' . $backupId);
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
            mkdir($derivedDir, 0777, true);
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

function aiPromptLine(string $prompt): string
{
    fwrite(STDOUT, $prompt);
    $line = fgets(STDIN);
    return $line === false ? '' : trim($line);
}

function aiPromptYesNo(string $prompt, bool $defaultNo = true): bool
{
    $suffix = $defaultNo ? ' [y/N]: ' : ' [Y/n]: ';
    $value = strtolower(aiPromptLine($prompt . $suffix));
    if ($value === '') {
        return !$defaultNo;
    }
    return in_array($value, ['y', 'yes'], true);
}

function aiLatestBackupId(string $root): ?string
{
    $dir = $root . DIRECTORY_SEPARATOR . '.ai-backups';
    if (!is_dir($dir)) {
        return null;
    }
    $entries = array_values(array_filter(scandir($dir) ?: [], static fn(string $e): bool => $e !== '.' && $e !== '..'));
    if ($entries === []) {
        return null;
    }
    rsort($entries, SORT_STRING);
    return $entries[0];
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
                    mkdir($dest, 0777, true);
                }
                continue;
            }
            $parent = dirname($dest);
            if (!is_dir($parent)) {
                mkdir($parent, 0777, true);
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

function aiDetectRuntimeMode(array $args): string
{
    if (in_array('--agent', $args, true)) {
        return 'AI_AGENT';
    }
    if (in_array('--ci', $args, true)) {
        return 'CI';
    }
    if (in_array('--interactive', $args, true)) {
        return 'HUMAN_TTY';
    }

    $ci = (string) getenv('CI');
    $gh = (string) getenv('GITHUB_ACTIONS');
    if (strtolower($ci) === 'true' || strtolower($gh) === 'true') {
        return 'CI';
    }

    $envKeys = array_keys($_ENV + $_SERVER);
    foreach ($envKeys as $key) {
        if (str_starts_with((string) $key, 'OPENCODE_') || str_starts_with((string) $key, 'CLAUDE_') || str_starts_with((string) $key, 'COPILOT_')) {
            return 'AI_AGENT';
        }
    }

    if (function_exists('stream_isatty') && stream_isatty(STDIN)) {
        return 'HUMAN_TTY';
    }
    return 'CI';
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

function aiArgsAfterDoubleDash(array $args): array
{
    $idx = array_search('--', $args, true);
    if ($idx === false) {
        return [];
    }
    return array_slice($args, $idx + 1);
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

function aiRunAdvisor(string $root, array $args): int
{
    $flags = [
        'scan' => in_array('--scan', $args, true),
        'score' => in_array('--score', $args, true),
        'validate' => in_array('--validate', $args, true),
        'secret-scan' => in_array('--secret-scan', $args, true),
        'pack' => in_array('--pack', $args, true),
        'token-budget' => in_array('--token-budget', $args, true),
        'prompt' => in_array('--prompt', $args, true),
        'baseline' => in_array('--baseline', $args, true),
        'diff' => in_array('--diff', $args, true),
        'submit' => in_array('--submit', $args, true),
        'check' => in_array('--check', $args, true),
        'all' => in_array('--all', $args, true),
    ];

    if (!in_array(true, $flags, true)) {
        $flags['all'] = true;
    }

    $dir = aiAdvisorGeneratedDir($root);
    $events = [];

    if ($flags['all'] || $flags['scan']) {
        $signals = aiAdvisorScan($root);
        $events[] = ['step' => 'scan', 'tracked_files_count' => $signals['tracked_files_count'] ?? 0];
    }

    if ($flags['all'] || $flags['validate']) {
        $signals = aiAdvisorReadJson($dir . DIRECTORY_SEPARATOR . 'project-signals.json');
        $errors = aiAdvisorValidateSignals($signals);
        if ($errors !== []) {
            throw new RuntimeException('advisor validate failed: ' . implode('; ', $errors));
        }
        if (is_file($dir . DIRECTORY_SEPARATOR . 'project-scorecard.json')) {
            $score = aiAdvisorReadJson($dir . DIRECTORY_SEPARATOR . 'project-scorecard.json');
            $errors2 = aiAdvisorValidateScorecard($score);
            if ($errors2 !== []) {
                throw new RuntimeException('advisor scorecard validate failed: ' . implode('; ', $errors2));
            }
        }
        $events[] = ['step' => 'validate', 'status' => 'ok'];
    }

    if ($flags['all'] || $flags['score']) {
        $signals = aiAdvisorReadJson($dir . DIRECTORY_SEPARATOR . 'project-signals.json');
        $score = aiAdvisorScore($root, $signals);
        $events[] = ['step' => 'score', 'overall' => $score['overall'] ?? 0];
    }

    if ($flags['all'] || $flags['secret-scan']) {
        $secret = aiAdvisorSecretScan($root);
        $events[] = ['step' => 'secret-scan', 'blocked' => $secret['blocked'] ?? false, 'findings' => $secret['count'] ?? 0];
        if (!empty($secret['blocked'])) {
            $data = ['status' => 'blocked', 'reason' => 'potential secrets detected', 'events' => $events, 'findings_file' => 'docs/ai/generated/advisor-secret-findings.json'];
            $written = aiCliWriteArtifact($root, 'advisor', 'php tools/ai/ai.php advisor', $data, 'blocked', null, 'Resolve secret findings before advisor pack/submit.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
    }

    if ($flags['all'] || $flags['pack']) {
        $pack = aiAdvisorPackContext($root);
        $events[] = ['step' => 'pack', 'file_count' => count($pack['files'] ?? [])];
    }

    if ($flags['all'] || $flags['token-budget']) {
        $budget = aiAdvisorTokenBudget($root);
        $events[] = ['step' => 'token-budget', 'tokens_estimate' => $budget['tokens_estimate'] ?? 0, 'mode' => $budget['mode'] ?? 'unknown'];
    }

    if ($flags['all'] || $flags['prompt']) {
        aiAdvisorBuildPrompt($root);
        $events[] = ['step' => 'prompt', 'status' => 'ok'];
    }

    if ($flags['baseline']) {
        $baseline = aiAdvisorWriteBaseline($root);
        $events[] = ['step' => 'baseline', 'overall' => $baseline['overall'] ?? 0];
    }

    if ($flags['diff']) {
        $diff = aiAdvisorDiffBaseline($root);
        $events[] = ['step' => 'diff', 'baseline_overall' => $diff['baseline_overall'] ?? 0, 'current_overall' => $diff['current_overall'] ?? 0];
    }

    if ($flags['submit']) {
        $provider = aiParseArg($args, 'provider') ?? 'dry-run';
        if ($provider !== 'dry-run') {
            throw new RuntimeException('advisor submit supports only --provider=dry-run in v1');
        }
        $submit = aiAdvisorSubmitDryRun($root);
        $events[] = ['step' => 'submit', 'provider' => $submit['provider'] ?? 'dry-run', 'network_called' => $submit['network_called'] ?? false];
    }

    if ($flags['check']) {
        $required = [
            $dir . DIRECTORY_SEPARATOR . 'project-signals.json',
            $dir . DIRECTORY_SEPARATOR . 'project-scorecard.json',
            $dir . DIRECTORY_SEPARATOR . 'advisor-secret-findings.json',
        ];

        $secretBlocked = false;
        $secretPath = $dir . DIRECTORY_SEPARATOR . 'advisor-secret-findings.json';
        if (is_file($secretPath)) {
            $secretData = aiAdvisorReadJson($secretPath);
            $secretBlocked = !empty($secretData['blocked']);
        }
        if (!$secretBlocked) {
            $required[] = $dir . DIRECTORY_SEPARATOR . 'advisor-token-budget.json';
            $required[] = $dir . DIRECTORY_SEPARATOR . 'advisor-context.md';
            $required[] = $dir . DIRECTORY_SEPARATOR . 'advisor-prompt.md';
        }

        $missing = [];
        foreach ($required as $path) {
            if (!is_file($path)) {
                $missing[] = aiCliToRelative($root, $path);
            }
        }
        if ($missing !== []) {
            $data = ['status' => 'failed', 'mode' => 'check', 'missing' => $missing, 'events' => $events];
            $written = aiCliWriteArtifact($root, 'advisor', 'php tools/ai/ai.php advisor --check', $data, 'failed', null, 'Run advisor --all to generate missing artifacts.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }
        $signals = aiAdvisorReadJson($dir . DIRECTORY_SEPARATOR . 'project-signals.json');
        $score = aiAdvisorReadJson($dir . DIRECTORY_SEPARATOR . 'project-scorecard.json');
        $errors = array_merge(aiAdvisorValidateSignals($signals), aiAdvisorValidateScorecard($score));
        if ($errors !== []) {
            $data = ['status' => 'failed', 'mode' => 'check', 'errors' => $errors, 'events' => $events];
            $written = aiCliWriteArtifact($root, 'advisor', 'php tools/ai/ai.php advisor --check', $data, 'failed', null, 'Fix invalid advisor JSON shapes.');
            fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
            return 1;
        }

        if ($secretBlocked) {
            $events[] = ['step' => 'check', 'secret_blocked' => true, 'note' => 'pack/prompt outputs optional while blocked'];
        }
    }

    $data = [
        'status' => 'ok',
        'events' => $events,
        'outputs' => [
            'project_signals' => 'docs/ai/generated/project-signals.json',
            'project_scorecard' => 'docs/ai/generated/project-scorecard.json',
            'secret_findings' => 'docs/ai/generated/advisor-secret-findings.json',
            'token_budget' => 'docs/ai/generated/advisor-token-budget.json',
            'context' => 'docs/ai/generated/advisor-context.md',
            'prompt' => 'docs/ai/generated/advisor-prompt.md',
            'baseline' => 'docs/ai/generated/advisor-baseline.json',
            'drift' => 'docs/ai/generated/advisor-drift.md',
            'submit_dry_run' => 'docs/ai/generated/advisor-submit-dry-run.json',
        ],
    ];
    $written = aiCliWriteArtifact($root, 'advisor', 'php tools/ai/ai.php advisor', $data, 'ok', null, 'Run advisor --check to enforce deterministic advisor outputs.');
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return 0;
}

try {
    $root = aiCliRepoRoot();
    $argv = $_SERVER['argv'] ?? [];
    $command = $argv[1] ?? 'help';
    $args = array_slice($argv, 2);

    switch ($command) {
        case 'help':
        case '--help':
        case '-h':
            aiUsage();
            exit(0);
        case 'list':
            exit(aiRunList($root));
        case 'freshness':
            exit(aiRunFreshness($root));
        case 'budget':
            exit(aiRunBudget($root, $args));
        case 'workflow':
            exit(aiRunWorkflow($root));
        case 'snapshot':
            exit(aiRunSnapshot($root));
        case 'diff-summary':
            exit(aiRunDiffSummary($root, $args));
        case 'risk':
            exit(aiRunRisk($root, $args));
        case 'verify':
            exit(aiRunVerify($root, $args));
        case 'next':
            exit(aiRunNext($root));
        case 'rebase-state':
            exit(aiRunRebaseState($root));
        case 'decision':
            exit(aiRunDecision($root, $args));
        case 'why':
            exit(aiRunWhy($root, $args));
        case 'session-resume':
            exit(aiRunSessionResume($root));
        case 'commit-msg':
            exit(aiRunCommitMsg($root));
        case 'pr-summary':
            exit(aiRunPrSummary($root));
        case 'logs':
            exit(aiRunLogs($root, $args));
        case 'env-check':
            exit(aiRunEnvCheck($root));
        case 'file-context':
            exit(aiRunFileContext($root, $args));
        case 'orphans':
            exit(aiRunOrphans($root));
        case 'auto-fix':
            exit(aiRunAutoFix($root, $args));
        case 'impact':
            exit(aiRunImpact($root, $args));
        case 'ask':
            exit(aiRunAsk($root, $args));
        case 'estimate':
            exit(aiRunEstimate($root, $args));
        case 'conflicts':
            exit(aiRunConflicts($root));
        case 'find':
            exit(aiRunFind($root, $args));
        case 'symbols':
            exit(aiRunSymbols($root, $args));
        case 'preflight':
            exit(aiRunPreflight($root));
        case 'package-lock':
            exit(aiRunPackageLock($root, $args));
        case 'package-verify':
            exit(aiRunPackageVerify($root));
        case 'audit-instructions':
            exit(aiRunAuditInstructions($root));
        case 'adapter-plan':
            exit(aiRunAdapterPlan($root, $args));
        case 'plan':
            exit(aiRunAdapterPlan($root, $args));
        case 'install':
            exit(aiRunInstallWorkflow($root, $args));
        case 'upgrade':
            exit(aiRunUpgradeWorkflow($root, $args));
        case 'adapter-validate':
            exit(aiRunAdapterValidate($root));
        case 'rollback':
            exit(aiRunRollbackWorkflow($root, $args));
        case 'packs':
            exit(aiRunPacks($root, $args));
        case 'placeholders':
            exit(aiRunPlaceholders($root, $args));
        case 'hooks':
            exit(aiRunHooks($root, $args));
        case 'toolchain':
            exit(aiRunToolchain($root, $args));
        case 'run-script':
            exit(aiRunScriptCommand($root, $args));
        case 'install-docs':
            exit(aiRunInstallDocs($root, $args));
        case 'advisor':
            exit(aiRunAdvisor($root, $args));
        case 'version':
            exit(aiRunVersion($root));
        default:
            fwrite(STDERR, "Error: unknown command '{$command}'" . PHP_EOL . PHP_EOL);
            aiUsage();
            exit(1);
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'Error: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
