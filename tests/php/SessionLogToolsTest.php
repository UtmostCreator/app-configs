<?php

declare(strict_types=1);

namespace Tests;

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__, 2) . '/tools/ai/session-log-lib.php';

class SessionLogToolsTest extends TestCase
{
    private string $tmpDir;
    private string $repoRoot;

    protected function setUp(): void
    {
        $this->tmpDir = sys_get_temp_dir() . '/ai_session_log_test_' . uniqid('', true);
        mkdir($this->tmpDir, 0777, true);
        $root = realpath(dirname(__DIR__, 2));
        $this->assertIsString($root);
        $this->repoRoot = $root;
    }

    protected function tearDown(): void
    {
        $this->removeDir($this->tmpDir);
    }

    public function testSessionStartCreatesEventsAndSummary(): void
    {
        $result = $this->runTool(['tools/ai/session-start.php', '--root', $this->tmpDir, '--session-id', 'ses-test', '--task', 'test task']);

        $this->assertSame(0, $result['exit'], $result['stderr']);
        $sessionDir = $this->tmpDir . '/docs/ai/generated/sessions/ses-test';
        $this->assertFileExists($sessionDir . '/events.jsonl');
        $this->assertFileExists($sessionDir . '/summary.md');
        $this->assertStringContainsString('session.start', (string) file_get_contents($sessionDir . '/events.jsonl'));
    }

    public function testSessionStartRedactsSensitiveTaskInSummary(): void
    {
        $result = $this->runTool(['tools/ai/session-start.php', '--root', $this->tmpDir, '--session-id', 'ses-start-secret', '--task', 'private prompt text with --api-key sk-1234567890abcdef']);

        $this->assertSame(0, $result['exit'], $result['stderr']);
        $summary = (string) file_get_contents($this->tmpDir . '/docs/ai/generated/sessions/ses-start-secret/summary.md');
        $this->assertStringContainsString('[REDACTED]', $summary);
        $this->assertStringNotContainsString('private prompt text', $summary);
        $this->assertStringNotContainsString('sk-1234567890abcdef', $summary);
    }

    public function testAgentLogRedactsSensitiveDetails(): void
    {
        $details = json_encode(['api_token' => 'super-secret-token', 'note' => 'safe'], JSON_THROW_ON_ERROR);
        $result = $this->runTool(['tools/ai/agent-log.php', '--root', $this->tmpDir, '--session-id', 'ses-redact', '--type', 'decision', '--details-json', $details]);

        $this->assertSame(0, $result['exit'], $result['stderr']);
        $events = (string) file_get_contents($this->tmpDir . '/docs/ai/generated/sessions/ses-redact/events.jsonl');
        $this->assertStringContainsString('[REDACTED]', $events);
        $this->assertStringNotContainsString('super-secret-token', $events);
    }

    public function testValidateSessionLogRejectsMalformedJsonl(): void
    {
        $sessionDir = $this->tmpDir . '/docs/ai/generated/sessions/bad';
        mkdir($sessionDir, 0777, true);
        file_put_contents($sessionDir . '/summary.md', '# Bad');
        file_put_contents($sessionDir . '/events.jsonl', "not-json\n");

        $result = $this->runTool(['tools/ai/validate-session-log.php', '--root', $this->tmpDir, 'bad']);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString('invalid JSON', $result['stderr']);
    }

    public function testValidateSessionLogRejectsInvalidSchemaValues(): void
    {
        $sessionDir = $this->tmpDir . '/docs/ai/generated/sessions/bad-schema';
        mkdir($sessionDir, 0777, true);
        file_put_contents($sessionDir . '/summary.md', '# Bad Schema');
        $event = aiSessionEvent(['session_id' => 'bad-schema', 'event_type' => 'decision']);
        $event['tool']['mutates_state'] = 'yes';
        file_put_contents($sessionDir . '/events.jsonl', json_encode($event, JSON_UNESCAPED_SLASHES) . "\n");

        $result = $this->runTool(['tools/ai/validate-session-log.php', '--root', $this->tmpDir, 'bad-schema']);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString('mutates_state must be boolean', $result['stderr']);
    }

    public function testValidateSessionLogRejectsAdditionalNestedProperties(): void
    {
        $sessionDir = $this->tmpDir . '/docs/ai/generated/sessions/bad-extra';
        mkdir($sessionDir, 0777, true);
        file_put_contents($sessionDir . '/summary.md', '# Bad Extra');
        $event = aiSessionEvent(['session_id' => 'bad-extra', 'event_type' => 'decision']);
        $event['actor']['extra'] = 'not allowed';
        file_put_contents($sessionDir . '/events.jsonl', json_encode($event, JSON_UNESCAPED_SLASHES) . "\n");

        $result = $this->runTool(['tools/ai/validate-session-log.php', '--root', $this->tmpDir, 'bad-extra']);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString('unsupported property extra', $result['stderr']);
    }

