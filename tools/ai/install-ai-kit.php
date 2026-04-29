<?php

declare(strict_types=1);

final class AiKitInstaller
{
    private string $sourceRoot;
    private string $targetRoot;
    private string $profile;
    private string $runtime;
    private string $projectName;
    private bool $force;
    private bool $dryRun;
    private bool $installBase;
    private bool $allowCoreOverwrite;
    /** @var array<string,string> */
    private array $placeholderMap = [];
    /** @var list<string> */
    private array $actions = [];
    /** @var list<string> */
    private array $installedTargets = [];

    public static function main(array $argv): int
    {
        $args = self::parseArgs($argv);

        if (($args['help'] ?? false) === true) {
            self::usage();
            return 0;
        }

        $installer = new self($args);
        return $installer->run();
    }

    /** @param array<string,mixed> $args */
    private function __construct(array $args)
    {
        $this->sourceRoot = $args['sourceRoot'];
        $this->targetRoot = $args['targetRoot'];
        $this->profile = $args['profile'];
        $this->runtime = $args['runtime'];
        $this->projectName = $args['projectName'];
        $this->force = $args['force'];
        $this->dryRun = $args['dryRun'];
        $this->installBase = $args['installBase'];
        $this->allowCoreOverwrite = $args['allowCoreOverwrite'];
    }

    private function run(): int
    {
        $this->log('source root: ' . $this->sourceRoot);
        $this->log('target root: ' . $this->targetRoot);
        $this->log('profile: ' . $this->profile);
        $this->log('runtime: ' . $this->runtime);

        $this->placeholderMap = $this->buildPlaceholderMap();

        if ($this->installBase) {
            $this->installBase();
        }

        if ($this->shouldInstallCopilot()) {
            $this->installCopilot();
        }
        if ($this->shouldInstallOpenCode()) {
            $this->installOpenCode();
        }

        if (!$this->dryRun) {
            $this->applyPlaceholders();
            $unresolved = $this->scanUnresolvedPlaceholders();
            if ($unresolved !== []) {
                $this->log('warning: unresolved placeholders found:');
                foreach ($unresolved as $item) {
                    $this->log('- ' . $item);
                }
            }
        }

        $this->printSummary();
        return 0;
    }

    private function installBase(): void
    {
        $this->copyFile('packages/ai-universal-rules/templates/core/AGENTS.template.md', 'AGENTS.md');
        $this->copyFile('packages/ai-universal-rules/templates/core/project-context.template.md', 'docs/ai/project-context.md');
        $this->copyFile('packages/ai-universal-rules/templates/shared/guardrails/AI-GUARDRAILS.md', 'docs/ai/AI-GUARDRAILS.md');
        $this->copyDir('packages/ai-universal-rules/templates/capabilities/project-context', 'docs/ai/capabilities/project-context');
        $this->copyDir('packages/ai-universal-rules/templates/capabilities/verify-change', 'docs/ai/capabilities/verify-change');
        $this->copyDir('packages/ai-universal-rules/templates/capabilities/review-diff', 'docs/ai/capabilities/review-diff');
    }

    private function installCopilot(): void
    {
        $this->copyFile('packages/ai-universal-rules/templates/core/copilot-instructions.template.md', '.github/copilot-instructions.md');
        $this->copyDir('packages/ai-universal-rules/templates/github-copilot/instructions', '.github/instructions');
        $this->copyDir('packages/ai-universal-rules/templates/github-copilot/agents', '.github/agents');
        $this->copyDir('packages/ai-universal-rules/templates/github-copilot/prompts', '.github/prompts');
    }

    private function installOpenCode(): void
    {
        $this->copyDir('packages/ai-universal-rules/templates/opencode/agents', '.opencode/agents');
        $this->copyDir('packages/ai-universal-rules/templates/opencode/commands', '.opencode/commands');
        $this->copyDir('packages/ai-universal-rules/templates/opencode/skills', '.opencode/skills');
    }

