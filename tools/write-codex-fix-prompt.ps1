[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder,
    [Parameter(Mandatory)]
    [int]$IterationIndex,
    [Parameter(Mandatory)]
    [int]$MaxIterations,
    [string]$Goal = '',
    [string]$TaskId = '',
    [string]$TestLevel = 'none',
    [switch]$SkipE2E,
    [switch]$DryRun,
    # Path to the test-summary.json from the PREVIOUS iteration. Optional.
    [string]$PreviousTestSummary = '',
    # Path to the claude-review.md from the PREVIOUS iteration. Optional.
    [string]$PreviousClaudeReview = '',
    # Output path for the fix prompt. Defaults to <RunFolder>/codex-fix-prompt.md.
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RunFolder)) {
    throw "write-codex-fix-prompt: run folder does not exist: $RunFolder"
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $RunFolder '..\..')).ProviderPath

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $RunFolder 'codex-fix-prompt.md'
}

function Read-Artifact {
    param([string]$Path, [int]$MaxLines = 0)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { return $null }
    if ($MaxLines -gt 0) {
        $arr = $content -split "`r?`n"
        if ($arr.Count -gt $MaxLines) {
            $arr = $arr[0..($MaxLines - 1)]
            $content = ($arr -join [Environment]::NewLine) + [Environment]::NewLine + '... (truncated)'
        }
    }
    return $content.TrimEnd()
}

function Block-OrPlaceholder {
    param([string]$Content, [string]$Placeholder = '(none captured)')
    if ([string]::IsNullOrWhiteSpace($Content)) { return $Placeholder }
    return $Content
}

# Defensive: redact any trailing secret-like markers if they ever leak in.
function Redact-IfSecret {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $Line }
    $patterns = @('(^|/)\.env(\.|$)', '\.pem$', '\.key$', 'secret', 'credentials')
    foreach ($p in $patterns) {
        if ($Line -match $p) { return '[redacted secret-like path]' }
    }
    return $Line
}

# Extract failed-test summary lines from a test-summary.json content.
function Get-FailedTestsSummary {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        $obj = (Get-Content -LiteralPath $Path -Raw) | ConvertFrom-Json
    } catch {
        return $null
    }
    if ($null -eq $obj) { return $null }
    $rows = @()
    if ($obj.PSObject.Properties.Name -contains 'results' -and $null -ne $obj.results) {
        foreach ($r in $obj.results) {
            if ($null -eq $r) { continue }
            $passed = [bool]$r.passed
            $skipped = [bool]$r.skipped
            if ($passed -and -not $skipped) { continue }
            $id      = if ($null -ne $r.id)       { [string]$r.id }       else { '' }
            $level   = if ($null -ne $r.level)    { [string]$r.level }    else { '' }
            $cmd     = if ($null -ne $r.command)  { [string]$r.command }  else { '' }
            $exit    = if ($null -ne $r.exitCode) { [string]$r.exitCode } else { '' }
            $reason  = if ($null -ne $r.skipReason) { [string]$r.skipReason } else { '' }
            $cmd     = Redact-IfSecret $cmd
            $rows += ("- id={0} level={1} exit={2} skipped={3} reason={4} cmd={5}" -f $id, $level, $exit, $skipped, $reason, $cmd)
        }
    }
    if ($rows.Count -eq 0) {
        return $null
    }
    return ($rows -join [Environment]::NewLine)
}

