<?php

declare(strict_types=1);

require_once __DIR__ . '/ai_output_lib.php';

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

    $data = [
        'status' => $status,
        'check_count' => count($results),
        'failed_checks' => $failed,
        'results' => $results,
        'log_dir' => 'docs/ai/generated/logs/' . basename($logDir),
    ];

    $written = aiCliWriteArtifact($root, 'verify', 'php tools/ai/ai.php verify --changed', $data, $status, null, $recommended);
    fwrite(STDOUT, "OK: wrote {$written['json']} and {$written['markdown']}" . PHP_EOL);
    return $failed === [] ? 0 : 2;
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
        default:
            fwrite(STDERR, "Error: unknown command '{$command}'" . PHP_EOL . PHP_EOL);
            aiUsage();
            exit(1);
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'Error: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
