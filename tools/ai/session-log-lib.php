<?php

declare(strict_types=1);

function aiSessionRepoRoot(?string $root = null): string
{
    $candidate = $root ?? getenv('AI_SESSION_REPO_ROOT') ?: realpath(__DIR__ . '/../..');
    if ($candidate === false || $candidate === null || $candidate === '') {
        throw new RuntimeException('repository root not found');
    }

    $resolved = realpath((string) $candidate) ?: (string) $candidate;
    if (!is_dir($resolved)) {
        throw new RuntimeException("repository root is not a directory: {$resolved}");
    }

    return rtrim($resolved, DIRECTORY_SEPARATOR);
}

function aiSessionId(?string $sessionId = null): string
{
    $id = $sessionId ?: getenv('SESSION_ID') ?: 'session-' . gmdate('Ymd-His');
    $id = preg_replace('/[^A-Za-z0-9._-]+/', '-', (string) $id) ?: 'session';
    return trim($id, '-_.') !== '' ? trim($id, '-_.') : 'session';
}

function aiSessionDir(string $root, string $sessionId): string
{
    return $root . DIRECTORY_SEPARATOR . 'docs' . DIRECTORY_SEPARATOR . 'ai' . DIRECTORY_SEPARATOR . 'generated'
        . DIRECTORY_SEPARATOR . 'sessions' . DIRECTORY_SEPARATOR . aiSessionId($sessionId);
}

function aiSessionEnsure(string $root, string $sessionId): string
{
    $dir = aiSessionDir($root, $sessionId);
    if (!is_dir($dir) && !mkdir($dir, 0775, true) && !is_dir($dir)) {
        throw new RuntimeException("failed to create session directory: {$dir}");
    }

    $events = $dir . DIRECTORY_SEPARATOR . 'events.jsonl';
    if (!is_file($events)) {
        file_put_contents($events, '');
    }

    $summary = $dir . DIRECTORY_SEPARATOR . 'summary.md';
    if (!is_file($summary)) {
        file_put_contents($summary, "# AI Session " . aiSessionId($sessionId) . "\n\n## Status\n\nStarted.\n");
    }

    return $dir;
}

/** @return array<string,mixed> */
function aiSessionEvent(array $overrides = []): array
{
    $type = (string) ($overrides['event_type'] ?? $overrides['type'] ?? 'event');
    $sessionId = aiSessionId((string) ($overrides['session_id'] ?? getenv('SESSION_ID') ?: 'session-' . gmdate('Ymd-His')));

    $event = [
        'event_version' => '1.0',
        'event_type' => $type,
        'trace_id' => (string) ($overrides['trace_id'] ?? getenv('TRACE_ID') ?: 'trc-' . $sessionId),
        'session_id' => $sessionId,
        'task_id' => (string) ($overrides['task_id'] ?? getenv('TASK_ID') ?: 'tsk-' . $sessionId),
        'timestamp' => (string) ($overrides['timestamp'] ?? gmdate('Y-m-d\TH:i:s\Z')),
        'actor' => [
            'type' => (string) ($overrides['actor_type'] ?? 'agent'),
            'id' => (string) ($overrides['actor_id'] ?? getenv('ACTOR_ID') ?: 'ai-agent'),
            'delegated_by' => $overrides['delegated_by'] ?? (getenv('DELEGATED_BY') ?: null),
        ],
        'tool' => [
            'name' => (string) ($overrides['tool_name'] ?? 'manual'),
            'category' => $overrides['tool_category'] ?? null,
            'args_hash' => $overrides['args_hash'] ?? null,
            'mutates_state' => (bool) ($overrides['mutates_state'] ?? false),
        ],
        'authorization' => [
            'policy_version' => $overrides['policy_version'] ?? null,
            'decision' => (string) ($overrides['authorization_decision'] ?? 'unknown'),
            'approval_required' => $overrides['approval_required'] ?? null,
            'approved_by' => $overrides['approved_by'] ?? null,
            'reason' => $overrides['authorization_reason'] ?? null,
        ],
        'execution' => [
            'status' => (string) ($overrides['execution_status'] ?? 'unknown'),
            'latency_ms' => $overrides['latency_ms'] ?? null,
            'retry_count' => $overrides['retry_count'] ?? 0,
            'exit_code' => $overrides['exit_code'] ?? null,
            'output_truncated' => $overrides['output_truncated'] ?? null,
        ],
        'repository' => [
            'root' => $overrides['repository_root'] ?? null,
            'git_branch' => $overrides['git_branch'] ?? null,
            'git_commit' => $overrides['git_commit'] ?? null,
        ],
        'output' => [
            'preview' => $overrides['output_preview'] ?? null,
        ],
        'details' => $overrides['details'] ?? [],
    ];

    return aiSessionRedact($event);
}