# Extract just the structured Claude review sections that describe what to fix.
# We only extract Verdict, Blocking Issues, Non-blocking Issues, and Suggested
# Fix Prompt For Codex. We never copy the entire review verbatim and we never
# include raw file diffs.
function Get-ClaudeReviewExcerpt {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    $text = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    # Drop placeholder reviews — they contain no fixable content.
    if ($text -match 'Claude review was requested but not executed' -or
        $text -match 'Automatic Claude review could not be executed safely') {
        return $null
    }

    function Get-Section {
        param([string]$Body, [string]$Heading)
        $rx = '(?ms)^##\s*' + [regex]::Escape($Heading) + '\s*$\s*\n+(.*?)(?=^##\s|\z)'
        if ($Body -match $rx) {
            $section = $matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($section)) { return $null }
            return $section
        }
        return $null
    }

    $verdict = $null
    if ($text -match '(?ms)^##\s*Verdict\s*$\s*\n+\s*(approve|request_changes|block)\b') {
        $verdict = $matches[1].ToLowerInvariant()
    } elseif ($text -match '(?im)^Verdict\s*:\s*(approve|request_changes|block)\b') {
        $verdict = $matches[1].ToLowerInvariant()
    }

    $blocking    = Get-Section -Body $text -Heading 'Blocking Issues'
    $nonBlocking = Get-Section -Body $text -Heading 'Non-blocking Issues'
    $suggested   = Get-Section -Body $text -Heading 'Suggested Fix Prompt For Codex'

    $rows = @()
    if ($null -ne $verdict)     { $rows += ("Verdict: " + $verdict) }
    if (-not [string]::IsNullOrWhiteSpace($blocking))    { $rows += ''; $rows += '### Blocking Issues'; $rows += ''; $rows += $blocking }
    if (-not [string]::IsNullOrWhiteSpace($nonBlocking)) { $rows += ''; $rows += '### Non-blocking Issues (informational only)'; $rows += ''; $rows += $nonBlocking }
    if (-not [string]::IsNullOrWhiteSpace($suggested))   { $rows += ''; $rows += '### Suggested Fix Prompt For Codex (advisory; you must still obey safety rules)'; $rows += ''; $rows += $suggested }

    if ($rows.Count -eq 0) { return $null }
    return ($rows -join [Environment]::NewLine)
}

$goalText = if ([string]::IsNullOrWhiteSpace($Goal))   { '(not provided)' } else { $Goal }
$taskText = if ([string]::IsNullOrWhiteSpace($TaskId)) { '(not provided)' } else { $TaskId }

# Default the previous-iteration paths if not supplied.
if ([string]::IsNullOrWhiteSpace($PreviousTestSummary)) {
    $candidate = Join-Path $RunFolder ("iteration-{0:00}-test-summary.json" -f ($IterationIndex - 1))
    if (Test-Path -LiteralPath $candidate) { $PreviousTestSummary = $candidate }
}
if ([string]::IsNullOrWhiteSpace($PreviousClaudeReview)) {
    $candidate = Join-Path $RunFolder ("iteration-{0:00}-claude-review.md" -f ($IterationIndex - 1))
    if (Test-Path -LiteralPath $candidate) { $PreviousClaudeReview = $candidate }
}

# Read run-folder summary artifacts only. No raw diffs, no source files, no secrets.
$gitStatus  = Read-Artifact -Path (Join-Path $RunFolder 'git-status.txt')
$diffStat   = Read-Artifact -Path (Join-Path $RunFolder 'git-diff-stat.txt')
$diffNames  = Read-Artifact -Path (Join-Path $RunFolder 'git-diff-names.txt')

$failedTests   = Get-FailedTestsSummary -Path $PreviousTestSummary
$reviewExcerpt = Get-ClaudeReviewExcerpt -Path $PreviousClaudeReview

$bt    = [char]96
$fence = '' + $bt + $bt + $bt