    private function copyFile(string $srcRel, string $destRel): void
    {
        $src = $this->sourceRoot . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $srcRel);
        $dest = $this->targetRoot . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $destRel);

        if (!is_file($src)) {
            throw new RuntimeException("missing source file: {$srcRel}");
        }

        if (is_file($dest) && !$this->force) {
            $this->log("skip existing file (use --force to overwrite): {$destRel}");
            return;
        }
        if (is_file($dest) && $this->force && $this->isProtectedBaseTarget($destRel) && !$this->allowCoreOverwrite) {
            $this->log("protect core file from overwrite (use --allow-core-overwrite): {$destRel}");
            return;
        }

        $this->actions[] = "file {$srcRel} -> {$destRel}";
        $this->installedTargets[] = $dest;
        if ($this->dryRun) {
            return;
        }

        $this->mkdir(dirname($dest));
        if (!copy($src, $dest)) {
            throw new RuntimeException("failed to copy file: {$srcRel}");
        }
        $this->log("copied file: {$destRel}");
    }

    private function copyDir(string $srcRel, string $destRel): void
    {
        $src = $this->sourceRoot . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $srcRel);
        $dest = $this->targetRoot . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $destRel);

        if (!is_dir($src)) {
            throw new RuntimeException("missing source directory: {$srcRel}");
        }

        if (file_exists($dest) && !$this->force) {
            $this->log("skip existing directory (use --force to overwrite): {$destRel}");
            return;
        }
        if (file_exists($dest) && $this->force && $this->isProtectedBaseTarget($destRel) && !$this->allowCoreOverwrite) {
            $this->log("protect core directory from overwrite (use --allow-core-overwrite): {$destRel}");
            return;
        }

        $this->actions[] = "dir {$srcRel} -> {$destRel}";
        $this->installedTargets[] = $dest;
        if ($this->dryRun) {
            return;
        }

        if (file_exists($dest)) {
            $this->deleteTree($dest);
        }
        $this->mkdir(dirname($dest));
        $this->copyTree($src, $dest);
        $this->log("copied directory: {$destRel}");
    }

    private function applyPlaceholders(): void
    {
        foreach ($this->iterMarkdownTargets($this->installedTargets) as $file) {
            $content = (string) file_get_contents($file);
            $updated = str_replace(array_keys($this->placeholderMap), array_values($this->placeholderMap), $content);
            if ($updated !== $content) {
                file_put_contents($file, $updated);
            }
        }
    }

    /** @return list<string> */
    private function scanUnresolvedPlaceholders(): array
    {
        $hits = [];
        foreach ($this->iterMarkdownTargets($this->installedTargets) as $file) {
            $content = (string) file_get_contents($file);
            if (preg_match_all('/<[A-Z0-9_]+>/', $content, $m) === 1 || (isset($m[0]) && $m[0] !== [])) {
                $rel = str_replace('\\', '/', substr($file, strlen($this->targetRoot) + 1));
                $hits[] = $rel . ' => ' . implode(', ', array_unique($m[0]));
            }
        }

        return $hits;
    }

    /** @return iterable<int,string> */
    private function iterMarkdownTargets(array $targets): iterable
    {
        foreach ($targets as $target) {
            if (is_file($target) && str_ends_with(strtolower($target), '.md')) {
                yield $target;
                continue;
            }
            if (!is_dir($target)) {
                continue;
            }
            $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($target, FilesystemIterator::SKIP_DOTS));
            foreach ($it as $file) {
                if (!$file->isFile()) {
                    continue;
                }
                if (strtolower($file->getExtension()) !== 'md') {
                    continue;
                }
                yield $file->getPathname();
            }
        }
    }

    /** @return array<string,string> */
    private function buildPlaceholderMap(): array
    {
        $map = [
            '<PROJECT_NAME>' => $this->projectName,
            '<PROJECT_SUMMARY>' => 'AI workflow starter for ' . $this->projectName,
            '<PROJECT_TYPE>' => $this->detectProjectType(),
            '<PRIMARY_LANGUAGE>' => 'unknown',
            '<PRIMARY_RUNTIME>' => 'unknown',
            '<ACTIVE_PATHS>' => $this->collectActivePaths(),
            '<INACTIVE_PATHS>' => 'unknown',
            '<PRIMARY_ENTRYPOINTS>' => 'README.md, docs/ai/project-context.md',
            '<PRIMARY_VERIFY_COMMAND>' => 'unknown',
            '<PRIMARY_BUILD_COMMAND>' => 'unknown',
            '<PRIMARY_TEST_COMMAND>' => 'unknown',
            '<PROJECT_CONTEXT_PATH>' => 'docs/ai/project-context.md',
            '<AVAILABLE_CAPABILITIES>' => 'project-context, verify-change, review-diff',
            '<REVIEW_PRIORITIES>' => 'correctness, regressions, configuration drift',
            '<APPROVAL_REQUIRED_CHANGES>' => 'secrets, destructive changes, auth or billing changes',
            '<TARGET_PLATFORMS>' => 'unknown',
            '<ARCHITECTURE_NOTES>' => 'Keep policy and capability docs canonical; keep runtime adapters thin.',
            '<RISK_AREAS>' => 'stale docs, adapter drift, unsafe command usage',
            '<NARROW_VERIFY_GUIDANCE>' => 'start with the narrowest repo-local check and escalate only if needed',
            '<CAPABILITY_COMPOSITION_NOTES>' => 'start with project-context, then verify-change, then review-diff',
            '<RELEASE_SAFETY_NOTES>' => 'define rollback posture for medium/high risk changes',
            '<KNOWN_GOTCHA_THEMES>' => 'stale paths, broad edits without evidence, guessed behavior',
            '<COPILOT_SURFACE>' => 'VS Code, CLI, GitHub.com',
            '<SUPPORTED_FEATURES>' => 'repo instructions, path instructions',
            '<OPTIONAL_FEATURES>' => 'prompt files, custom agents, hooks, MCP',
            '<INSTRUCTION_PRECEDENCE_NOTES>' => 'Nearest AGENTS.md wins for agent instructions.',
            '<CONFLICT_AVOIDANCE_NOTES>' => 'Keep repo-wide and path-specific guidance complementary.',
            '<GLOBAL_OR_SHARED_RULE_SOURCES>' => 'organization instructions, user-level instructions',
            '<OPTIONAL_VERIFY_COMMAND>' => 'unknown',
        ];

        return $map;
    }

    private function detectProjectType(): string
    {
        if (is_file($this->targetRoot . DIRECTORY_SEPARATOR . 'composer.json')) {
            return 'php project';
        }
        if (is_file($this->targetRoot . DIRECTORY_SEPARATOR . 'package.json')) {
            return 'node project';
        }
        if (is_file($this->targetRoot . DIRECTORY_SEPARATOR . 'go.mod')) {
            return 'go project';
        }
        return 'repository';
    }

    private function collectActivePaths(): string
    {
        $gitDir = $this->targetRoot . DIRECTORY_SEPARATOR . '.git';
        if (!is_dir($gitDir)) {
            return '_root';
        }

        $output = [];
        $cmd = 'git -C ' . escapeshellarg($this->targetRoot) . ' ls-files';
        exec($cmd, $output);
        if ($output === []) {
            return '_root';
        }
        $tops = [];
        foreach ($output as $line) {
            $parts = explode('/', $line);
            $tops[$parts[0] !== '' ? $parts[0] : '_root'] = true;
        }
        return implode(',', array_keys($tops));
    }

    private function shouldInstallCopilot(): bool
    {
        if ($this->profile === 'minimal') {
            return false;
        }
        return $this->runtime === 'both' || $this->runtime === 'github-copilot';
    }

    private function shouldInstallOpenCode(): bool
    {
        if ($this->profile === 'minimal') {
            return false;
        }
        return $this->runtime === 'both' || $this->runtime === 'opencode';
    }

    private function isProtectedBaseTarget(string $destRel): bool
    {
        return in_array($destRel, [
            'AGENTS.md',
            'docs/ai/project-context.md',
            'docs/ai/AI-GUARDRAILS.md',
            'docs/ai/capabilities/project-context',
            'docs/ai/capabilities/verify-change',
            'docs/ai/capabilities/review-diff',
        ], true);
    }

    private function printSummary(): void
    {
        if ($this->dryRun) {
            $this->log('dry-run complete; no files changed');
        } else {
            $this->log('install complete');
        }

        $this->log('actions: ' . count($this->actions));
        $this->log('next steps:');
        $this->log('1) review AGENTS.md and docs/ai/project-context.md');
        $this->log('2) run php tools/ai/validate-ai-config.php');
        $this->log('3) run php tools/ai/validate-ai-catalog.php (if catalog files changed)');
        if ($this->shouldInstallOpenCode()) {
            $this->log('4) OpenCode runtime paths: .opencode/agents, .opencode/commands, .opencode/skills');
        }
        if ($this->shouldInstallCopilot()) {
            $this->log('5) Copilot runtime paths: .github/copilot-instructions.md, .github/instructions, .github/agents, .github/prompts');
        }
    }

    private function mkdir(string $path): void
    {
        if (is_dir($path)) {
            return;
        }
        if (!mkdir($path, 0777, true) && !is_dir($path)) {
            throw new RuntimeException('failed to create directory: ' . $path);
        }
    }

    private function copyTree(string $src, string $dest): void
    {
        $this->mkdir($dest);
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($src, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::SELF_FIRST);
        foreach ($it as $item) {
            $target = $dest . DIRECTORY_SEPARATOR . $it->getSubPathName();
            if ($item->isDir()) {
                $this->mkdir($target);
                continue;
            }
            $this->mkdir(dirname($target));
            if (!copy($item->getPathname(), $target)) {
                throw new RuntimeException('failed to copy file: ' . $item->getPathname());
            }
        }
    }

    private function deleteTree(string $path): void
    {
        if (is_file($path) || is_link($path)) {
            @unlink($path);
            return;
        }
        if (!is_dir($path)) {
            return;
        }
        $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($path, FilesystemIterator::SKIP_DOTS), RecursiveIteratorIterator::CHILD_FIRST);
        foreach ($it as $item) {
            if ($item->isDir()) {
                @rmdir($item->getPathname());
            } else {
                @unlink($item->getPathname());
            }
        }
        @rmdir($path);
    }

    private function log(string $message): void
    {
        fwrite(STDOUT, '[install-ai-kit] ' . $message . PHP_EOL);
    }

    /** @param array<int,string> $argv @return array<string,mixed> */
    private static function parseArgs(array $argv): array
    {
        $target = '.';
        $profile = 'dual';
        $runtime = '';
        $projectName = '';
        $force = false;
        $dryRun = false;
        $installBase = true;
        $allowCoreOverwrite = false;
        $help = false;

        for ($i = 1; $i < count($argv); $i++) {
            $arg = $argv[$i];
            if ($arg === '--help' || $arg === '-h') {
                $help = true;
                continue;
            }
            if ($arg === '--force') {
                $force = true;
                continue;
            }
            if ($arg === '--dry-run') {
                $dryRun = true;
                continue;
            }
            if ($arg === '--no-base') {
                $installBase = false;
                continue;
            }
            if ($arg === '--allow-core-overwrite') {
                $allowCoreOverwrite = true;
                continue;
            }
            if (str_starts_with($arg, '--target=')) {
                $target = substr($arg, 9);
                continue;
            }
            if ($arg === '--target') {
                $target = $argv[++$i] ?? '';
                continue;
            }
            if (str_starts_with($arg, '--profile=')) {
                $profile = substr($arg, 10);
                continue;
            }
            if ($arg === '--profile') {
                $profile = $argv[++$i] ?? '';
                continue;
            }
            if (str_starts_with($arg, '--runtime=')) {
                $runtime = substr($arg, 10);
                continue;
            }
            if ($arg === '--runtime') {
                $runtime = $argv[++$i] ?? '';
                continue;
            }
            if (str_starts_with($arg, '--project-name=')) {
                $projectName = substr($arg, 15);
                continue;
            }
            if ($arg === '--project-name') {
                $projectName = $argv[++$i] ?? '';
                continue;
            }
            throw new InvalidArgumentException("unknown option '{$arg}'");
        }

        $scriptDir = realpath(__DIR__);
        if ($scriptDir === false) {
            throw new RuntimeException('unable to resolve script dir');
        }
        $sourceRoot = realpath($scriptDir . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . '..');
        if ($sourceRoot === false) {
            throw new RuntimeException('unable to resolve source root');
        }
        $targetRoot = realpath($target);
        if ($targetRoot === false || !is_dir($targetRoot)) {
            throw new InvalidArgumentException('target directory not found: ' . $target);
        }

        $allowedProfiles = ['minimal', 'copilot', 'opencode', 'dual', 'guarded'];
        if (!in_array($profile, $allowedProfiles, true)) {
            throw new InvalidArgumentException('unsupported profile: ' . $profile);
        }

        if ($runtime === '') {
            $runtime = match ($profile) {
                'copilot' => 'github-copilot',
                'opencode' => 'opencode',
                default => 'both',
            };
        }
        $allowedRuntimes = ['github-copilot', 'opencode', 'both'];
        if (!in_array($runtime, $allowedRuntimes, true)) {
            throw new InvalidArgumentException('unsupported runtime: ' . $runtime);
        }

        if ($projectName === '') {
            $projectName = basename($targetRoot);
        }

        return [
            'help' => $help,
            'sourceRoot' => $sourceRoot,
            'targetRoot' => $targetRoot,
            'profile' => $profile,
            'runtime' => $runtime,
            'projectName' => $projectName,
            'force' => $force,
            'dryRun' => $dryRun,
            'installBase' => $installBase,
            'allowCoreOverwrite' => $allowCoreOverwrite,
        ];
    }

    private static function usage(): void
    {
        $text = <<<'TXT'
Usage:
  php tools/ai/install-ai-kit.php [options]

Options:
  --target <dir>      Target repository root (default: .)
  --profile <name>    Install profile: minimal|copilot|opencode|dual|guarded (default: dual)
  --runtime <name>    Runtime override: github-copilot|opencode|both
  --project-name <n>  Override inferred project name
  --force             Overwrite existing files
  --no-base           Skip base-layer install
  --allow-core-overwrite  Permit force-overwrite of core base policy files
  --dry-run           Print planned actions only
  --help              Show this help

Examples:
  php tools/ai/install-ai-kit.php --target ../repo --profile dual --dry-run
  php tools/ai/install-ai-kit.php --target ../repo --profile opencode --force
TXT;
        fwrite(STDOUT, $text . PHP_EOL);
    }
}

try {
    exit(AiKitInstaller::main($argv));
} catch (Throwable $e) {
    fwrite(STDERR, 'Error: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
