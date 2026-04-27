<?php

declare(strict_types=1);

date_default_timezone_set('UTC');

$checkOnly = in_array('--check', $argv, true);
$withScc = in_array('--with-scc', $argv, true);
$rootInput = '.';
$outputDirInput = 'docs/ai/generated';

foreach ($argv as $argument) {
    if (str_starts_with($argument, '--root=')) {
        $rootInput = substr($argument, strlen('--root='));
    }

    if (str_starts_with($argument, '--output-dir=')) {
        $outputDirInput = substr($argument, strlen('--output-dir='));
    }
}

$root = realpath($rootInput);

if ($root === false || !is_dir($root)) {
    fwrite(STDERR, "ERROR: root directory not found: {$rootInput}\n");
    exit(1);
}

$gitCheck = runCommand(['git', 'rev-parse', '--is-inside-work-tree'], $root);

if ($gitCheck['exit'] !== 0 || trim($gitCheck['stdout']) !== 'true') {
    fwrite(STDERR, "ERROR: root is not a git repository: {$root}\n");
    exit(1);
}

$filesResult = runCommand(['git', 'ls-files'], $root);

if ($filesResult['exit'] !== 0) {
    fwrite(STDERR, "ERROR: unable to read tracked files with git ls-files\n");
    fwrite(STDERR, trim($filesResult['stderr']) . "\n");
    exit(1);
}

$trackedFiles = array_values(
    array_filter(
        array_map(static fn (string $line): string => trim(str_replace('\\', '/', $line)), preg_split('/\r?\n/', $filesResult['stdout']) ?: []),
        static fn (string $line): bool => $line !== ''
    )
);

sort($trackedFiles, SORT_STRING);

if ($trackedFiles === []) {
    fwrite(STDERR, "ERROR: no tracked files found\n");
    exit(1);
}

$folderMap = [];

foreach ($trackedFiles as $file) {
    $parts = explode('/', $file);
    $folder = count($parts) > 1 ? $parts[0] : '_root';

    if (!array_key_exists($folder, $folderMap)) {
        $folderMap[$folder] = [];
    }

    $folderMap[$folder][] = $file;
}

ksort($folderMap, SORT_STRING);

$sccByFile = [];

if ($withScc) {
    $sccCheck = runCommand(['scc', '--by-file', '--format', 'json', '.'], $root);

    if ($sccCheck['exit'] !== 0) {
        fwrite(STDERR, "ERROR: unable to run scc --by-file --format json .\n");
        fwrite(STDERR, trim($sccCheck['stderr']) . "\n");
        exit(1);
    }

    $decoded = json_decode($sccCheck['stdout'], true);

    if (!is_array($decoded)) {
        fwrite(STDERR, "ERROR: invalid JSON returned by scc\n");
        exit(1);
    }

    foreach ($decoded as $languageGroup) {
        if (!is_array($languageGroup) || !isset($languageGroup['Files']) || !is_array($languageGroup['Files'])) {
            continue;
        }

        foreach ($languageGroup['Files'] as $fileEntry) {
            if (!is_array($fileEntry) || !isset($fileEntry['Location']) || !is_string($fileEntry['Location'])) {
                continue;
            }

            $location = str_replace('\\', '/', $fileEntry['Location']);
            $location = preg_replace('/^\.\//', '', $location) ?? $location;

            $sccByFile[$location] = [
                'lines' => toInt($fileEntry['Lines'] ?? 0),
                'code' => toInt($fileEntry['Code'] ?? 0),
                'comments' => toInt($fileEntry['Comment'] ?? 0),
                'blanks' => toInt($fileEntry['Blank'] ?? 0),
                'complexity' => toInt($fileEntry['Complexity'] ?? 0),
                'bytes' => toInt($fileEntry['Bytes'] ?? 0),
            ];
        }
    }
}

$folders = [];

foreach ($folderMap as $folder => $files) {
    sort($files, SORT_STRING);

    $metrics = [
        'lines' => 0,
        'code' => 0,
        'comments' => 0,
        'blanks' => 0,
        'complexity' => 0,
        'bytes' => 0,
    ];

    if ($withScc) {
        foreach ($files as $file) {
            if (!array_key_exists($file, $sccByFile)) {
                continue;
            }

            $metrics['lines'] += $sccByFile[$file]['lines'];
            $metrics['code'] += $sccByFile[$file]['code'];
            $metrics['comments'] += $sccByFile[$file]['comments'];
            $metrics['blanks'] += $sccByFile[$file]['blanks'];
            $metrics['complexity'] += $sccByFile[$file]['complexity'];
            $metrics['bytes'] += $sccByFile[$file]['bytes'];
        }
    }

    $folders[] = [
        'path' => $folder,
        'file_count' => count($files),
        'files' => $files,
        'files_csv' => implode(',', $files),
        'metrics' => $withScc ? $metrics : null,
    ];
}

$payload = [
    'generated_by' => 'php tools/ai/generate-repo-structure.php',
    'root' => $root,
    'source' => 'git ls-files',
    'with_scc' => $withScc,
    'folder_count' => count($folders),
    'tracked_file_count' => count($trackedFiles),
    'folders' => $folders,
];

$jsonOutput = json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
$csvOutput = renderCsv($folders, $withScc);
$mdOutput = renderMarkdown($payload);

$outputDir = isAbsolutePath($outputDirInput)
    ? $outputDirInput
    : $root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $outputDirInput);

$outputDir = rtrim($outputDir, DIRECTORY_SEPARATOR);

