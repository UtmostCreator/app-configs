<?php

declare(strict_types=1);

namespace Tests;

use PHPUnit\Framework\TestCase;

class AiCatalogLibTest extends TestCase
{
    // ---- aiNormalizePath ----

    public function testNormalizePathConvertsBackslashes(): void
    {
        $this->assertSame('foo/bar/baz', aiNormalizePath('foo\\bar\\baz'));
    }

    public function testNormalizePathLeavesForwardSlashesUnchanged(): void
    {
        $this->assertSame('foo/bar/baz', aiNormalizePath('foo/bar/baz'));
    }

    public function testNormalizePathEmptyString(): void
    {
        $this->assertSame('', aiNormalizePath(''));
    }

    // ---- aiAbsolutePath ----

    public function testAbsolutePathCombinesRootAndRelative(): void
    {
        $sep = DIRECTORY_SEPARATOR;
        $this->assertSame('/tmp' . $sep . 'foo' . $sep . 'bar', aiAbsolutePath('/tmp', 'foo/bar'));
    }

    public function testAbsolutePathNormalizesRelativeSeparators(): void
    {
        $sep = DIRECTORY_SEPARATOR;
        $this->assertSame('/tmp' . $sep . 'a' . $sep . 'b', aiAbsolutePath('/tmp', 'a/b'));
    }

    // ---- aiNormalizeGeneratedContent ----

    public function testNormalizeGeneratedContentConvertsCarriageReturns(): void
    {
        $this->assertSame("line1\nline2\n", aiNormalizeGeneratedContent("line1\r\nline2\r\n"));
    }

    public function testNormalizeGeneratedContentLeavesLfUnchanged(): void
    {
        $this->assertSame("line1\nline2\n", aiNormalizeGeneratedContent("line1\nline2\n"));
    }

    public function testNormalizeGeneratedContentEmptyString(): void
    {
        $this->assertSame('', aiNormalizeGeneratedContent(''));
    }

    // ---- aiParseFrontMatter ----

    public function testParseFrontMatterExtractsKeyValues(): void
    {
        $content = "---\ntitle: Hello World\nauthor: Alice\n---\nContent here";
        $result = aiParseFrontMatter($content);
        $this->assertSame('Hello World', $result['title']);
        $this->assertSame('Alice', $result['author']);
    }

    public function testParseFrontMatterReturnsEmptyWhenNoMarker(): void
    {
        $this->assertSame([], aiParseFrontMatter('No front matter here'));
    }

    public function testParseFrontMatterReturnsEmptyWhenNoClosingMarker(): void
    {
        $this->assertSame([], aiParseFrontMatter("---\ntitle: Unclosed\n"));
    }

    public function testParseFrontMatterStripsDoubleQuotes(): void
    {
        $content = "---\ntitle: \"Quoted Title\"\n---\n";
        $result = aiParseFrontMatter($content);
        $this->assertSame('Quoted Title', $result['title']);
    }

    public function testParseFrontMatterSkipsLinesWithoutColon(): void
    {
        $content = "---\ntitle: Valid\nno-colon-line\n---\n";
        $result = aiParseFrontMatter($content);
        $this->assertSame('Valid', $result['title']);
        $this->assertArrayNotHasKey('no-colon-line', $result);
    }

    // ---- aiExtractTitle ----

    public function testExtractTitleFindsH1(): void
    {
        $this->assertSame('My Title', aiExtractTitle("# My Title\n\nParagraph.", 'fallback'));
    }

    public function testExtractTitleReturnsFallbackWhenNoH1(): void
    {
        $this->assertSame('fallback', aiExtractTitle("No heading here", 'fallback'));
    }

    public function testExtractTitleFindsH1InMiddleOfContent(): void
    {
        $this->assertSame('Mid Title', aiExtractTitle("Some text\n# Mid Title\nMore text", 'fallback'));
    }

    public function testExtractTitleTrimsWhitespace(): void
    {
        $this->assertSame('Trimmed', aiExtractTitle("#  Trimmed  \n", 'fallback'));
    }

    // ---- aiSummarizeMarkdown ----

    public function testSummarizeMarkdownReturnsFirstParagraph(): void
    {
        $this->assertSame(
            'First paragraph.',
            aiSummarizeMarkdown("# Heading\n\nFirst paragraph.\n\nSecond paragraph.")
        );
    }

    public function testSummarizeMarkdownSkipsHrule(): void
    {
        $this->assertSame('Real content.', aiSummarizeMarkdown("---\nReal content."));
    }

    public function testSummarizeMarkdownSkipsHeadings(): void
    {
        $this->assertSame('Body text.', aiSummarizeMarkdown("# Heading\n## Sub\nBody text."));
    }