    public function testEventJsonUsesSanitizedSessionIdAndRedactsPrompt(): void
    {
        $event = aiSessionEvent([
            'session_id' => '../unsafe/session',
            'event_type' => 'user.query',
            'details' => ['raw_prompt' => 'private prompt text'],
        ]);
        $result = $this->runTool(['tools/ai/agent-log.php', '--root', $this->tmpDir, '--session-id', '../unsafe/session', '--event-json', json_encode($event, JSON_THROW_ON_ERROR)]);

        $this->assertSame(0, $result['exit'], $result['stderr']);
        $this->assertFileExists($this->tmpDir . '/docs/ai/generated/sessions/unsafe-session/events.jsonl');
        $this->assertFileDoesNotExist($this->tmpDir . '/docs/ai/generated/unsafe/session/events.jsonl');
        $events = (string) file_get_contents($this->tmpDir . '/docs/ai/generated/sessions/unsafe-session/events.jsonl');
        $this->assertStringContainsString('[REDACTED]', $events);
        $this->assertStringNotContainsString('private prompt text', $events);
    }

    public function testEventJsonRedactsSecretsInsideCommandAndOutputStrings(): void
    {
        $event = aiSessionEvent([
            'session_id' => 'ses-command-secret',
            'event_type' => 'command.post',
            'output_preview' => 'token ghp_1234567890abcdef leaked',
            'details' => ['tool_args' => ['command' => 'deploy --api-key sk-1234567890abcdef']],
        ]);
        $result = $this->runTool(['tools/ai/agent-log.php', '--root', $this->tmpDir, '--session-id', 'ses-command-secret', '--event-json', json_encode($event, JSON_THROW_ON_ERROR)]);

        $this->assertSame(0, $result['exit'], $result['stderr']);
        $events = (string) file_get_contents($this->tmpDir . '/docs/ai/generated/sessions/ses-command-secret/events.jsonl');
        $this->assertStringContainsString('[REDACTED]', $events);
        $this->assertStringNotContainsString('sk-1234567890abcdef', $events);
        $this->assertStringNotContainsString('ghp_1234567890abcdef', $events);
    }

    public function testSessionEndWritesSummaryAndVerificationFiles(): void
    {
        $start = $this->runTool(['tools/ai/session-start.php', '--root', $this->tmpDir, '--session-id', 'ses-end']);
        $this->assertSame(0, $start['exit'], $start['stderr']);

        $end = $this->runTool(['tools/ai/session-end.php', '--root', $this->tmpDir, '--session-id', 'ses-end', '--status', 'partial', '--next-step', 'run tests', '--remaining', 'review,verify']);
        $this->assertSame(0, $end['exit'], $end['stderr']);

        $sessionDir = $this->tmpDir . '/docs/ai/generated/sessions/ses-end';
        $this->assertFileExists($sessionDir . '/verification.json');
        $this->assertFileExists($sessionDir . '/changed-files.json');
        $this->assertStringContainsString('run tests', (string) file_get_contents($sessionDir . '/summary.md'));

        $validate = $this->runTool(['tools/ai/validate-session-log.php', '--root', $this->tmpDir, 'ses-end']);
        $this->assertSame(0, $validate['exit'], $validate['stderr']);
    }

    public function testSessionEndRedactsSensitiveNextStepInSummary(): void
    {
        $start = $this->runTool(['tools/ai/session-start.php', '--root', $this->tmpDir, '--session-id', 'ses-end-secret']);
        $this->assertSame(0, $start['exit'], $start['stderr']);

        $end = $this->runTool(['tools/ai/session-end.php', '--root', $this->tmpDir, '--session-id', 'ses-end-secret', '--next-step', 'use TOKEN=super-secret-value']);
        $this->assertSame(0, $end['exit'], $end['stderr']);
        $summary = (string) file_get_contents($this->tmpDir . '/docs/ai/generated/sessions/ses-end-secret/summary.md');
        $this->assertStringContainsString('[REDACTED]', $summary);
        $this->assertStringNotContainsString('super-secret-value', $summary);
    }

    public function testSessionEndRedactsUnsafeStatusInVerificationJson(): void
    {
        $start = $this->runTool(['tools/ai/session-start.php', '--root', $this->tmpDir, '--session-id', 'ses-status-secret']);
        $this->assertSame(0, $start['exit'], $start['stderr']);

        $end = $this->runTool(['tools/ai/session-end.php', '--root', $this->tmpDir, '--session-id', 'ses-status-secret', '--status', 'TOKEN=super-secret-value']);
        $this->assertSame(0, $end['exit'], $end['stderr']);
        $verification = (string) file_get_contents($this->tmpDir . '/docs/ai/generated/sessions/ses-status-secret/verification.json');
        $this->assertStringContainsString('[REDACTED]', $verification);
        $this->assertStringNotContainsString('super-secret-value', $verification);
    }

    /** @return array{stdout:string,stderr:string,exit:int} */
    /** @param list<string> $command */
    private function runTool(array $command): array
    {
        $full = array_merge([(string) PHP_BINARY], $command);
        $process = proc_open($full, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, $this->repoRoot);
        $this->assertIsResource($process);
        fclose($pipes[0]);
        $stdout = (string) stream_get_contents($pipes[1]);
        $stderr = (string) stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        return ['stdout' => $stdout, 'stderr' => $stderr, 'exit' => proc_close($process)];
    }

    private function removeDir(string $dir): void
    {
        if (!is_dir($dir)) {
            return;
        }
        foreach (scandir($dir) ?: [] as $entry) {
            if ($entry === '.' || $entry === '..') {
                continue;
            }
            $path = $dir . DIRECTORY_SEPARATOR . $entry;
            is_dir($path) ? $this->removeDir($path) : unlink($path);
        }
        rmdir($dir);
    }
}