$jsonPath = $outputDir . DIRECTORY_SEPARATOR . 'repo-structure.json';
$csvPath = $outputDir . DIRECTORY_SEPARATOR . 'repo-structure.csv';
$mdPath = $outputDir . DIRECTORY_SEPARATOR . 'repo-structure.md';

$messages = [];
$ok = true;
$ok = compareOrWrite($jsonPath, $jsonOutput, $checkOnly, $messages) && $ok;
$ok = compareOrWrite($csvPath, $csvOutput, $checkOnly, $messages) && $ok;
$ok = compareOrWrite($mdPath, $mdOutput, $checkOnly, $messages) && $ok;

foreach ($messages as $message) {
    $stream = str_starts_with($message, 'ERROR:') ? STDERR : STDOUT;
    fwrite($stream, $message . "\n");
}

exit($ok ? 0 : 1);

function compareOrWrite(string $path, string $content, bool $checkOnly, array &$messages): bool
{
    $normalizedContent = str_replace("\r\n", "\n", $content);
    $exists = is_file($path);
    $current = $exists ? str_replace("\r\n", "\n", (string) file_get_contents($path)) : null;

    if ($checkOnly) {
        if (!$exists) {
            $messages[] = "ERROR: missing generated file {$path}";
            return false;
        }

        if ($current !== $normalizedContent) {
            $messages[] = "ERROR: generated output drift detected in {$path}";
            return false;
        }

        $messages[] = "OK: {$path} is up to date";
        return true;
    }

    $directory = dirname($path);

    if (!is_dir($directory) && !mkdir($directory, 0777, true) && !is_dir($directory)) {
        $messages[] = "ERROR: unable to create directory {$directory}";
        return false;
    }

    file_put_contents($path, $normalizedContent);
    $messages[] = "OK: wrote {$path}";
    return true;
}

function renderCsv(array $folders, bool $withScc): string
{
    $stream = fopen('php://temp', 'r+');

    if ($stream === false) {
        throw new RuntimeException('unable to open temporary stream for csv rendering');
    }

    if ($withScc) {
        fputcsv($stream, ['folder', 'file_count', 'lines', 'code', 'comments', 'blanks', 'complexity', 'bytes', 'files'], ',', '"', '\\');
    } else {
        fputcsv($stream, ['folder', 'file_count', 'files'], ',', '"', '\\');
    }

    foreach ($folders as $folder) {
        if ($withScc) {
            fputcsv($stream, [
                $folder['path'],
                $folder['file_count'],
                $folder['metrics']['lines'],
                $folder['metrics']['code'],
                $folder['metrics']['comments'],
                $folder['metrics']['blanks'],
                $folder['metrics']['complexity'],
                $folder['metrics']['bytes'],
                $folder['files_csv'],
            ], ',', '"', '\\');
        } else {
            fputcsv($stream, [
                $folder['path'],
                $folder['file_count'],
                $folder['files_csv'],
            ], ',', '"', '\\');
        }
    }

    rewind($stream);
    $output = (string) stream_get_contents($stream);
    fclose($stream);
    return $output;
}

function renderMarkdown(array $payload): string
{
    $lines = [];
    $lines[] = '# Repo Structure';
    $lines[] = '';
    $lines[] = '_Generated by `php tools/ai/generate-repo-structure.php`. Do not edit by hand._';
    $lines[] = '';
    $lines[] = '- Source: `git ls-files` (tracked files only)';
    $lines[] = '- Folder count: `' . $payload['folder_count'] . '`';
    $lines[] = '- Tracked file count: `' . $payload['tracked_file_count'] . '`';
    $lines[] = '- SCC metrics: `' . ($payload['with_scc'] ? 'enabled' : 'disabled') . '`';
    $lines[] = '';
    $lines[] = '## Folder Index';
    $lines[] = '';

    foreach ($payload['folders'] as $folder) {
        $summary = '- `' . $folder['path'] . '` (' . $folder['file_count'] . ' files)';

        if (is_array($folder['metrics'])) {
            $summary .= ', code=' . $folder['metrics']['code'] . ', complexity=' . $folder['metrics']['complexity'];
        }

        $lines[] = $summary;
    }

    $lines[] = '';
    $lines[] = '## Folder To Files (comma-separated)';
    $lines[] = '';

    foreach ($payload['folders'] as $folder) {
        $lines[] = '### `' . $folder['path'] . '`';
        $lines[] = '';
        $lines[] = '`' . $folder['files_csv'] . '`';
        $lines[] = '';
    }

    return implode("\n", $lines) . "\n";
}

/**
 * @param array<int, string> $command
 * @return array{stdout: string, stderr: string, exit: int}
 */
function runCommand(array $command, string $cwd): array
{
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];

    $process = proc_open($command, $descriptors, $pipes, $cwd);

    if (!is_resource($process)) {
        return ['stdout' => '', 'stderr' => 'failed to start command', 'exit' => 1];
    }

    fclose($pipes[0]);
    $stdout = (string) stream_get_contents($pipes[1]);
    $stderr = (string) stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $exit = proc_close($process);

    return ['stdout' => $stdout, 'stderr' => $stderr, 'exit' => $exit];
}

function toInt(mixed $value): int
{
    return is_numeric($value) ? (int) $value : 0;
}

function isAbsolutePath(string $path): bool
{
    if ($path === '') {
        return false;
    }

    if ($path[0] === '/' || $path[0] === '\\') {
        return true;
    }

    return preg_match('/^[A-Za-z]:[\\\\\/]/', $path) === 1;
}