    public function testSummarizeMarkdownReturnsNullWhenOnlyHeadings(): void
    {
        $this->assertNull(aiSummarizeMarkdown("# Only heading\n\n---\n"));
    }

    // ---- aiResource ----

    public function testResourceBuildsCorrectArray(): void
    {
        $result = aiResource('root', 'doc', 'My Doc', 'docs/my-doc.md', 'A description', 'github-copilot');
        $this->assertSame('root', $result['scope']);
        $this->assertSame('doc', $result['type']);
        $this->assertSame('My Doc', $result['name']);
        $this->assertSame('docs/my-doc.md', $result['path']);
        $this->assertSame('A description', $result['description']);
        $this->assertSame('github-copilot', $result['runtime']);
    }

    public function testResourceNormalizesBackslashesInPath(): void
    {
        $result = aiResource('root', 'doc', 'Doc', 'docs\\sub\\file.md');
        $this->assertSame('docs/sub/file.md', $result['path']);
    }

    public function testResourceDefaultsOptionalParamsToNull(): void
    {
        $result = aiResource('root', 'doc', 'Doc', 'path.md');
        $this->assertNull($result['description']);
        $this->assertNull($result['runtime']);
    }

    public function testResourceMergesExtraFields(): void
    {
        $result = aiResource('root', 'doc', 'Doc', 'path.md', null, null, ['custom' => 'value', 'num' => 42]);
        $this->assertSame('value', $result['custom']);
        $this->assertSame(42, $result['num']);
    }

    // ---- aiDetectExampleRuntime ----

    public function testDetectExampleRuntimeGitHubCopilot(): void
    {
        $files = ['repo/.github/copilot-instructions.md', 'repo/README.md'];
        $this->assertSame('github-copilot', aiDetectExampleRuntime($files));
    }

    public function testDetectExampleRuntimeOpenCode(): void
    {
        $files = ['repo/.opencode/config.toml', 'repo/README.md'];
        $this->assertSame('opencode', aiDetectExampleRuntime($files));
    }

    public function testDetectExampleRuntimeDual(): void
    {
        $files = ['repo/.github/copilot-instructions.md', 'repo/.opencode/config.toml'];
        $this->assertSame('dual-runtime', aiDetectExampleRuntime($files));
    }

    public function testDetectExampleRuntimeReference(): void
    {
        $files = ['repo/README.md', 'repo/AGENTS.md'];
        $this->assertSame('reference', aiDetectExampleRuntime($files));
    }

    public function testDetectExampleRuntimeEmptyFiles(): void
    {
        $this->assertSame('reference', aiDetectExampleRuntime([]));
    }

    // ---- aiEscapeTable ----

    public function testEscapeTableReplacesBar(): void
    {
        $this->assertSame('foo\\|bar', aiEscapeTable('foo|bar'));
    }

    public function testEscapeTableLeavesNonBarUnchanged(): void
    {
        $this->assertSame('hello world', aiEscapeTable('hello world'));
    }

    public function testEscapeTableMultipleBars(): void
    {
        $this->assertSame('a\\|b\\|c', aiEscapeTable('a|b|c'));
    }

    // ---- aiNormalizeExampleTitle ----

    public function testNormalizeExampleTitleStripsRepositoryInstructions(): void
    {
        $this->assertSame('My Project', aiNormalizeExampleTitle('My Project - Repository Instructions'));
    }

    public function testNormalizeExampleTitleStripsSharedAgentGuidance(): void
    {
        $this->assertSame('My Project', aiNormalizeExampleTitle('My Project - Shared Agent Guidance'));
    }

    public function testNormalizeExampleTitleLeavesOtherTitlesUnchanged(): void
    {
        $this->assertSame('My Project', aiNormalizeExampleTitle('My Project'));
    }

    public function testNormalizeExampleTitleTrims(): void
    {
        $this->assertSame('My Project', aiNormalizeExampleTitle('  My Project  '));
    }

    // ---- aiPrettifyExampleSlug ----

    public function testPrettifyExampleSlugCapitalizesWords(): void
    {
        $this->assertSame('My Example Repo', aiPrettifyExampleSlug('my-example-repo'));
    }

    public function testPrettifyExampleSlugSingleWord(): void
    {
        $this->assertSame('Example', aiPrettifyExampleSlug('example'));
    }

    // ---- aiCountExampleAssets ----

    public function testCountExampleAssetsCountsAgents(): void
    {
        $files = ['foo.agent.md', 'bar.agent.md', 'README.md'];
        $counts = aiCountExampleAssets($files);
        $this->assertSame(2, $counts['agents']);
        $this->assertSame(0, $counts['instructions']);
    }

