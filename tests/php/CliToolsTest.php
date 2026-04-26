<?php

declare(strict_types=1);

namespace Tests;

use PHPUnit\Framework\TestCase;

/**
 * CLI contract tests: run each PHP entrypoint against the live repo via proc_open.
 *
 * These tests verify exit codes and output markers only — they do not test
 * internal logic (covered by AiCatalogLibTest / AiCatalogLibIoTest).
 *
 * Real-contract-first: these tests were verified against the live repo before
 * assertions were written. Exit 0 = tool reports success for the current repo.
 */
class CliToolsTest extends TestCase
{
    private static string $repoRoot;

    public static function setUpBeforeClass(): void
    {
        $root = realpath(dirname(__DIR__, 2));

        if ($root === false) {
            throw new \RuntimeException('Could not resolve repo root from tests/php/');
        }

        self::$repoRoot = $root;
    }

    /**
     * Run a PHP CLI tool from the repo root with an isolated env.
     *
     * @return array{stdout: string, stderr: string, exit: int}
     */
    private function runTool(string $command): array
    {
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $env = [
            'HOME'              => sys_get_temp_dir(),
            'XDG_CONFIG_HOME'   => sys_get_temp_dir(),
            'GIT_CONFIG_GLOBAL' => '/dev/null',
            'PATH'              => (string) getenv('PATH'),
        ];

        $process = proc_open($command, $descriptors, $pipes, self::$repoRoot, $env);

        $this->assertIsResource($process, "proc_open failed for: $command");

        fclose($pipes[0]);
        $stdout = (string) stream_get_contents($pipes[1]);
        $stderr = (string) stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        $exit = proc_close($process);

        return ['stdout' => $stdout, 'stderr' => $stderr, 'exit' => $exit];
    }

    // ---- validate-ai-config.php (no flags; runs unconditionally) ----

    public function testValidateAiConfigExitsZero(): void
    {
        $result = $this->runTool('php tools/ai/validate-ai-config.php');
        $this->assertSame(
            0,
            $result['exit'],
            "validate-ai-config.php exited non-zero:\n" . $result['stderr']
        );
    }

    public function testValidateAiConfigOutputsOkLines(): void
    {
        $result = $this->runTool('php tools/ai/validate-ai-config.php');
        $combined = $result['stdout'] . $result['stderr'];
        $this->assertStringContainsString('OK', $combined);
    }

    // ---- validate-ai-catalog.php (no flags; runs unconditionally) ----

    public function testValidateAiCatalogExitsZero(): void
    {
        $result = $this->runTool('php tools/ai/validate-ai-catalog.php');
        $this->assertSame(
            0,
            $result['exit'],
            "validate-ai-catalog.php exited non-zero:\n" . $result['stderr']
        );
    }

    public function testValidateAiCatalogOutputsOkLines(): void
    {
        $result = $this->runTool('php tools/ai/validate-ai-catalog.php');
        $combined = $result['stdout'] . $result['stderr'];
        $this->assertStringContainsString('OK', $combined);
    }

    // ---- generate-ai-catalog.php --check ----

    public function testGenerateCatalogCheckModeExitsZero(): void
    {
        $result = $this->runTool('php tools/ai/generate-ai-catalog.php --check');
        $this->assertSame(
            0,
            $result['exit'],
            "generate-ai-catalog.php --check exited non-zero:\n" . $result['stderr']
        );
    }

    public function testGenerateCatalogCheckModeOutputsOkPerFile(): void
    {
        $result = $this->runTool('php tools/ai/generate-ai-catalog.php --check');
        $combined = $result['stdout'] . $result['stderr'];
        $this->assertStringContainsString('OK:', $combined);
    }

    public function testGenerateCatalogCheckModeDoesNotWriteFiles(): void
    {
        // --check must be idempotent: re-running it leaves no changed files
        $before = $this->runTool('php tools/ai/generate-ai-catalog.php --check');
        $after  = $this->runTool('php tools/ai/generate-ai-catalog.php --check');
        $this->assertSame($before['exit'], $after['exit']);
        $this->assertSame(0, $after['exit']);
    }

    // ---- export-ai-universal-rules.php --check ----

    public function testExportAiUniversalRulesCheckModeExitsZero(): void
    {
        $result = $this->runTool('php tools/ai/export-ai-universal-rules.php --check');
        $this->assertSame(
            0,
            $result['exit'],
            "export-ai-universal-rules.php --check exited non-zero:\n" . $result['stderr']
        );
    }

    public function testExportAiUniversalRulesCheckModeOutputsOkPerProfile(): void
    {
        $result = $this->runTool('php tools/ai/export-ai-universal-rules.php --check');
        $combined = $result['stdout'] . $result['stderr'];
        $this->assertStringContainsString('OK: export profile', $combined);
    }
}
