<?php

declare(strict_types=1);

namespace Tests;

use PHPUnit\Framework\TestCase;

class GenerateRepoStructureTest extends TestCase
{
    private string $tmpDir;
    private string $repoRoot;

    protected function setUp(): void
    {
        $root = realpath(dirname(__DIR__, 2));
        if ($root === false) {
            throw new \RuntimeException('Could not resolve repo root');
        }

        $this->repoRoot = $root;
        $this->tmpDir = sys_get_temp_dir() . '/repo_structure_test_' . uniqid('', true);
        mkdir($this->tmpDir, 0700, true);
    }

    protected function tearDown(): void
    {
        $this->removeDir($this->tmpDir);
    }

    public function testValidMetadataPasses(): void
    {
        $fixture = $this->createFixtureRepo();
        $metadataPath = $this->writeMetadata($fixture, $this->baseDirectories());

        $result = $this->runGenerator($fixture, $metadataPath);

        $this->assertSame(0, $result['exit'], $result['stderr']);
        $this->assertFileExists($fixture . '/out/repo-structure.json');
        $this->assertFileExists($fixture . '/out/repo-structure.csv');
        $this->assertFileExists($fixture . '/out/repo-structure.md');
        $this->assertFileExists($fixture . '/out/repo-structure.log');
    }

    public function testUnsupportedSchemaVersionFails(): void
    {
        $fixture = $this->createFixtureRepo();
        $metadataPath = $this->writeMetadata($fixture, $this->baseDirectories(), 99);

        $result = $this->runGenerator($fixture, $metadataPath);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString('unsupported metadata schema_version', $result['stderr']);
    }

    public function testDuplicateMetadataPathFails(): void
    {
        $fixture = $this->createFixtureRepo();
        $directories = $this->baseDirectories();
        $directories[] = $directories[0];
        $metadataPath = $this->writeMetadata($fixture, $directories);

        $result = $this->runGenerator($fixture, $metadataPath);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString('duplicate metadata path', $result['stderr']);
    }

    public function testMissingRequiredFieldFails(): void
    {
        $fixture = $this->createFixtureRepo();
        $directories = $this->baseDirectories();
        unset($directories[1]['purpose']);
        $metadataPath = $this->writeMetadata($fixture, $directories);

        $result = $this->runGenerator($fixture, $metadataPath);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString("missing required field 'purpose'", $result['stderr']);
    }

    public function testMissingRootMetadataFailsWhenRootFilesExist(): void
    {
        $fixture = $this->createFixtureRepo();
        $directories = array_values(array_filter(
            $this->baseDirectories(),
            static fn(array $entry): bool => $entry['path'] !== '.'
        ));
        $metadataPath = $this->writeMetadata($fixture, $directories);

        $result = $this->runGenerator($fixture, $metadataPath);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString("metadata entry for '.' is required", $result['stderr']);
    }

    public function testBadReferencePathFails(): void
    {
        $fixture = $this->createFixtureRepo();
        $directories = $this->baseDirectories();
        $directories[1]['install_guide'] = 'docs/ai/missing.md';
        $metadataPath = $this->writeMetadata($fixture, $directories);

        $result = $this->runGenerator($fixture, $metadataPath);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString("metadata reference 'install_guide' points to missing file", $result['stderr']);
    }

    public function testMissingTopLevelMetadataFails(): void
    {
        $fixture = $this->createFixtureRepo();
        mkdir($fixture . '/scripts', 0777, true);
        file_put_contents($fixture . '/scripts/run.sh', "#!/usr/bin/env bash\n");
        $this->git($fixture, 'git add scripts/run.sh');

        $metadataPath = $this->writeMetadata($fixture, $this->baseDirectories());
        $result = $this->runGenerator($fixture, $metadataPath);

        $this->assertNotSame(0, $result['exit']);
        $this->assertStringContainsString('missing metadata for top-level paths: scripts', $result['stderr']);
    }

    private function createFixtureRepo(): string
    {
        $fixture = $this->tmpDir . '/fixture';
        mkdir($fixture, 0777, true);

        $this->git($fixture, 'git init');

        mkdir($fixture . '/docs/ai', 0777, true);
        mkdir($fixture . '/tools/ai', 0777, true);

        file_put_contents($fixture . '/README.md', "# Fixture\n");
        file_put_contents($fixture . '/docs/ai/external-repo-install.md', "# Install\n");
        file_put_contents($fixture . '/docs/ai/context-packing.md', "# Context\n");
        file_put_contents($fixture . '/tools/ai/install-copilot-kit.sh', "#!/usr/bin/env bash\n");

        $this->git($fixture, 'git add README.md docs/ai/external-repo-install.md docs/ai/context-packing.md tools/ai/install-copilot-kit.sh');

        return $fixture;
    }

    /**
     * @return array<int, array<string, string>>
     */
    private function baseDirectories(): array
    {
        return [
            [
                'path' => '.',
                'purpose' => 'Root files',
                'designed_for' => 'Humans and tools',
                'install_guide' => 'docs/ai/external-repo-install.md',
                'install_script' => 'none',
                'ai_entrypoint' => 'README.md',
                'notes' => 'Root metadata',
            ],
            [
                'path' => 'docs',
                'purpose' => 'Docs',
                'designed_for' => 'Humans and agents',
                'install_guide' => 'docs/ai/external-repo-install.md',
                'install_script' => 'tools/ai/install-copilot-kit.sh',
                'ai_entrypoint' => 'docs/ai/context-packing.md',
                'notes' => 'Docs metadata',
            ],
            [
                'path' => 'tools',
                'purpose' => 'Tools',
                'designed_for' => 'Maintainers',
                'install_guide' => 'docs/ai/external-repo-install.md',
                'install_script' => 'tools/ai/install-copilot-kit.sh',
                'ai_entrypoint' => 'tools/ai/install-copilot-kit.sh',
                'notes' => 'Tools metadata',
            ],
        ];
    }

    /**
     * @param array<int, array<string, string>> $directories
     */
    private function writeMetadata(string $fixture, array $directories, int $schemaVersion = 1): string
    {
        $payload = [
            'schema_version' => $schemaVersion,
            'directories' => $directories,
            'metadata_exemptions' => [],
        ];

        $path = $fixture . '/metadata.json';
        file_put_contents($path, (string) json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

        return $path;
    }

    /**
     * @return array{stdout: string, stderr: string, exit: int}
     */
    private function runGenerator(string $fixture, string $metadataPath): array
    {
        $command = sprintf(
            'php %s --root=. --output-dir=out --metadata=%s',
            escapeshellarg($this->repoRoot . '/tools/ai/generate-repo-structure.php'),
            escapeshellarg($metadataPath)
        );

        return $this->runCommand($command, $fixture);
    }

    private function git(string $cwd, string $command): void
    {
        $result = $this->runCommand($command, $cwd);
        $this->assertSame(0, $result['exit'], $result['stderr']);
    }

    /**
     * @return array{stdout: string, stderr: string, exit: int}
     */
    private function runCommand(string $command, string $cwd): array
    {
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $process = proc_open($command, $descriptors, $pipes, $cwd, [
            'PATH' => (string) getenv('PATH'),
        ]);

        $this->assertIsResource($process, "proc_open failed for: $command");

        fclose($pipes[0]);
        $stdout = (string) stream_get_contents($pipes[1]);
        $stderr = (string) stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        $exit = proc_close($process);

        return ['stdout' => $stdout, 'stderr' => $stderr, 'exit' => $exit];
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
