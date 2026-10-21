<?php

declare(strict_types=1);

require dirname(__DIR__) . '/errors/core.php';

use LogErrors\Aggregator;
use LogErrors\EventUtil;
use LogErrors\Fingerprint;
use LogErrors\FormatDetector;
use LogErrors\Options;
use LogErrors\Parser;
use LogErrors\Regex;
use LogErrors\Selector;
use LogErrors\UsageError;

$tests = 0;

function check(bool $condition, string $message): void
{
    global $tests;
    $tests++;
    if (!$condition) {
        fwrite(STDERR, "not ok {$tests} - {$message}\n");
        exit(1);
    }
    fwrite(STDOUT, "ok {$tests} - {$message}\n");
}

function parseText(string $text, string $format): array
{
    $handle = fopen('php://temp', 'w+b');
    fwrite($handle, $text);
    rewind($handle);
    $warnings = [];
    $degraded = false;
    $events = iterator_to_array(Parser::events($handle, 'fixture.log', $format, $warnings, $degraded));
    fclose($handle);
    return [$events, $warnings, $degraded];
}

function fakeEvent(string $raw, string $message, ?string $level = 'ERROR', string $format = 'generic', int $line = 1, ?string $timestamp = null, string $kind = 'missing'): array
{
    return [
        'source_path' => 'fixture.log', 'source_format' => $format,
        'start_line' => $line, 'end_line' => $line,
        'timestamp' => $timestamp, 'timestamp_kind' => $kind, 'timestamp_raw' => $timestamp,
        '_timestamp_sort' => $timestamp === null ? null : (float) strtotime($timestamp),
        'kind' => 'log', 'level' => $level, 'message' => $message, 'raw' => $raw,
        'exception_class' => null, 'application_frame' => null, 'stack' => null,
        'context' => null, 'correlation_ids' => [], 'parse_warnings' => [],
    ];
}

check(EventUtil::normalizeLevel('warn') === 'WARNING', 'WARN normalizes to WARNING');
check(EventUtil::normalizeLevel('fatal') === 'EMERGENCY', 'FATAL normalizes to EMERGENCY');
check(EventUtil::inferLevel('ordinary error count is 2') === null, 'unlevelled inference is conservative');
check(EventUtil::inferLevel('Fatal error: Uncaught RuntimeException: failed') === 'EMERGENCY', 'fatal exception is inferred');

$utc = EventUtil::timestamp('2026-09-03T09:00:00+01:00');
check($utc['timestamp_kind'] === 'utc' && str_starts_with($utc['timestamp'], '2026-09-03T08:00:00'), 'offset timestamp normalizes to UTC');
$local = EventUtil::timestamp('2026-09-03 09:00:00');
check($local['timestamp_kind'] === 'local-unknown-offset', 'naive timestamp keeps unknown offset semantics');
check(EventUtil::timestamp(null)['timestamp_kind'] === 'missing', 'missing timestamp is explicit');
check(EventUtil::timestamp('2026-02-31T09:00:00Z')['timestamp'] === null, 'invalid calendar timestamps are not normalized silently');
$nano = EventUtil::timestamp('2026-09-03T09:00:00.123456789Z');
check($nano['timestamp'] === '2026-09-03T09:00:00.123456Z' && $nano['timestamp_raw'] === '2026-09-03T09:00:00.123456789Z', 'high-precision timestamps retain raw text and normalize safely');
check(EventUtil::terminalMetadata("bad\033[31m\npath") === 'bad\\npath', 'terminal metadata strips ANSI and escapes line breaks');
check(FormatDetector::detect('ambiguous.log', "ordinary startup text\n") === 'generic', 'ambiguous input falls back to generic without degradation');

$laravel = "[2026-09-03 09:00:00] local.ERROR: RuntimeException: failed {\"trace_id\":\"trace-1\"}\n#0 /vendor/a.php(1): x()\n#1 /app/src/a.php(22): y()\n";
check(FormatDetector::detect('laravel.log', $laravel) === 'laravel', 'Laravel format detection');
[$events] = parseText($laravel, 'laravel');
check(count($events) === 1 && $events[0]['end_line'] === 3, 'Laravel multiline event stays intact');
check($events[0]['application_frame']['path'] === '/app/src/a.php', 'first non-vendor Laravel frame is extracted');
check($events[0]['correlation_ids']['trace_id'] === 'trace-1', 'Laravel context and correlation are decoded');
[$events] = parseText("orphan preamble\n" . $laravel, 'laravel');
check($events[0]['source_format'] === 'generic' && $events[1]['source_format'] === 'laravel', 'Laravel preambles remain generic events');