/** @param mixed $value @return mixed */
function aiSessionRedact($value, ?string $key = null)
{
    if ($key !== null && preg_match('/(token|secret|password|credential|api[_-]?key|raw[_-]?prompt|private[_-]?prompt|prompt)/i', $key) === 1) {
        return '[REDACTED]';
    }

    if (is_array($value)) {
        $redacted = [];
        foreach ($value as $k => $v) {
            $redacted[$k] = aiSessionRedact($v, is_string($k) ? $k : null);
        }
        return $redacted;
    }

    if (is_string($value) && preg_match('/(raw[-_ ]?prompt|private[-_ ]?prompt|Bearer\s+[A-Za-z0-9._~+\/-]+=*|[A-Za-z0-9._%+-]+:[A-Za-z0-9._%+-]+@|(^|[\s"\'])(--?(api[-_]?key|token|secret|password)|[A-Z0-9_]*(TOKEN|SECRET|PASSWORD|API_KEY))\s*[=:]\s*[^\s"\']+|\b(sk-[A-Za-z0-9_-]{8,}|ghp_[A-Za-z0-9_]{8,}|github_pat_[A-Za-z0-9_]{8,}|glpat-[A-Za-z0-9_-]{8,}|xox[baprs]-[A-Za-z0-9-]{8,}|AKIA[0-9A-Z]{16})\b)/i', $value) === 1) {
        return '[REDACTED]';
    }

    return $value;
}

function aiSessionAppendEvent(string $root, string $sessionId, array $event): string
{
    $dir = aiSessionEnsure($root, $sessionId);
    $event = aiSessionRedact($event);
    aiSessionValidateEvent($event);
    $line = json_encode($event, JSON_UNESCAPED_SLASHES);
    if ($line === false) {
        throw new RuntimeException('failed to encode session event');
    }
    file_put_contents($dir . DIRECTORY_SEPARATOR . 'events.jsonl', $line . PHP_EOL, FILE_APPEND | LOCK_EX);
    return $dir;
}

function aiSessionWriteSummary(string $root, string $sessionId, string $status, string $nextStep = '', array $remaining = []): void
{
    $dir = aiSessionEnsure($root, $sessionId);
    $status = (string) aiSessionRedact($status);
    $nextStep = (string) aiSessionRedact($nextStep);
    $remaining = array_map(static fn ($item): string => (string) aiSessionRedact((string) $item), $remaining);
    $content = '# AI Session ' . aiSessionId($sessionId) . "\n\n";
    $content .= "## Status\n\n{$status}\n\n";
    $content .= "## Remaining\n\n" . ($remaining === [] ? "- unknown\n" : '- ' . implode("\n- ", $remaining) . "\n");
    $content .= "\n## Next Step\n\n" . ($nextStep !== '' ? $nextStep : 'unknown') . "\n";
    file_put_contents($dir . DIRECTORY_SEPARATOR . 'summary.md', $content);
}

function aiSessionValidateEvent(array $event): void
{
    foreach (['event_version', 'event_type', 'trace_id', 'session_id', 'task_id', 'timestamp', 'actor', 'tool', 'authorization', 'execution'] as $field) {
        if (!array_key_exists($field, $event)) {
            throw new RuntimeException("session event missing {$field}");
        }
    }
    foreach (['event_version', 'event_type', 'trace_id', 'session_id', 'task_id', 'timestamp'] as $field) {
        if (!is_string($event[$field]) || $event[$field] === '') {
            throw new RuntimeException("session event {$field} must be a non-empty string");
        }
    }
    if (strtotime($event['timestamp']) === false) {
        throw new RuntimeException('session event timestamp must be date-time');
    }
    if (!is_array($event['actor']) || !isset($event['actor']['type'], $event['actor']['id'])) {
        throw new RuntimeException('session event actor is incomplete');
    }
    aiSessionRejectExtraKeys($event['actor'], ['type', 'id', 'delegated_by'], 'actor');
    if (!in_array($event['actor']['type'], ['human', 'agent', 'service'], true)) {
        throw new RuntimeException('session event actor.type is invalid');
    }
    if (!is_string($event['actor']['id']) || $event['actor']['id'] === '') {
        throw new RuntimeException('session event actor.id must be a non-empty string');
    }
    if (isset($event['actor']['delegated_by']) && !is_string($event['actor']['delegated_by']) && $event['actor']['delegated_by'] !== null) {
        throw new RuntimeException('session event actor.delegated_by must be string or null');
    }
    if (!is_array($event['tool']) || !isset($event['tool']['name'], $event['tool']['mutates_state'])) {
        throw new RuntimeException('session event tool is incomplete');
    }
    aiSessionRejectExtraKeys($event['tool'], ['name', 'category', 'args_hash', 'mutates_state'], 'tool');
    if (!is_string($event['tool']['name']) || $event['tool']['name'] === '') {
        throw new RuntimeException('session event tool.name must be a non-empty string');
    }
    foreach (['category', 'args_hash'] as $field) {
        if (isset($event['tool'][$field]) && !is_string($event['tool'][$field]) && $event['tool'][$field] !== null) {
            throw new RuntimeException("session event tool.{$field} must be string or null");
        }
    }
    if (!is_bool($event['tool']['mutates_state'])) {
        throw new RuntimeException('session event tool.mutates_state must be boolean');
    }
    if (!is_array($event['authorization']) || !isset($event['authorization']['decision'])) {
        throw new RuntimeException('session event authorization is incomplete');
    }
    aiSessionRejectExtraKeys($event['authorization'], ['policy_version', 'decision', 'approval_required', 'approved_by', 'reason'], 'authorization');
    if (!in_array($event['authorization']['decision'], ['allowed', 'denied', 'ask', 'unknown'], true)) {
        throw new RuntimeException('session event authorization.decision is invalid');
    }
    if (isset($event['authorization']['policy_version']) && !is_string($event['authorization']['policy_version']) && $event['authorization']['policy_version'] !== null) {
        throw new RuntimeException('session event authorization.policy_version must be string or null');
    }
    if (isset($event['authorization']['approval_required']) && !is_bool($event['authorization']['approval_required']) && $event['authorization']['approval_required'] !== null) {
        throw new RuntimeException('session event authorization.approval_required must be boolean or null');
    }
    foreach (['approved_by', 'reason'] as $field) {
        if (isset($event['authorization'][$field]) && !is_string($event['authorization'][$field]) && $event['authorization'][$field] !== null) {
            throw new RuntimeException("session event authorization.{$field} must be string or null");
        }
    }
    if (!is_array($event['execution']) || !isset($event['execution']['status'])) {
        throw new RuntimeException('session event execution is incomplete');
    }
    aiSessionRejectExtraKeys($event['execution'], ['status', 'latency_ms', 'retry_count', 'exit_code', 'output_truncated'], 'execution');
    if (!in_array($event['execution']['status'], ['success', 'error', 'timeout', 'blocked', 'unknown'], true)) {
        throw new RuntimeException('session event execution.status is invalid');
    }
    foreach (['latency_ms', 'retry_count'] as $field) {
        if (isset($event['execution'][$field]) && (!is_int($event['execution'][$field]) || $event['execution'][$field] < 0) && $event['execution'][$field] !== null) {
            throw new RuntimeException("session event execution.{$field} must be a non-negative integer or null");
        }
    }
    if (isset($event['execution']['exit_code']) && !is_int($event['execution']['exit_code']) && $event['execution']['exit_code'] !== null) {
        throw new RuntimeException('session event execution.exit_code must be integer or null');
    }
    if (isset($event['execution']['output_truncated']) && !is_bool($event['execution']['output_truncated']) && $event['execution']['output_truncated'] !== null) {
        throw new RuntimeException('session event execution.output_truncated must be boolean or null');
    }
    if (aiSessionContainsSensitiveValue($event)) {
        throw new RuntimeException('session event contains unredacted sensitive-looking value');
    }
}

