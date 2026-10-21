#!/usr/bin/env php
<?php

declare(strict_types=1);

namespace LogErrors;

use DateTimeImmutable;
use DateTimeZone;
use Generator;
use JsonException;
use RuntimeException;
use Throwable;

final class UsageError extends RuntimeException {}
final class ResourceError extends RuntimeException {}

final class Options
{
    /** @param list<string> $levels @param list<string> $contains @param list<string> $ignores @param list<string> $paths */
    public function __construct(
        public array $levels = ['ERROR', 'CRITICAL', 'ALERT', 'EMERGENCY'],
        public array $contains = [],
        public array $ignores = [],
        public ?string $pattern = null,
        public string $group = 'smart',
        public bool $full = false,
        public string $format = 'human',
        public bool $includeNoise = false,
        public bool $noPager = false,
        public bool $preview = false,
        public array $paths = [],
        public bool $help = false,
    ) {}

    /** @param list<string> $argv */
    public static function parse(array $argv): self
    {
        $options = new self();
        $explicitLevels = [];
        $endOptions = false;
        $legacy = ['--levels', '--unique', '--target-dir'];

        for ($i = 1, $count = count($argv); $i < $count; $i++) {
            $arg = $argv[$i];
            if ($endOptions) {
                $options->paths[] = $arg;
                continue;
            }
            if ($arg === '--') {
                $endOptions = true;
                continue;
            }
            if (in_array($arg, $legacy, true)) {
                throw new UsageError("Legacy option is no longer supported: {$arg}");
            }
            if ($arg === '-h' || $arg === '--help') {
                $options->help = true;
                continue;
            }
            if (in_array($arg, ['--full', '--include-noise', '--no-pager', '--preview'], true)) {
                match ($arg) {
                    '--full' => $options->full = true,
                    '--include-noise' => $options->includeNoise = true,
                    '--no-pager' => $options->noPager = true,
                    '--preview' => $options->preview = true,
                };
                continue;
            }
            if (str_starts_with($arg, '-')) {
                if (!in_array($arg, ['--level', '--contains', '--ignore', '--pattern', '--group', '--format'], true)) {
                    throw new UsageError("Unknown option: {$arg}");
                }
                if (!isset($argv[$i + 1])) {
                    throw new UsageError("Missing value for {$arg}");
                }
                $value = $argv[++$i];
                if ($value === '') {
                    throw new UsageError("Empty value for {$arg}");
                }
                match ($arg) {
                    '--level' => array_push($explicitLevels, ...self::parseLevels($value)),
                    '--contains' => $options->contains[] = $value,
                    '--ignore' => $options->ignores[] = $value,
                    '--pattern' => $options->pattern === null
                        ? $options->pattern = $value
                        : throw new UsageError('--pattern may be supplied only once'),
                    '--group' => $options->group = $value,
                    '--format' => $options->format = $value,
                };
                continue;
            }
            $options->paths[] = $arg;
        }

        if ($explicitLevels !== []) {
            $options->levels = array_values(array_unique(array_map([EventUtil::class, 'normalizeLevel'], $explicitLevels)));
        }
        if (!in_array($options->group, ['smart', 'exact', 'none'], true)) {
            throw new UsageError('--group must be smart, exact, or none');
        }
        if (!in_array($options->format, ['human', 'json', 'jsonl'], true)) {
            throw new UsageError('--format must be human, json, or jsonl');
        }
        if ($options->preview && $options->format !== 'human') {
            throw new UsageError('--preview may only be used with --format human');
        }
        foreach ($options->ignores as $pattern) {
            Regex::validate($pattern, '--ignore');
        }
        if ($options->pattern !== null) {
            Regex::validate($options->pattern, '--pattern');
        }
        if (!$options->help && $options->paths === []) {
            throw new UsageError('At least one input path is required');
        }
        return $options;
    }