$npm = "2026-09-03T09:00:00.000Z [FRONTEND-NPM] ERROR TypeError: failed\n2026-09-03T09:00:00.001Z [FRONTEND-NPM]     at run (/app/src/a.js:8:2)\n2026-09-03T09:00:01.000Z [FRONTEND-NPM] INFO ready\n";
check(FormatDetector::detect('frontend-npm.log', $npm) === 'npm', 'captured npm format detection');
[$events] = parseText($npm, 'npm');
check(count($events) === 2 && $events[0]['end_line'] === 2, 'npm stack continuation attaches to originating event');
check(str_contains($events[0]['message'], 'at run') && !str_contains($events[0]['message'], '[FRONTEND-NPM]'), 'npm semantic message removes capture envelopes');
check($events[0]['kind'] === 'FRONTEND-NPM', 'npm capture source is retained as event kind');
[$events] = parseText("2026-09-03T09:00:00.000Z [FRONTEND-NPM] INFO ready\n2026-09-03T09:00:01.000Z [FRONTEND-NPM] TypeError: exploded\n", 'npm');
check(count($events) === 2 && $events[1]['level'] === 'ERROR', 'unlevelled npm exceptions start inferred error events');

$json = "{\"timestamp\":\"2026-09-03T09:00:00Z\",\"level\":\"ERROR\",\"message\":\"failed\",\"stack\":\"Error: failed\\n at run (/app/x.js:2:1)\"}\n";
check(FormatDetector::detect('events.txt', $json) === 'jsonl', 'complete JSON record selects JSONL format');
[$events] = parseText($json, 'jsonl');
check(str_contains($events[0]['message'], 'at run') && str_contains($events[0]['raw'], '\\n at run'), 'JSON stack field and raw record are retained');
$jsonMetadata = "{\"timestamp\":\"2026-09-03T09:00:00Z\",\"level\":\"ERROR\",\"message\":\"failed\",\"kind\":\"worker\",\"trace_id\":\"root-trace\",\"context\":{\"job_id\":\"nested-job\"}}\n";
[$events] = parseText($jsonMetadata, 'jsonl');
check($events[0]['kind'] === 'worker' && $events[0]['correlation_ids'] === ['job_id' => 'nested-job', 'trace_id' => 'root-trace'], 'JSON kind and root/nested correlations are retained');

[$events, $warnings, $degraded] = parseText("{bad json Error: broken\n", 'jsonl');
check($degraded && count($warnings) === 1 && $events[0]['source_format'] === 'generic', 'malformed declared JSONL degrades per record');
check($events[0]['parse_warnings'][0]['code'] === 'malformed_jsonl_record', 'malformed JSONL warning is retained on its fallback event');

[$events] = parseText("orphan preamble\n2026-09-03 09:00:00 ERROR failed\n  continuation\nError: inferred boundary\n", 'generic');
check(count($events) === 3 && $events[0]['level'] === null, 'generic parser preserves orphan preamble and conservative boundaries');
check($events[1]['end_line'] === 3 && str_contains($events[1]['raw'], 'continuation'), 'generic parser retains continuation lines');

$options = Options::parse(['log-errors', '--level', 'WARN,FATAL', '--contains', 'Alpha', '--ignore', 'known', '--pattern', 'failure', 'x.log']);
check($options->levels === ['WARNING', 'EMERGENCY'], 'level option parses and normalizes');
$preview = Options::parse(['log-errors', '--preview', 'x.log']);
check($preview->preview && !$preview->noPager, 'preview flag parses independently');
$selector = new Selector($options, []);
check($selector->select(fakeEvent('WARNING Alpha failure', 'Alpha failure', 'WARNING'))['selected'], 'positive selection composes level, pattern, and contains');
check(!$selector->select(fakeEvent('WARNING Alpha known failure', 'Alpha known failure', 'WARNING'))['selected'], 'CLI ignore runs after positive selection');
check(!$selector->select(fakeEvent('WARNING failure', 'failure', 'WARNING'))['selected'], 'every contains constraint is required');

$badRegex = false;
try { Regex::validate('(', '--pattern'); } catch (UsageError) { $badRegex = true; }
check($badRegex, 'invalid PCRE is rejected');
check(Regex::matches('failure', "bad\xFF FAILURE"), 'PCRE matching remains reliable for non-UTF-8 log bytes');