function aiSessionRejectExtraKeys(array $value, array $allowed, string $path): void
{
    foreach (array_keys($value) as $key) {
        if (!in_array($key, $allowed, true)) {
            throw new RuntimeException("session event {$path} has unsupported property {$key}");
        }
    }
}

/** @param mixed $value */
function aiSessionContainsSensitiveValue($value, ?string $key = null): bool
{
    if ($key !== null && preg_match('/(token|secret|password|credential|api[_-]?key|raw[_-]?prompt|private[_-]?prompt|prompt)/i', $key) === 1 && $value !== '[REDACTED]' && $value !== null) {
        return true;
    }
    if (is_array($value)) {
        foreach ($value as $k => $v) {
            if (aiSessionContainsSensitiveValue($v, is_string($k) ? $k : null)) {
                return true;
            }
        }
        return false;
    }
    return is_string($value) && preg_match('/(raw[-_ ]?prompt|private[-_ ]?prompt|Bearer\s+[A-Za-z0-9._~+\/-]+=*|(^|[\s"\'])(--?(api[-_]?key|token|secret|password)|[A-Z0-9_]*(TOKEN|SECRET|PASSWORD|API_KEY))\s*[=:]\s*[^\s"\']+|\b(sk-[A-Za-z0-9_-]{8,}|ghp_[A-Za-z0-9_]{8,}|github_pat_[A-Za-z0-9_]{8,}|glpat-[A-Za-z0-9_-]{8,}|xox[baprs]-[A-Za-z0-9-]{8,}|AKIA[0-9A-Z]{16})\b)/i', $value) === 1;
}

/** @return array{root:?string,session_id:?string,options:array<string,string|bool>,args:list<string>} */
function aiSessionParseArgs(array $argv): array
{
    $parsed = ['root' => null, 'session_id' => null, 'options' => [], 'args' => []];
    for ($i = 1; $i < count($argv); $i++) {
        $arg = (string) $argv[$i];
        if ($arg === '--root' && isset($argv[$i + 1])) {
            $parsed['root'] = (string) $argv[++$i];
        } elseif ($arg === '--session-id' && isset($argv[$i + 1])) {
            $parsed['session_id'] = (string) $argv[++$i];
        } elseif (str_starts_with($arg, '--') && isset($argv[$i + 1]) && !str_starts_with((string) $argv[$i + 1], '--')) {
            $parsed['options'][substr($arg, 2)] = (string) $argv[++$i];
        } elseif (str_starts_with($arg, '--')) {
            $parsed['options'][substr($arg, 2)] = true;
        } else {
            $parsed['args'][] = $arg;
        }
    }
    return $parsed;
}
