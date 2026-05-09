<?php

declare(strict_types=1);

require_once __DIR__ . '/session-log-lib.php';

try {
    $args = aiSessionParseArgs($argv);
    $root = aiSessionRepoRoot($args['root']);
    $sessionId = aiSessionId($args['session_id']);
    $status = (string) ($args['options']['status'] ?? 'partial');
    $allowedStatuses = ['verified', 'partial', 'not-verified', 'failed-verification', 'failed'];
    if (!in_array($status, $allowedStatuses, true)) {
        $status = '[REDACTED]';
    }
    $nextStep = (string) ($args['options']['next-step'] ?? 'unknown');
    $remainingRaw = (string) ($args['options']['remaining'] ?? '');
    $remaining = $remainingRaw !== '' ? array_values(array_filter(array_map('trim', explode(',', $remainingRaw)))) : [];

    $event = aiSessionEvent([
        'event_type' => 'session.end',
        'session_id' => $sessionId,
        'tool_name' => 'session-end.php',
        'execution_status' => $status === 'failed' ? 'error' : 'success',
        'repository_root' => $root,
        'details' => ['status' => $status, 'remaining' => $remaining, 'next_step' => $nextStep],
    ]);
    $dir = aiSessionAppendEvent($root, $sessionId, $event);
    aiSessionWriteSummary($root, $sessionId, $status, $nextStep, $remaining);
    file_put_contents($dir . DIRECTORY_SEPARATOR . 'verification.json', json_encode(['status' => $status, 'updated_at' => gmdate('Y-m-d\TH:i:s\Z')], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);
    if (!is_file($dir . DIRECTORY_SEPARATOR . 'changed-files.json')) {
        file_put_contents($dir . DIRECTORY_SEPARATOR . 'changed-files.json', json_encode(['files' => []], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . PHP_EOL);
    }
    fwrite(STDOUT, "OK: session ended {$sessionId} at {$dir}\n");
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