$smartA = fakeEvent('ERROR request_id=req-1 id 123', 'request_id=req-1 id 123');
$smartB = fakeEvent('ERROR request_id=req-2 id 123', 'request_id=req-2 id 123');
$smartC = fakeEvent('ERROR request_id=req-2 id 124', 'request_id=req-2 id 124');
check(Fingerprint::for($smartA, 'smart') === Fingerprint::for($smartB, 'smart'), 'smart fingerprint normalizes recognized identifiers');
check(Fingerprint::for($smartB, 'smart') !== Fingerprint::for($smartC, 'smart'), 'smart fingerprint preserves general numbers');
$smartJsonA = fakeEvent('ERROR {"request_id":"req-1","uuid":"018f47a2-7b10-7cc1-8d7a-123456789abc"}', '{"request_id":"req-1","uuid":"018f47a2-7b10-7cc1-8d7a-123456789abc"}');
$smartJsonB = fakeEvent('ERROR {"request_id":"req-2","uuid":"018f47a2-7b10-7cc1-8d7a-abcdefabcdef"}', '{"request_id":"req-2","uuid":"018f47a2-7b10-7cc1-8d7a-abcdefabcdef"}');
check(Fingerprint::for($smartJsonA, 'smart') === Fingerprint::for($smartJsonB, 'smart'), 'smart fingerprint normalizes JSON IDs and modern UUID variants');
$exactA = fakeEvent("[2026-09-03 09:00:00] local.ERROR: exact\n", 'exact', 'ERROR', 'laravel');
$exactB = fakeEvent("[2026-09-03 10:00:00] local.ERROR: exact\r\n", 'exact', 'ERROR', 'laravel');
check(Fingerprint::for($exactA, 'exact') === Fingerprint::for($exactB, 'exact'), 'exact fingerprint ignores timestamp, CRLF, and final newline');
$exactC = fakeEvent("[2026-09-03 10:00:00] local.ERROR:  exact\n", ' exact', 'ERROR', 'laravel');
check(Fingerprint::for($exactB, 'exact') !== Fingerprint::for($exactC, 'exact'), 'exact fingerprint preserves whitespace');
$genericExactA = fakeEvent("2026-09-03T10:00:00Z ERROR exact\n", 'exact');
$genericExactB = fakeEvent("2026-09-03T11:00:00Z ERROR exact\n", 'exact');
check(Fingerprint::for($genericExactA, 'exact') === Fingerprint::for($genericExactB, 'exact'), 'exact fingerprint ignores generic timestamps');
$stackSmartA = fakeEvent("ERROR failed\n at run (/app/src/a.js:10:2)\n", "failed\n at run (/app/src/a.js:10:2)");
$stackSmartB = fakeEvent("ERROR failed\n at run (/app/src/a.js:20:2)\n", "failed\n at run (/app/src/a.js:20:2)");
$stackSmartA['application_frame'] = ['path' => '/app/src/a.js', 'line' => 10, 'column' => 2];
$stackSmartB['application_frame'] = ['path' => '/app/src/a.js', 'line' => 20, 'column' => 2];
check(Fingerprint::for($stackSmartA, 'smart') === Fingerprint::for($stackSmartB, 'smart'), 'smart fingerprint ignores stack frame line volatility');

$groups = [];
Aggregator::add($groups, fakeEvent('ERROR same', 'same', 'ERROR', 'generic', 2, '2026-09-03T09:00:00Z', 'utc'), 'smart', 1);
Aggregator::add($groups, fakeEvent('ERROR same', 'same', 'ERROR', 'generic', 8, '2026-09-03T10:00:00Z', 'utc'), 'smart', 2);
$finished = Aggregator::finish($groups, true);
check($finished[0]['count'] === 2 && $finished[0]['occurrence_ranges']['latest']['start_line'] === 8, 'aggregation retains count and latest occurrence');
check(strlen($finished[0]['fingerprint']) === 12 && $finished[0]['highest_severity'] === 'ERROR', 'group exposes short fingerprint and severity');

$missingGroups = [];
$missingA = fakeEvent('ERROR same', 'same', 'ERROR', 'generic', 1);
$missingA['context'] = ['request_id' => 'old'];
$missingA['correlation_ids'] = ['request_id' => 'old'];
$missingB = fakeEvent('ERROR same', 'same', 'ERROR', 'generic', 2);
$missingB['context'] = ['request_id' => 'new'];
$missingB['correlation_ids'] = ['request_id' => 'new'];
Aggregator::add($missingGroups, $missingA, 'smart', 1);
Aggregator::add($missingGroups, $missingB, 'smart', 2);
$missingFinished = Aggregator::finish($missingGroups, false);
check($missingFinished[0]['representative']['start_line'] === 2 && $missingFinished[0]['context']['request_id'] === 'new', 'missing-timestamp representative metadata stays synchronized');
check($missingFinished[0]['chronology_comparable'] === false, 'timestamp-free groups make no chronology claim');

$none = [];
Aggregator::add($none, fakeEvent('ERROR same', 'same'), 'none', 1);
Aggregator::add($none, fakeEvent('ERROR same', 'same'), 'none', 2);
check(count(Aggregator::finish($none, false)) === 2, 'none grouping emits each occurrence');

fwrite(STDOUT, "1..{$tests}\n");