    /** @return list<string> */
    private static function parseLevels(string $value): array
    {
        $levels = preg_split('/[|,\s]+/', trim($value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        if ($levels === []) {
            throw new UsageError('No levels provided for --level');
        }
        foreach ($levels as $level) {
            $normalized = EventUtil::normalizeLevel($level);
            if (!in_array($normalized, EventUtil::LEVELS, true)) {
                throw new UsageError("Unknown log level: {$level}");
            }
        }
        return $levels;
    }

    public static function usage(): string
    {
        return <<<'TEXT'
Usage: log-errors [OPTIONS] [--] PATH...

Find, preserve, and group complete error events in files or directories.

  --level LEVEL        select a level (repeatable; comma-separated also accepted)
  --contains TEXT      require literal text in the complete event (repeatable)
  --ignore PCRE        exclude matching complete events (repeatable)
  --pattern PCRE       select events matching a case-insensitive PCRE
  --group MODE         smart (default), exact, or none
  --full               include each newest complete event in human output
  --format FORMAT      human (default), json, or jsonl
  --include-noise      skip repository noise rules (CLI ignores still apply)
  --no-pager           never page human output
  --preview            force styled human output without pager
  -h, --help           show this help

Selection is: (selected level OR pattern) AND every --contains AND no ignore.
TEXT;
    }
}

final class Regex
{
    public static function compile(string $expression): string
    {
        // Logs are byte streams and can contain malformed UTF-8. PCRE's `u`
        // modifier would turn those events into silent non-matches.
        return '~' . str_replace('~', '\\~', $expression) . '~i';
    }

    public static function validate(string $expression, string $label): void
    {
        $message = null;
        set_error_handler(static function (int $_severity, string $text) use (&$message): bool {
            $message = preg_replace('/^preg_match\(\): /', '', $text);
            return true;
        });
        try {
            $result = preg_match(self::compile($expression), '');
        } finally {
            restore_error_handler();
        }
        if ($result === false) {
            throw new UsageError("Invalid {$label} PCRE: " . ($message ?? preg_last_error_msg()));
        }
    }

    public static function matches(string $expression, string $subject): bool
    {
        return preg_match(self::compile($expression), $subject) === 1;
    }
}

final class EventUtil
{
    public const LEVELS = ['TRACE', 'DEBUG', 'INFO', 'NOTICE', 'WARNING', 'ERROR', 'CRITICAL', 'ALERT', 'EMERGENCY'];
    public const SEVERITY = ['TRACE' => 0, 'DEBUG' => 1, 'INFO' => 2, 'NOTICE' => 3, 'WARNING' => 4, 'ERROR' => 5, 'CRITICAL' => 6, 'ALERT' => 7, 'EMERGENCY' => 8];

    public static function normalizeLevel(string $level): string
    {
        $level = strtoupper(trim($level));
        return match ($level) {
            'WARN' => 'WARNING',
            'FATAL' => 'EMERGENCY',
            default => $level,
        };
    }

    /** @return array{timestamp:?string,timestamp_kind:string,timestamp_raw:?string,sort:?float} */
    public static function timestamp(?string $raw): array
    {
        if ($raw === null || trim($raw) === '') {
            return ['timestamp' => null, 'timestamp_kind' => 'missing', 'timestamp_raw' => $raw, 'sort' => null];
        }
        $raw = trim($raw);
        $parseRaw = preg_replace('/(\.\d{6})\d+(?=Z|[+-]\d{2}:?\d{2}|$)/', '$1', $raw) ?? $raw;
        $offsetAware = preg_match('/(?:Z|[+-]\d{2}:?\d{2})$/i', $raw) === 1;
        if ($offsetAware) {
            try {
                $value = new DateTimeImmutable($parseRaw);
                $errors = DateTimeImmutable::getLastErrors();
                if ($errors !== false && ($errors['warning_count'] > 0 || $errors['error_count'] > 0)) {
                    throw new RuntimeException('Invalid timestamp');
                }
                $utc = $value->setTimezone(new DateTimeZone('UTC'));
                return [
                    'timestamp' => $utc->format('Y-m-d\TH:i:s.u\Z'),
                    'timestamp_kind' => 'utc',
                    'timestamp_raw' => $raw,
                    'sort' => (float) $utc->format('U.u'),
                ];
            } catch (Throwable) {
                return ['timestamp' => null, 'timestamp_kind' => 'missing', 'timestamp_raw' => $raw, 'sort' => null];
            }
        }
        $formats = ['!Y-m-d H:i:s.u', '!Y-m-d H:i:s', '!Y-m-d\TH:i:s.u', '!Y-m-d\TH:i:s'];
        foreach ($formats as $format) {
            $value = DateTimeImmutable::createFromFormat($format, $parseRaw, new DateTimeZone('UTC'));
            $errors = DateTimeImmutable::getLastErrors();
            if ($value !== false && ($errors === false || ($errors['warning_count'] === 0 && $errors['error_count'] === 0))) {
                return [
                    'timestamp' => str_contains($raw, 'T') ? $value->format('Y-m-d\TH:i:s.u') : $value->format('Y-m-d H:i:s.u'),
                    'timestamp_kind' => 'local-unknown-offset',
                    'timestamp_raw' => $raw,
                    'sort' => (float) $value->format('U.u'),
                ];
            }
        }
        return ['timestamp' => null, 'timestamp_kind' => 'missing', 'timestamp_raw' => $raw, 'sort' => null];
    }

    public static function stripControls(string $value): string
    {
        $value = preg_replace('/\x1B\][^\x07]*(?:\x07|\x1B\\\\)/s', '', $value) ?? $value;
        $value = preg_replace('/\x1B\[[0-?]*[ -\/]*[@-~]/', '', $value) ?? $value;
        return preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', '', $value) ?? $value;
    }

    public static function terminalMetadata(string $value): string
    {
        return str_replace(["\r", "\n", "\t"], ['\\r', '\\n', '\\t'], self::stripControls($value));
    }

    public static function inferLevel(string $text): ?string
    {
        if (preg_match('/\b(?:fatal error|uncaught\s+(?:[\\\\\w]+)?(?:exception|error)|unhandled(?:promise)?rejection)\b/i', $text)) {
            return 'EMERGENCY';
        }
        if (preg_match('/(?:^|\n)\s*(?:Error|TypeError|ReferenceError|RangeError|[A-Z][\\\\\w]*Exception)\s*:/m', $text)) {
            return 'ERROR';
        }
        return null;
    }

    /** @return array{exception_class:?string,application_frame:?array{path:string,line:?int,column:?int},stack:?string} */
    public static function exceptionData(string $text, ?array $json = null): array
    {
        $exception = null;
        foreach (['exception_class', 'exception.type', 'error.type', 'error.name', 'exception', 'type', 'name'] as $key) {
            $candidate = is_array($json) ? self::nestedString($json, $key) : null;
            if ($candidate !== null && preg_match('/(?:Exception|Error)$/', $candidate)) {
                $exception = $candidate;
                break;
            }
        }
        if ($exception === null && preg_match('/(?:Uncaught\s+)?([A-Z][A-Za-z0-9_\\\\]*(?:Exception|Error))(?::|\s)/', $text, $match)) {
            $exception = $match[1];
        }
        $frame = null;
        $lines = preg_split('/\R/', $text) ?: [];
        foreach ($lines as $line) {
            $path = null;
            $lineNo = null;
            $column = null;
            if (preg_match('~#\d+\s+([^\s(]+)\((\d+)\)~', $line, $match)) {
                [$path, $lineNo] = [$match[1], (int) $match[2]];
            } elseif (preg_match('~\bat\s+(?:.+?\s+\()?((?:file://)?(?:/|[A-Za-z]:[\\\\/])[^():]+):(\d+)(?::(\d+))?\)?~', $line, $match)) {
                $path = preg_replace('~^file://~', '', $match[1]) ?? $match[1];
                $lineNo = (int) $match[2];
                $column = isset($match[3]) ? (int) $match[3] : null;
            }
            if ($path !== null && !preg_match('~(?:^|/)(?:vendor|node_modules)(?:/|$)~', str_replace('\\', '/', $path))) {
                $frame = ['path' => $path, 'line' => $lineNo, 'column' => $column];
                break;
            }
        }
        $stack = null;
        if ($json !== null) {
            foreach (['stack', 'trace', 'error.stack'] as $key) {
                $stack = self::nestedString($json, $key);
                if ($stack !== null) break;
            }
        }
        if ($stack === null && preg_match('/(?:^|\n)(\s*(?:#\d+\s+|at\s+|Caused by:|\[stacktrace\]).*)/s', $text, $match)) {
            $stack = $match[1];
        }
        return ['exception_class' => $exception, 'application_frame' => $frame, 'stack' => $stack];
    }

    private static function nestedString(array $data, string $path): ?string
    {
        $value = $data;
        foreach (explode('.', $path) as $part) {
            if (!is_array($value) || !array_key_exists($part, $value)) return null;
            $value = $value[$part];
        }
        return is_string($value) && $value !== '' ? $value : null;
    }

    /** @return array<string,string> */
    public static function correlations(mixed $value): array
    {
        $found = [];
        $walk = static function (mixed $item) use (&$walk, &$found): void {
            if (!is_array($item)) return;
            foreach ($item as $key => $child) {
                if (is_string($key) && preg_match('/^(?:request|trace|job|correlation|span|user)_id$/i', $key) && (is_string($child) || is_int($child))) {
                    $found[strtolower($key)] = (string) $child;
                }
                $walk($child);
            }
        };
        $walk($value);
        ksort($found);
        return $found;
    }
}

final class Discovery
{
    /** @return array{files:list<array{path:string,canonical:string,aliases:list<string>}>,duplicates:list<array{path:string,duplicate_of:string}>,warnings:list<array<string,mixed>>,partial:bool} */
    public static function discover(array $inputs): array
    {
        $candidates = [];
        $warnings = [];
        $partial = false;
        foreach ($inputs as $input) {
            if (!file_exists($input)) {
                throw new UsageError("Input path not found: {$input}");
            }
            if (is_link($input) && is_dir($input)) {
                throw new UsageError("Directory symlinks are not integrationd: {$input}");
            }
            if (is_file($input)) {
                $candidates[] = $input;
                continue;
            }
            if (!is_dir($input)) {
                throw new UsageError("Input path must be a regular file or directory: {$input}");
            }
            $inside = [];
            self::walk($input, $inside, $warnings, $partial);
            sort($inside, SORT_STRING);
            array_push($candidates, ...$inside);
        }

        $files = [];
        $byIdentity = [];
        $duplicates = [];
        foreach ($candidates as $path) {
            $canonical = realpath($path);
            if ($canonical === false || !is_file($canonical)) {
                throw new UsageError("Input path does not resolve to a regular file: {$path}");
            }
            $stat = @stat($canonical);
            $identity = $stat !== false && isset($stat['dev'], $stat['ino']) && (int) $stat['ino'] !== 0
                ? 'inode:' . $stat['dev'] . ':' . $stat['ino']
                : 'path:' . $canonical;
            if (isset($byIdentity[$identity])) {
                $index = $byIdentity[$identity];
                $files[$index]['aliases'][] = $path;
                $duplicates[] = ['path' => $path, 'duplicate_of' => $files[$index]['path']];
                continue;
            }
            $byIdentity[$identity] = count($files);
            $files[] = ['path' => $path, 'canonical' => $canonical, 'aliases' => []];
        }
        return ['files' => $files, 'duplicates' => $duplicates, 'warnings' => $warnings, 'partial' => $partial];
    }

    /** @param list<string> $inside @param list<array<string,mixed>> $warnings */
    private static function walk(string $directory, array &$inside, array &$warnings, bool &$partial): void
    {
        $entries = @scandir($directory);
        if ($entries === false) {
            $warnings[] = ['code' => 'read_failure', 'path' => $directory, 'line' => null, 'message' => 'Cannot read directory'];
            $partial = true;
            return;
        }
        foreach ($entries as $entry) {
            if ($entry === '.' || $entry === '..') continue;
            $path = rtrim($directory, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . $entry;
            if (is_link($path)) {
                if (is_file($path) && self::supportedName($entry)) $inside[] = $path;
                continue;
            }
            if (is_dir($path)) {
                self::walk($path, $inside, $warnings, $partial);
            } elseif (is_file($path) && self::supportedName($entry)) {
                $inside[] = $path;
            }
        }
    }

    private static function supportedName(string $name): bool
    {
        if (preg_match('/\.(?:gz|bz2|xz|zip|zst|lz4)$/i', $name)) return false;
        return preg_match('/(?:\.log(?:\..+)?|\.jsonl)$/i', $name) === 1;
    }
}

final class FormatDetector
{
    public static function detect(string $path, string $sample): string
    {
        if (str_ends_with(strtolower($path), '.jsonl')) return 'jsonl';
        $lines = preg_split('/\R/', $sample) ?: [];
        foreach ($lines as $line) {
            if (Parser::laravelHeader($line) !== null) return 'laravel';
            if (Parser::npmHeader($line) !== null) return 'npm';
            $trim = trim($line);
            if ($trim !== '' && ($trim[0] === '{' || $trim[0] === '[')) {
                try {
                    $decoded = json_decode($trim, true, 32, JSON_THROW_ON_ERROR);
                    if (is_array($decoded) && self::looksLikeLogJson($decoded)) return 'jsonl';
                } catch (JsonException) {}
            }
        }
        return 'generic';
    }

    private static function looksLikeLogJson(array $record): bool
    {
        foreach (['message', 'msg', 'body', 'level', 'severity', 'timestamp', 'time', '@timestamp'] as $key) {
            if (array_key_exists($key, $record)) return true;
        }
        return false;
    }
}

final class Parser
{
    /** @return array{raw_timestamp:string,level:string,message:string,context:?array}|null */
    public static function laravelHeader(string $line): ?array
    {
        if (!preg_match('/^\[([^]]+)]\s+([A-Za-z0-9_-]+)\.([A-Za-z]+):\s?(.*)$/s', rtrim($line, "\r\n"), $match)) return null;
        $message = $match[4];
        $context = null;
        if (preg_match('/^(.*?)(\s+\{.*\})$/s', $message, $parts)) {
            try {
                $decoded = json_decode($parts[2], true, 64, JSON_THROW_ON_ERROR);
                if (is_array($decoded)) {
                    $context = $decoded;
                    $message = $parts[1];
                }
            } catch (JsonException) {}
        }
        return ['raw_timestamp' => $match[1], 'level' => EventUtil::normalizeLevel($match[3]), 'message' => $message, 'context' => $context];
    }

    /** @return array{raw_timestamp:string,kind:string,level:?string,message:string}|null */
    public static function npmHeader(string $line): ?array
    {
        if (!preg_match('/^(\d{4}-\d{2}-\d{2}T\S+) \[(BACKEND-NPM|FRONTEND-NPM)](?:\s+(.*))?$/s', rtrim($line, "\r\n"), $match)) return null;
        $body = $match[3] ?? '';
        $level = null;
        if (preg_match('/^(TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|CRITICAL|ALERT|FATAL|EMERGENCY)(?:[ :]+)(.*)$/is', $body, $parts)) {
            $level = EventUtil::normalizeLevel($parts[1]);
            $body = $parts[2];
        } else {
            $level = EventUtil::inferLevel($body);
        }
        return ['raw_timestamp' => $match[1], 'kind' => $match[2], 'level' => $level, 'message' => $body];
    }

    /** @return Generator<int,array<string,mixed>> */
    public static function events($handle, string $path, string $format, array &$warnings, bool &$degraded): Generator
    {
        if ($format === 'jsonl') {
            yield from self::jsonl($handle, $path, $warnings, $degraded);
            return;
        }
        $builder = null;
        $lineNo = 0;
        while (($line = fgets($handle)) !== false) {
            $lineNo++;
            $header = match ($format) {
                'laravel' => self::laravelHeader($line),
                'npm' => self::npmHeader($line),
                default => self::genericHeader($line),
            };
            $isContinuation = $format === 'npm' && $header !== null && $builder !== null && $header['level'] === null && self::continuation($header['message']);
            if ($header !== null && !$isContinuation) {
                if ($builder !== null) yield self::finish($builder, $format);
                $builder = ['path' => $path, 'start' => $lineNo, 'end' => $lineNo, 'raw' => $line, 'header' => $header];
            } elseif ($builder === null) {
                $builder = ['path' => $path, 'start' => $lineNo, 'end' => $lineNo, 'raw' => $line, 'header' => null];
            } else {
                $builder['end'] = $lineNo;
                $builder['raw'] .= $line;
            }
        }
        if ($builder !== null) yield self::finish($builder, $format);
        if (!feof($handle)) {
            $warnings[] = self::warning('read_failure', $path, $lineNo ?: null, 'The file could not be read completely');
            $degraded = true;
        }
    }

    /** @return array<string,mixed>|null */
    private static function genericHeader(string $line): ?array
    {
        $clean = rtrim($line, "\r\n");
        if (preg_match('/^(?:\[)?(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)(?:])?[\s:|-]+(?:(TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|CRITICAL|ALERT|FATAL|EMERGENCY)\b[\s:|-]*)?(.*)$/is', $clean, $match)) {
            return ['raw_timestamp' => $match[1], 'level' => isset($match[2]) && $match[2] !== '' ? EventUtil::normalizeLevel($match[2]) : null, 'message' => $match[3]];
        }
        if (preg_match('/^(TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|CRITICAL|ALERT|FATAL|EMERGENCY)\b[\s:|-]+(.*)$/is', $clean, $match)) {
            return ['raw_timestamp' => null, 'level' => EventUtil::normalizeLevel($match[1]), 'message' => $match[2]];
        }
        $inferred = EventUtil::inferLevel($clean);
        if ($inferred !== null) {
            return ['raw_timestamp' => null, 'level' => $inferred, 'message' => $clean];
        }
        return null;
    }

    private static function continuation(string $body): bool
    {
        return $body === '' || preg_match('/^(?:\s+|at\s+|#\d+\s+|Caused by:|\[cause]|\[stacktrace]|\.\.\.|\^|[|>]|File\s+"|\w*Error\s*:)/i', $body) === 1;
    }

    /** @return array<string,mixed> */
    private static function finish(array $builder, string $format): array
    {
        $header = $builder['header'];
        $raw = $builder['raw'];
        $rawTimestamp = $header['raw_timestamp'] ?? null;
        $level = $header['level'] ?? null;
        $message = $header['message'] ?? trim($raw);
        if ($builder['end'] > $builder['start']) {
            $firstEnd = strpos($raw, "\n");
            if ($firstEnd !== false) {
                $continuation = substr($raw, $firstEnd + 1);
                if ($format === 'npm') {
                    $continuationLines = preg_split('/(?<=\n)/', $continuation, -1, PREG_SPLIT_NO_EMPTY) ?: [];
                    $continuation = implode('', array_map(static function (string $line): string {
                        $parsed = self::npmHeader($line);
                        return ($parsed['message'] ?? rtrim($line, "\r\n")) . (str_ends_with($line, "\n") ? "\n" : '');
                    }, $continuationLines));
                }
                $message .= "\n" . $continuation;
            }
        }
        if ($level === null) $level = EventUtil::inferLevel($message);
        $context = $header['context'] ?? null;
        $exception = EventUtil::exceptionData($message);
        $eventFormat = $header === null ? 'generic' : $format;
        return self::event($builder['path'], $eventFormat, $builder['start'], $builder['end'], $rawTimestamp, $level, $message, $raw, $context, $exception, [], $header['kind'] ?? 'log');
    }

    /** @return Generator<int,array<string,mixed>> */
    private static function jsonl($handle, string $path, array &$warnings, bool &$degraded): Generator
    {
        $lineNo = 0;
        while (($line = fgets($handle)) !== false) {
            $lineNo++;
            try {
                $decoded = json_decode(rtrim($line, "\r\n"), true, 128, JSON_THROW_ON_ERROR);
                if (!is_array($decoded)) throw new JsonException('record is not a JSON object');
                $rawTimestamp = self::firstValue($decoded, ['timestamp', '@timestamp', 'time', 'datetime']);
                $rawLevel = self::firstValue($decoded, ['level', 'severity', 'log.level']);
                $message = self::firstValue($decoded, ['message', 'msg', 'body', 'error.message']) ?? '';
                $stack = self::firstValue($decoded, ['stack', 'trace', 'error.stack']);
                if ($stack !== null && !str_contains($message, $stack)) $message .= ($message === '' ? '' : "\n") . $stack;
                $level = $rawLevel !== null ? EventUtil::normalizeLevel($rawLevel) : EventUtil::inferLevel($message);
                $context = $decoded['context'] ?? self::extraContext($decoded);
                if (!is_array($context)) $context = ['value' => $context];
                $exception = EventUtil::exceptionData($message, $decoded);
                $kind = self::firstValue($decoded, ['kind', 'event.kind']) ?? 'log';
                yield self::event($path, 'jsonl', $lineNo, $lineNo, $rawTimestamp, $level, $message, $line, $context, $exception, [], $kind, EventUtil::correlations($decoded));
            } catch (JsonException $error) {
                $degraded = true;
                $warnings[] = self::warning('malformed_jsonl_record', $path, $lineNo, $error->getMessage());
                $message = rtrim($line, "\r\n");
                yield self::event($path, 'generic', $lineNo, $lineNo, null, EventUtil::inferLevel($message), $message, $line, null, EventUtil::exceptionData($message), [self::warning('malformed_jsonl_record', $path, $lineNo, $error->getMessage())]);
            }
        }
        if (!feof($handle)) {
            $warnings[] = self::warning('read_failure', $path, $lineNo ?: null, 'The file could not be read completely');
            $degraded = true;
        }
    }

    private static function firstValue(array $data, array $paths): ?string
    {
        foreach ($paths as $path) {
            $value = $data;
            foreach (explode('.', $path) as $part) {
                if (!is_array($value) || !array_key_exists($part, $value)) continue 2;
                $value = $value[$part];
            }
            if (is_scalar($value) && (string) $value !== '') return (string) $value;
        }
        return null;
    }

    private static function extraContext(array $decoded): array
    {
        foreach (['timestamp', '@timestamp', 'time', 'datetime', 'level', 'severity', 'message', 'msg', 'body', 'stack', 'trace'] as $key) unset($decoded[$key]);
        return $decoded;
    }

    /** @return array<string,mixed> */
    private static function event(string $path, string $format, int $start, int $end, ?string $rawTimestamp, ?string $level, string $message, string $raw, ?array $context, array $exception, array $parseWarnings = [], string $kind = 'log', ?array $correlationIds = null): array
    {
        $timestamp = EventUtil::timestamp($rawTimestamp);
        return [
            'source_path' => $path,
            'source_format' => $format,
            'start_line' => $start,
            'end_line' => $end,
            'timestamp' => $timestamp['timestamp'],
            'timestamp_kind' => $timestamp['timestamp_kind'],
            'timestamp_raw' => $timestamp['timestamp_raw'],
            '_timestamp_sort' => $timestamp['sort'],
            'kind' => $kind,
            'level' => $level,
            'message' => rtrim($message, "\r\n"),
            'raw' => $raw,
            'exception_class' => $exception['exception_class'],
            'application_frame' => $exception['application_frame'],
            'stack' => $exception['stack'],
            'context' => $context,
            'correlation_ids' => $correlationIds ?? EventUtil::correlations($context),
            'parse_warnings' => $parseWarnings,
        ];
    }

    /** @return array{code:string,path:string,line:?int,message:string} */
    private static function warning(string $code, string $path, ?int $line, string $message): array
    {
        return compact('code', 'path', 'line', 'message');
    }
}

final class Fingerprint
{
    public static function for(array $event, string $mode): string
    {
        $canonical = $mode === 'smart' ? self::smart($event) : self::exact($event);
        return hash('sha256', $canonical);
    }

    private static function smart(array $event): string
    {
        $message = EventUtil::stripControls($event['message']);
        $message = preg_replace('/(?:^|\n)\s*(?:#\d+\s+|at\s+).*/s', '', $message) ?? $message;
        $message = preg_replace('/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i', '<uuid>', $message) ?? $message;
        $message = preg_replace('/\b((?:request|trace|job|correlation|span)[_-]?id\b["\']?\s*[=:]\s*["\']?)[A-Za-z0-9._:-]+/i', '$1<id>', $message) ?? $message;
        $message = preg_replace('/\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})\b/i', '<timestamp>', $message) ?? $message;
        $message = preg_replace('/\b0x[0-9a-f]+\b/i', '<address>', $message) ?? $message;
        $message = preg_replace('/\b[0-9a-f]{16,}\b/i', '<hex>', $message) ?? $message;
        $message = preg_replace('/[ \t]+/', ' ', trim($message)) ?? trim($message);
        $frame = $event['application_frame']['path'] ?? null;
        return self::json([$event['source_format'], $event['level'], $event['exception_class'], $message, $frame]);
    }

    private static function exact(array $event): string
    {
        $raw = str_replace("\r\n", "\n", EventUtil::stripControls($event['raw']));
        $raw = rtrim($raw, "\n");
        $raw = preg_replace('/^\[[^]]+]\s+(?=[A-Za-z0-9_-]+\.[A-Za-z]+:)/m', '', $raw) ?? $raw;
        $raw = preg_replace('/^\d{4}-\d{2}-\d{2}T\S+ \[(?:BACKEND-NPM|FRONTEND-NPM)] ?/m', '', $raw) ?? $raw;
        $raw = preg_replace('/^(?:\[)?\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?(?:])?[\s:|-]*/m', '', $raw) ?? $raw;
        if ($event['source_format'] === 'jsonl') {
            $raw = preg_replace('/("(?:timestamp|@timestamp|time|datetime)"\s*:\s*")[^"]*(")/i', '$1<timestamp>$2', $raw) ?? $raw;
        }
        return self::json([$event['source_format'], $event['level'], $event['context'], $event['exception_class'], $raw]);
    }

    private static function json(mixed $value): string
    {
        return json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION) ?: serialize($value);
    }
}

final class Selector
{
    public function __construct(private Options $options, private array $repositoryRules) {}

    /** @return array{selected:bool,positive:bool,ignored_by:?string,repository:bool} */
    public function select(array $event): array
    {
        $search = $event['raw'] . "\n" . $event['message'];
        $levelSelected = $event['level'] !== null && in_array($event['level'], $this->options->levels, true);
        $patternSelected = $this->options->pattern !== null && Regex::matches($this->options->pattern, $search);
        $positive = $levelSelected || $patternSelected;
        if (!$positive) return ['selected' => false, 'positive' => false, 'ignored_by' => null, 'repository' => false];
        foreach ($this->options->contains as $contains) {
            if (stripos($search, $contains) === false) return ['selected' => false, 'positive' => false, 'ignored_by' => null, 'repository' => false];
        }
        foreach ($this->options->ignores as $rule) {
            if (Regex::matches($rule, $search)) return ['selected' => false, 'positive' => true, 'ignored_by' => $rule, 'repository' => false];
        }
        if (!$this->options->includeNoise) {
            foreach ($this->repositoryRules as $rule) {
                if (Regex::matches($rule, $search)) return ['selected' => false, 'positive' => true, 'ignored_by' => $rule, 'repository' => true];
            }
        }
        return ['selected' => true, 'positive' => true, 'ignored_by' => null, 'repository' => false];
    }
}

final class Aggregator
{
    /** @param array<string,array<string,mixed>> $groups */
    public static function add(array &$groups, array $event, string $mode, int $sequence): void
    {
        $full = Fingerprint::for($event, $mode === 'none' ? 'exact' : $mode);
        $key = $mode === 'none' ? $full . ':' . $sequence : $full;
        $range = ['start_line' => $event['start_line'], 'end_line' => $event['end_line']];
        if (!isset($groups[$key])) {
            $groups[$key] = [
                '_fingerprint_full' => $full,
                'fingerprint' => substr($full, 0, 12),
                'count' => 0,
                'highest_severity' => $event['level'],
                'first_timestamp' => null,
                'latest_timestamp' => null,
                'unknown_timestamp_count' => 0,
                'occurrence_ranges' => ['first' => $range, 'latest' => $range],
                'total_source_span' => 0,
                'variants' => [],
                'exception_class' => $event['exception_class'],
                'application_frame' => $event['application_frame'],
                'context' => $event['context'],
                'correlation_ids' => $event['correlation_ids'],
                'representative' => $event,
                '_first_sort' => null,
                '_latest_sort' => null,
                '_clock_kinds' => [],
            ];
        }
        $group =& $groups[$key];
        $group['count']++;
        $group['total_source_span'] += $event['end_line'] - $event['start_line'] + 1;
        if (($event['level'] !== null ? EventUtil::SEVERITY[$event['level']] ?? -1 : -1) > ($group['highest_severity'] !== null ? EventUtil::SEVERITY[$group['highest_severity']] ?? -1 : -1)) {
            $group['highest_severity'] = $event['level'];
        }
        $timestampObject = self::timestampObject($event);
        if ($event['timestamp_kind'] === 'missing') {
            $group['unknown_timestamp_count']++;
        } else {
            $group['_clock_kinds'][$event['timestamp_kind']] = true;
            if ($group['first_timestamp'] === null || self::earlier($event, $group['_first_sort'])) {
                $group['first_timestamp'] = $timestampObject;
                $group['_first_sort'] = self::sortData($event);
                $group['occurrence_ranges']['first'] = $range;
            }
            if ($group['latest_timestamp'] === null || self::later($event, $group['_latest_sort'])) {
                $group['latest_timestamp'] = $timestampObject;
                $group['_latest_sort'] = self::sortData($event);
                $group['occurrence_ranges']['latest'] = $range;
                $group['representative'] = $event;
                $group['exception_class'] = $event['exception_class'];
                $group['application_frame'] = $event['application_frame'];
                $group['context'] = $event['context'];
                $group['correlation_ids'] = $event['correlation_ids'];
            }
        }
        if ($event['timestamp_kind'] === 'missing' && $event['start_line'] >= $group['representative']['start_line']) {
            $group['occurrence_ranges']['latest'] = $range;
            self::setRepresentative($group, $event);
        }
        self::addVariant($group, $event);
        unset($group);
    }

    /** @return array<string,mixed> */
    private static function timestampObject(array $event): array
    {
        return ['timestamp' => $event['timestamp'], 'timestamp_kind' => $event['timestamp_kind'], 'timestamp_raw' => $event['timestamp_raw']];
    }

    private static function sortData(array $event): array
    {
        return ['kind' => $event['timestamp_kind'], 'time' => $event['_timestamp_sort'], 'line' => $event['start_line']];
    }

    private static function earlier(array $event, ?array $against): bool
    {
        if ($against === null) return true;
        if ($event['timestamp_kind'] === $against['kind'] && $event['_timestamp_sort'] !== null) return $event['_timestamp_sort'] < $against['time'] || ($event['_timestamp_sort'] === $against['time'] && $event['start_line'] < $against['line']);
        return $event['start_line'] < $against['line'];
    }

    private static function later(array $event, ?array $against): bool
    {
        if ($against === null) return true;
        if ($event['timestamp_kind'] === $against['kind'] && $event['_timestamp_sort'] !== null) return $event['_timestamp_sort'] > $against['time'] || ($event['_timestamp_sort'] === $against['time'] && $event['start_line'] > $against['line']);
        return $event['start_line'] > $against['line'];
    }

    private static function addVariant(array &$group, array $event): void
    {
        $message = $event['message'];
        $group['variants'] = array_values(array_filter($group['variants'], static fn(array $variant): bool => $variant['message'] !== $message));
        $group['variants'][] = ['message' => $message, 'timestamp' => self::timestampObject($event), 'range' => ['start_line' => $event['start_line'], 'end_line' => $event['end_line']], '_sort' => self::sortData($event)];
        usort($group['variants'], static function (array $a, array $b): int {
            if ($a['_sort']['kind'] === $b['_sort']['kind'] && $a['_sort']['time'] !== null && $b['_sort']['time'] !== null) {
                $comparison = $b['_sort']['time'] <=> $a['_sort']['time'];
                if ($comparison !== 0) return $comparison;
            }
            return $b['_sort']['line'] <=> $a['_sort']['line'];
        });
        $group['variants'] = array_slice($group['variants'], 0, 3);
    }

    private static function setRepresentative(array &$group, array $event): void
    {
        $group['representative'] = $event;
        $group['exception_class'] = $event['exception_class'];
        $group['application_frame'] = $event['application_frame'];
        $group['context'] = $event['context'];
        $group['correlation_ids'] = $event['correlation_ids'];
    }

    /** @param array<string,array<string,mixed>> $groups @return list<array<string,mixed>> */
    public static function finish(array $groups, bool $chronologyComparable): array
    {
        $result = array_values($groups);
        usort($result, static function (array $a, array $b) use ($chronologyComparable): int {
            if ($chronologyComparable && $a['_latest_sort'] !== null && $b['_latest_sort'] !== null && $a['_latest_sort']['kind'] === $b['_latest_sort']['kind']) {
                $comparison = $b['_latest_sort']['time'] <=> $a['_latest_sort']['time'];
                if ($comparison !== 0) return $comparison;
            }
            return $b['representative']['start_line'] <=> $a['representative']['start_line'];
        });
        foreach ($result as &$group) {
            unset($group['_fingerprint_full'], $group['_first_sort'], $group['_latest_sort'], $group['_clock_kinds']);
            foreach ($group['variants'] as &$variant) unset($variant['_sort']);
            unset($variant);
            $group['chronology_comparable'] = $chronologyComparable;
            unset($group['representative']['_timestamp_sort']);
        }
        unset($group);
        return $result;
    }
}

final class Renderer
{
    public static function human(array $document, bool $full, bool $color, bool $interactive = false): string
    {
        $summary = $document['summary'];
        $bold = $color ? "\033[1m" : '';
        $dim = $color ? "\033[2m" : '';
        $red = $color ? "\033[31m" : '';
        $yellow = $color ? "\033[33m" : '';
        $blue = $color ? "\033[34m" : '';
        $magenta = $color ? "\033[35m" : '';
        $cyan = $color ? "\033[36m" : '';
        $whiteOnBlue = $color ? "\033[1;37;44m" : '';
        $reset = $color ? "\033[0m" : '';
        $lines = [];
        $lines[] = $color ? "{$whiteOnBlue} LOG ERRORS {$reset}" : "{$bold}Error log report{$reset}";
        $lines[] = sprintf('Scanned %d file(s), %d event(s); matched %d event(s) in %d group(s).', $summary['files_scanned'], $summary['events_scanned'], $summary['events_matched'], $summary['groups']);
        $noise = $document['noise_suppression'];
        if ($noise['repository_rules_applied']) {
            $lines[] = sprintf('Noise suppression: repository rules on (%d rules, %d event(s) ignored); CLI ignores: %d rule(s), %d event(s) ignored.', $noise['repository_rule_count'], $noise['repository_rules_matched'], $noise['cli_rule_count'], $noise['cli_rules_matched']);
        } else {
            $lines[] = sprintf('Noise suppression: repository rules off; CLI ignores: %d rule(s), %d event(s) ignored.', $noise['cli_rule_count'], $noise['cli_rules_matched']);
        }
        if ($interactive) {
            $lines[] = "{$dim}↑/↓ PgUp/PgDn scroll  / search  n/N matches  & filter  m+letter mark  mouse-select + terminal copy  q quit{$reset}";
        }
        if ($interactive) {
            $lines[] = "{$dim}" . str_repeat('─', 78) . "{$reset}";
        }
        $groupNumber = 0;
        foreach ($document['files'] as $file) {
            $lines[] = '';
            $path = EventUtil::terminalMetadata($file['path']);
            $format = EventUtil::terminalMetadata($file['format']);
            $lines[] = "{$bold}{$blue}{$path}{$reset} {$dim}[{$format}]{$reset}";
            if ($file['groups'] === []) {
                $lines[] = '  No matching events.';
                continue;
            }
            foreach ($file['groups'] as $group) {
                $groupNumber++;
                $level = EventUtil::terminalMetadata($group['highest_severity'] ?? 'UNLEVELLED');
                $shade = in_array($level, ['EMERGENCY', 'ALERT', 'CRITICAL', 'ERROR'], true) ? $red : $yellow;
                $range = $group['occurrence_ranges']['latest'];
                $lines[] = sprintf(
                    '  %s[%02d]%s  %s%s%s  %s%s%s  %s×%d%s  %slines %d-%d%s',
                    $bold,
                    $groupNumber,
                    $reset,
                    $shade,
                    $level,
                    $reset,
                    $cyan,
                    $group['fingerprint'],
                    $reset,
                    $magenta,
                    $group['count'],
                    $reset,
                    $dim,
                    $range['start_line'],
                    $range['end_line'],
                    $reset,
                );
                $message = trim(EventUtil::stripControls($group['representative']['message']));
                $firstLine = preg_split('/\R/', $message, 2)[0] ?? '';
                $lines[] = '        ' . self::headline($firstLine);
                if ($group['exception_class'] !== null) $lines[] = '        exception: ' . EventUtil::terminalMetadata($group['exception_class']);
                if ($group['application_frame'] !== null) {
                    $frame = $group['application_frame'];
                    $lines[] = '        frame: ' . EventUtil::terminalMetadata($frame['path']) . ($frame['line'] !== null ? ':' . $frame['line'] : '');
                }
                if ($full) {
                    $lines[] = '';
                    $lines[] = EventUtil::stripControls(rtrim($group['representative']['raw'], "\r\n"));
                    $lines[] = '';
                }
            }
        }
        if ($document['warnings'] !== []) {
            $lines[] = '';
            $lines[] = sprintf('%sWarnings: %d%s', $yellow, count($document['warnings']), $reset);
        }
        return implode("\n", $lines) . "\n";
    }

    private static function headline(string $message, int $limit = 240): string
    {
        $message = EventUtil::terminalMetadata($message);
        if (strlen($message) <= $limit) return $message;
        $headline = substr($message, 0, $limit - 1);
        if (preg_match('//u', $message) === 1) {
            while ($headline !== '' && preg_match('//u', $headline) !== 1) {
                $headline = substr($headline, 0, -1);
            }
        }
        return rtrim($headline) . '…';
    }

    public static function json(array $document): string
    {
        return json_encode($document, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR) . "\n";
    }

    public static function jsonl(array $document): string
    {
        $lines = [];
        foreach ($document['files'] as $file) {
            foreach ($file['groups'] as $group) {
                $lines[] = json_encode([
                    'schema_version' => 1,
                    'record_type' => 'error_group',
                    'source' => ['path' => $file['path'], 'format' => $file['format'], 'duplicate_input_paths' => $file['duplicate_input_paths']],
                    'noise_suppression' => $document['noise_suppression'],
                    'group' => $group,
                ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR);
            }
        }
        return $lines === [] ? '' : implode("\n", $lines) . "\n";
    }
}

final class Application
{
    /** @param list<string> $argv */
    public static function main(array $argv): int
    {
        try {
            $options = Options::parse($argv);
            if ($options->help) {
                self::write(STDOUT, Options::usage() . "\n");
                return 0;
            }
            $rulesPath = __DIR__ . '/ignore.patterns';
            if (!is_file($rulesPath) || !is_readable($rulesPath)) {
                throw new ResourceError("Required noise-rule file is missing or unreadable: {$rulesPath}");
            }
            $repositoryRules = self::loadRules($rulesPath);
            $discovery = Discovery::discover($options->paths);
            // All invocation-level validation completes before any machine output.
            $document = self::scan($options, $repositoryRules, $discovery);
            foreach ($document['warnings'] as $warning) {
                self::write(STDERR, sprintf("log-errors: warning: %s%s: %s\n", $warning['path'], $warning['line'] !== null ? ':' . $warning['line'] : '', $warning['message']));
            }
            $interactive = $options->format === 'human'
                && !$options->noPager
                && !$options->preview
                && self::interactiveTerminal()
                && self::findExecutable('less') !== null;
            $output = match ($options->format) {
                'json' => Renderer::json($document),
                'jsonl' => Renderer::jsonl($document),
                default => Renderer::human($document, $options->full, self::useColor($options->preview), $interactive),
            };
            if ($options->format === 'human') self::deliverHuman($output, $options);
            else self::write(STDOUT, $output);
            return $document['summary']['partial'] ? 3 : 0;
        } catch (UsageError $error) {
            self::write(STDERR, 'log-errors: ' . $error->getMessage() . "\nTry 'log-errors --help' for usage.\n");
            return 2;
        } catch (ResourceError $error) {
            self::write(STDERR, 'log-errors: ' . $error->getMessage() . "\n");
            return 4;
        } catch (Throwable $error) {
            self::write(STDERR, 'log-errors: unexpected failure: ' . $error->getMessage() . "\n");
            return 1;
        }
    }

    /** @return list<string> */
    private static function loadRules(string $path): array
    {
        $lines = file($path, FILE_IGNORE_NEW_LINES);
        if ($lines === false) throw new ResourceError("Cannot read required noise-rule file: {$path}");
        $rules = [];
        foreach ($lines as $lineNo => $line) {
            $line = trim($line);
            if ($line === '' || str_starts_with($line, '#')) continue;
            try {
                Regex::validate($line, "repository rule at line " . ($lineNo + 1));
            } catch (UsageError $error) {
                throw new ResourceError($error->getMessage());
            }
            $rules[] = $line;
        }
        return $rules;
    }

    private static function scan(Options $options, array $repositoryRules, array $discovery): array
    {
        $selector = new Selector($options, $repositoryRules);
        $warnings = $discovery['warnings'];
        $files = [];
        $summary = ['files_scanned' => 0, 'events_scanned' => 0, 'events_positive' => 0, 'events_matched' => 0, 'groups' => 0, 'partial' => $discovery['partial']];
        $repositoryIgnored = 0;
        $cliIgnored = 0;
        $sequence = 0;
        foreach ($discovery['files'] as $source) {
            $section = ['path' => $source['path'], 'canonical_path' => $source['canonical'], 'format' => 'unknown', 'events_scanned' => 0, 'matching_events' => 0, 'duplicate_input_paths' => $source['aliases'], 'ordering' => 'source-position', 'groups' => []];
            $handle = @fopen($source['canonical'], 'rb');
            if ($handle === false) {
                $warnings[] = ['code' => 'read_failure', 'path' => $source['path'], 'line' => null, 'message' => 'Cannot open file for reading'];
                $summary['partial'] = true;
                $files[] = $section;
                continue;
            }
            $summary['files_scanned']++;
            $format = self::detectStreamFormat($handle, $source['path'], $warnings, $summary['partial']);
            $section['format'] = $format;
            $groups = [];
            $clockKinds = [];
            $degraded = false;
            foreach (Parser::events($handle, $source['path'], $format, $warnings, $degraded) as $event) {
                $summary['events_scanned']++;
                $section['events_scanned']++;
                $result = $selector->select($event);
                if ($result['positive']) $summary['events_positive']++;
                if ($result['ignored_by'] !== null) {
                    if ($result['repository']) $repositoryIgnored++; else $cliIgnored++;
                }
                if (!$result['selected']) continue;
                $summary['events_matched']++;
                $section['matching_events']++;
                if ($event['timestamp_kind'] !== 'missing') $clockKinds[$event['timestamp_kind']] = true;
                Aggregator::add($groups, $event, $options->group, ++$sequence);
            }
            fclose($handle);
            if ($degraded) $summary['partial'] = true;
            $chronologyComparable = count($clockKinds) === 1;
            $section['ordering'] = $chronologyComparable ? 'timestamp-then-source-position' : 'source-position';
            $section['groups'] = Aggregator::finish($groups, $chronologyComparable);
            $summary['groups'] += count($section['groups']);
            $files[] = $section;
        }
        return [
            'schema_version' => 1,
            'summary' => $summary,
            'noise_suppression' => [
                'repository_rules_applied' => !$options->includeNoise,
                'repository_rule_count' => count($repositoryRules),
                'repository_rules_matched' => $options->includeNoise ? null : $repositoryIgnored,
                'cli_rule_count' => count($options->ignores),
                'cli_rules_matched' => $cliIgnored,
                'ignored_events' => $repositoryIgnored + $cliIgnored,
            ],
            'files' => $files,
            'duplicate_input_paths' => $discovery['duplicates'],
            'warnings' => $warnings,
        ];
    }

    /** @param resource $handle @param list<array<string,mixed>> $warnings */
    private static function detectStreamFormat($handle, string $path, array &$warnings, bool &$partial): string
    {
        if (str_ends_with(strtolower($path), '.jsonl')) return 'jsonl';
        $format = 'generic';
        while (($line = fgets($handle)) !== false) {
            $candidate = FormatDetector::detect($path, $line);
            if ($candidate !== 'generic') {
                $format = $candidate;
                break;
            }
        }
        if (!feof($handle) && $format === 'generic') {
            $warnings[] = ['code' => 'read_failure', 'path' => $path, 'line' => null, 'message' => 'The file could not be sampled completely'];
            $partial = true;
        }
        rewind($handle);
        return $format;
    }

    private static function useColor(bool $preview = false): bool
    {
        $term = getenv('TERM');
        if (getenv('NO_COLOR') !== false || $term === false || $term === '' || strtolower($term) === 'dumb') {
            return false;
        }
        return $preview || self::interactiveTerminal();
    }

    private static function interactiveTerminal(): bool
    {
        return function_exists('stream_isatty') && stream_isatty(STDOUT);
    }

    private static function deliverHuman(string $output, Options $options): void
    {
        if (!self::interactiveTerminal() || $options->noPager || $options->preview) {
            self::write(STDOUT, $output);
            return;
        }
        $less = self::findExecutable('less');
        if ($less === null) {
            self::write(STDERR, "log-errors: warning: less is unavailable; printing the report directly\n");
            self::write(STDOUT, $output);
            return;
        }
        $prompt = 'log-errors  %pB%  |  / search  n/N matches  & filter  m+letter mark  q quit';
        $pagerEnvironment = getenv();
        if (is_array($pagerEnvironment)) {
            // User LESS/LESSOPEN settings must not silently re-enable -F/-S or
            // preprocess the generated report. Other environment stays intact.
            $pagerEnvironment['LESS'] = '';
            $pagerEnvironment['LESSOPEN'] = '';
            $pagerEnvironment['LESSCLOSE'] = '';
        } else {
            $pagerEnvironment = null;
        }
        $process = proc_open(
            [$less, '-R', '-M', '-I', '-K', '-J', '-w', '-L', '-P', $prompt],
            [['pipe', 'r'], STDOUT, STDERR],
            $pipes,
            null,
            $pagerEnvironment,
        );
        if (!is_resource($process)) throw new RuntimeException('Could not start pager');
        $writeError = null;
        try {
            self::write($pipes[0], $output);
        } catch (Throwable $error) {
            $writeError = $error;
        } finally {
            fclose($pipes[0]);
        }
        $status = proc_close($process);
        if ($status !== 0) throw new RuntimeException("Pager failed with status {$status}");
        // A zero status after the input pipe closes means the user quit the
        // pager normally before consuming a large report.
        if ($writeError !== null) return;
    }

    private static function findExecutable(string $name): ?string
    {
        foreach (explode(PATH_SEPARATOR, getenv('PATH') ?: '') as $dir) {
            $path = rtrim($dir, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR . $name;
            if (is_file($path) && is_executable($path)) return $path;
        }
        return null;
    }

    private static function write($stream, string $value): void
    {
        $length = strlen($value);
        $written = 0;
        while ($written < $length) {
            $result = @fwrite($stream, substr($value, $written));
            if ($result === false || $result === 0) throw new RuntimeException('Output write failed');
            $written += $result;
        }
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (function_exists('pcntl_async_signals')) {
        pcntl_async_signals(true);
        pcntl_signal(SIGINT, static fn() => exit(130));
    }
    exit(Application::main($argv));
}