$lines = @()
$lines += "# Codex Fix Prompt (Phase 5, iteration $IterationIndex of $MaxIterations)"
$lines += ''
$lines += '## Implementer-Only Directive — FIX ONLY'
$lines += ''
$lines += '**You are running as Codex CLI in `--sandbox workspace-write` mode for a single fix iteration. The previous iteration left fixable issues. Address ONLY those issues. Do not broaden scope. Do not refactor unrelated code. If the fix would require changes outside the allowed list or would touch files unrelated to the listed failures, stop and report instead of proceeding.**'
$lines += ''
$lines += '## Run Parameters'
$lines += ''
$lines += ('- Goal: ' + $goalText)
$lines += ('- TaskId: ' + $taskText)
$lines += ('- TestLevel: ' + $TestLevel)
$lines += ('- SkipE2E: ' + [bool]$SkipE2E)
$lines += ('- DryRun: ' + [bool]$DryRun)
$lines += ('- IterationIndex: ' + $IterationIndex)
$lines += ('- MaxIterations: ' + $MaxIterations)
$lines += ('- RunFolder: ' + $RunFolder)
$lines += ('- RepoRoot: ' + $repoRoot)
$lines += ''
$lines += '## Strict Safety Rules (unchanged from Phase 4)'
$lines += ''
$lines += '- Do NOT run `git commit`, `git push`, `git tag`, or any deploy command.'
$lines += '- Do NOT install dependencies (`npm`, `pnpm`, `yarn`, `pip`, `poetry`, `uv`, etc.).'
$lines += '- Do NOT modify `package.json`, lockfiles, or CI configuration unless the active task explicitly requires it.'
$lines += '- Do NOT read or print secret material. Treat any path matching `.env`, `*.pem`, `*.key`, or `*secret*` as off-limits.'
$lines += '- Do NOT run destructive shell commands (`rm -rf`, `Remove-Item -Recurse -Force` outside the active run folder, `git reset --hard`, force pushes).'
$lines += '- Do NOT modify files outside the repository root.'
$lines += '- Do NOT modify files outside the allowed list for the current phase as defined in `AGENTS.md` / `CLAUDE.md`. If a fix appears to require expansion of scope, stop and report.'
$lines += '- Do NOT broaden scope beyond the listed failures. Do not opportunistically reformat or refactor.'
$lines += '- Do NOT request `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, or any permissive sandbox mode.'
$lines += '- Do NOT introduce additional retries, fix loops, or follow-up Codex/Claude calls. The harness manages iteration count.'
$lines += '- Surface uncertainty. If the failure list is ambiguous or the requested fix would require unsafe changes, stop and emit a clarifying response instead of guessing.'
$lines += ''
$lines += '## Failures From Previous Iteration'
$lines += ''
$lines += '### Failed Test Commands (from previous iteration test-summary.json)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $failedTests '(no failed-test summary available from the previous iteration)')
$lines += $fence
$lines += ''
$lines += '### Claude Review Excerpt (verdict + blocking / non-blocking / suggested fix)'
$lines += ''
$lines += (Block-OrPlaceholder $reviewExcerpt '(no Claude review excerpt available from the previous iteration)')
$lines += ''
$lines += '## Current Git Snapshot (filtered, summary only — never raw diffs)'
$lines += ''
$lines += '### git status --short'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $gitStatus)
$lines += $fence
$lines += ''
$lines += '### git diff --stat'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $diffStat)
$lines += $fence
$lines += ''
$lines += '### Files changed (filtered, secret-like paths redacted)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $diffNames)
$lines += $fence
$lines += ''
$lines += '## Out-of-Scope Material'
$lines += ''
$lines += '- This prompt does NOT include raw file diffs, full source contents, or secret material.'
$lines += '- This prompt does NOT include credential paths or environment variable values.'
$lines += '- Codex CLI may read repository files directly when needed; do not assume the prompt is exhaustive.'
$lines += '- Do NOT use this iteration to expand the original Goal / TaskId. Address the listed failures only.'
$lines += ''
$lines += '## Required Final Response Format'
$lines += ''
$lines += 'After making (or refusing to make) edits, respond with the following structured markdown. Do not add other top-level sections.'
$lines += ''
$lines += $fence + 'markdown'
$lines += '# Codex Fix Result'
$lines += ''
$lines += '## Summary'
$lines += ''
$lines += '<2-5 sentences describing what was changed (or why nothing was changed).>'
$lines += ''
$lines += '## Files Changed'
$lines += ''
$lines += '- <relative/path/to/file>: <short description of the change>'
$lines += ''
$lines += '## Tests Run Or Not Run'
$lines += ''
$lines += '<Did Codex run any tests in this iteration? At what level? Results? If not, why not?>'
$lines += ''
$lines += '## Risks'
$lines += ''
$lines += '- <risk 1>'
$lines += '- <risk 2>'
$lines += ''
$lines += '## Follow-up Needed'
$lines += ''
$lines += '- <next step the human reviewer should take>'
$lines += $fence

($lines -join [Environment]::NewLine) | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "[codex-fix-prompt] Wrote $OutputPath"