    public function testCountExampleAssetsCountsInstructions(): void
    {
        $files = ['path.instructions.md', 'other.instructions.md'];
        $counts = aiCountExampleAssets($files);
        $this->assertSame(2, $counts['instructions']);
    }

    public function testCountExampleAssetsCountsSkills(): void
    {
        $files = ['/some/path/SKILL.md'];
        $counts = aiCountExampleAssets($files);
        $this->assertSame(1, $counts['skills']);
    }

    public function testCountExampleAssetsCountsCapabilities(): void
    {
        $files = ['/docs/ai/capabilities/foo/CAPABILITY.md'];
        $counts = aiCountExampleAssets($files);
        $this->assertSame(1, $counts['capabilities']);
    }

    public function testCountExampleAssetsReturnsZeroesForEmpty(): void
    {
        $counts = aiCountExampleAssets([]);
        foreach (['agents', 'instructions', 'prompts', 'commands', 'skills', 'capabilities'] as $key) {
            $this->assertSame(0, $counts[$key], "Expected 0 for key '$key'");
        }
    }

    // ---- aiRenderTableRows ----

    public function testRenderTableRowsIncludesHeaderAndSeparator(): void
    {
        $lines = aiRenderTableRows([], 'root');
        $this->assertSame('| Type | Name | Path | Description |', $lines[0]);
        $this->assertSame('| --- | --- | --- | --- |', $lines[1]);
    }

    public function testRenderTableRowsFiltersOutWrongScope(): void
    {
        $resources = [
            aiResource('root', 'doc', 'Doc A', 'docs/a.md', 'Desc A'),
            aiResource('package', 'doc', 'Doc B', 'docs/b.md', 'Desc B'),
        ];
        $lines = aiRenderTableRows($resources, 'root');
        $this->assertCount(3, $lines); // header + separator + 1 data row
        $this->assertStringContainsString('Doc A', $lines[2]);
        $this->assertStringNotContainsString('Doc B', implode("\n", $lines));
    }

    public function testRenderTableRowsIncludesPathAndDescription(): void
    {
        $resources = [aiResource('root', 'capability', 'My Cap', 'docs/cap.md', 'Cap description')];
        $lines = aiRenderTableRows($resources, 'root');
        $this->assertStringContainsString('docs/cap.md', $lines[2]);
        $this->assertStringContainsString('Cap description', $lines[2]);
    }

    // ---- aiFindExampleReadme ----

    public function testFindExampleReadmeFindsFirstReadme(): void
    {
        $files = ['repo/src/file.php', 'repo/README.md', 'repo/docs/OTHER.md'];
        $this->assertSame('repo/README.md', aiFindExampleReadme($files));
    }

    public function testFindExampleReadmeReturnsNullWhenAbsent(): void
    {
        $this->assertNull(aiFindExampleReadme(['file.md', 'AGENTS.md']));
    }

    // ---- aiCollectExampleEntrypoints (string-path-only, using real repo root) ----

    public function testCollectExampleEntrypointsFindsKnownSuffixes(): void
    {
        $root = aiRepoRoot();
        $relDir = 'packages/ai-universal-rules/examples/generic-placeholder-repo';
        $prefix = $root . '/' . $relDir . '/';
        $files = [
            $prefix . 'README.md',
            $prefix . 'AGENTS.md',
            $prefix . 'docs/ai/workflow.md',
            $prefix . 'unrelated.txt',
        ];
        $entrypoints = aiCollectExampleEntrypoints($files, $relDir);
        $this->assertContains('README.md', $entrypoints);
        $this->assertContains('AGENTS.md', $entrypoints);
        $this->assertNotContains('unrelated.txt', $entrypoints);
    }

    public function testCollectExampleEntrypointsMaxSix(): void
    {
        $root = aiRepoRoot();
        $relDir = 'packages/ai-universal-rules/examples/worked-dual-tool-repo';
        $prefix = $root . '/' . $relDir . '/';
        // Feed more than 6 matching paths
        $files = [
            $prefix . 'README.md',
            $prefix . 'AGENTS.md',
            $prefix . 'CLAUDE.md',
            $prefix . '.github/copilot-instructions.md',
            $prefix . 'docs/ai/project-context.md',
            $prefix . 'docs/ai/workflow.md',
            // 7th would exceed limit but there's no 7th suffix
        ];
        $entrypoints = aiCollectExampleEntrypoints($files, $relDir);
        $this->assertLessThanOrEqual(6, count($entrypoints));
    }
}
