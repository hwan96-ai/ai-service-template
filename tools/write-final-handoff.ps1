[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder,
    [string]$Goal = '',
    [string]$TaskId = '',
    [string]$TestLevel = 'none',
    [switch]$SkipE2E,
    [switch]$DryRun,
    [ValidateSet('none','claude')]
    [string]$Reviewer = 'none',
    [switch]$RunReviewer,
    [ValidateSet('prompt-only','print')]
    [string]$ClaudeReviewMode = 'prompt-only'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $RunFolder)) {
    throw "write-final-handoff: run folder does not exist: $RunFolder"
}

function Read-OrPlaceholder {
    param([string]$Path, [string]$Placeholder = '(not generated)')
    if (Test-Path -LiteralPath $Path) {
        $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { return '(empty)' }
        return $content.TrimEnd()
    }
    return $Placeholder
}

$gitStatus  = Read-OrPlaceholder (Join-Path $RunFolder 'git-status.txt')
$diffStat   = Read-OrPlaceholder (Join-Path $RunFolder 'git-diff-stat.txt')
$diffNames  = Read-OrPlaceholder (Join-Path $RunFolder 'git-diff-names.txt')
$detectedMd = Read-OrPlaceholder (Join-Path $RunFolder 'detected-tests.md')

$goalText = if ([string]::IsNullOrWhiteSpace($Goal))   { '(not provided)' } else { $Goal }
$taskText = if ([string]::IsNullOrWhiteSpace($TaskId)) { '(not provided)' } else { $TaskId }

# Load test summary if present
$testSummaryPath = Join-Path $RunFolder 'test-summary.json'
$testOutputPath  = Join-Path $RunFolder 'test-output.txt'
$testSummary = $null
if (Test-Path -LiteralPath $testSummaryPath) {
    try {
        $testSummary = (Get-Content -LiteralPath $testSummaryPath -Raw) | ConvertFrom-Json
    } catch {
        $testSummary = $null
    }
}

# Load detected-tests.json for noTestsFound flag
$detectedJsonPath = Join-Path $RunFolder 'detected-tests.json'
$detectedJson = $null
if (Test-Path -LiteralPath $detectedJsonPath) {
    try {
        $detectedJson = (Get-Content -LiteralPath $detectedJsonPath -Raw) | ConvertFrom-Json
    } catch {
        $detectedJson = $null
    }
}
$noTestsFound = $false
if ($null -ne $detectedJson -and ($detectedJson.PSObject.Properties.Name -contains 'noTestsFound')) {
    $noTestsFound = [bool]$detectedJson.noTestsFound
}

# Claude review artifacts (Phase 3)
$reviewPromptPath = Join-Path $RunFolder 'claude-review-prompt.md'
$reviewOutputPath = Join-Path $RunFolder 'claude-review.md'
$reviewPromptExists = Test-Path -LiteralPath $reviewPromptPath
$reviewOutputExists = Test-Path -LiteralPath $reviewOutputPath
$reviewOutputText = ''
if ($reviewOutputExists) {
    try { $reviewOutputText = Get-Content -LiteralPath $reviewOutputPath -Raw -ErrorAction SilentlyContinue } catch { $reviewOutputText = '' }
    if ($null -eq $reviewOutputText) { $reviewOutputText = '' }
}

# Parse the Claude verdict: look for a "## Verdict" section followed by a single
# token "approve" | "request_changes" | "block". Anything else is treated as
# unknown so the handoff cannot accidentally claim approval.
$reviewVerdict = $null            # one of approve|request_changes|block when detected
$reviewExecuted = $false          # true only when claude-review.md looks like a real review
if ($reviewOutputExists) {
    if ($reviewOutputText -match '(?ms)^##\s*Verdict\s*$\s*\n+\s*(approve|request_changes|block)\b') {
        $reviewVerdict = $matches[1].ToLowerInvariant()
        $reviewExecuted = $true
    } elseif ($reviewOutputText -match '(?im)^Verdict\s*:\s*(approve|request_changes|block)\b') {
        $reviewVerdict = $matches[1].ToLowerInvariant()
        $reviewExecuted = $true
    }
    # The placeholder file used when -RunReviewer is not set must NOT be classified as executed.
    if ($reviewOutputText -match 'Claude review was requested but not executed') {
        $reviewExecuted = $false
        $reviewVerdict = $null
    }
    if ($reviewOutputText -match 'Automatic Claude review could not be executed safely') {
        $reviewExecuted = $false
        $reviewVerdict = $null
    }
}

# Reviewer mode label for the handoff.
$reviewerModeLabel = ''
if ($Reviewer -eq 'none') {
    $reviewerModeLabel = 'disabled (Reviewer=none)'
} elseif ($RunReviewer) {
    $reviewerModeLabel = "auto-execute (mode=$ClaudeReviewMode)"
} else {
    $reviewerModeLabel = "prompt-only (mode=$ClaudeReviewMode)"
}

# Result logic (Phase 3 verdict-aware).
# Priority: tests-failed > verdict=block > verdict=request_changes > verdict=approve+tests-passed > verdict=approve > Phase 2 fallback.
$result = ''
$testsFailed = ($null -ne $testSummary -and $testSummary.anyFailed)
$testsPassed = ($null -ne $testSummary -and $testSummary.allPassed)

if ($testsFailed) {
    $result = 'tests failed, manual review required'
} elseif ($reviewExecuted -and $reviewVerdict -eq 'block') {
    $result = 'Claude review verdict: block — manual review required'
} elseif ($reviewExecuted -and $reviewVerdict -eq 'request_changes') {
    $result = 'Claude review verdict: request changes — manual review required'
} elseif ($reviewExecuted -and $reviewVerdict -eq 'approve' -and $testsPassed) {
    $result = 'Claude review approved and tests passed — manual approval still required'
} elseif ($reviewExecuted -and $reviewVerdict -eq 'approve') {
    $result = 'Claude review approved (no automated verification of tests this run) — manual approval still required'
} elseif ($null -ne $testSummary -and $testSummary.dryRun) {
    $result = 'manual review required (DryRun: tests not executed)'
} elseif ($TestLevel -eq 'none') {
    $result = 'manual review required (TestLevel=none: tests not executed)'
} elseif ($null -ne $testSummary -and $testSummary.noCommandsSelected) {
    if ($noTestsFound) {
        $result = 'manual review required — no automated verification available (no tests detected in this repository)'
    } else {
        $result = 'manual review required — no commands matched the requested TestLevel/SkipE2E selection'
    }
} elseif ($testsPassed) {
    $result = 'tests passed, manual review still required'
} else {
    $result = 'manual review required'
}

# Build test execution summary text
$testExecLines = @()
if ($null -eq $testSummary) {
    $testExecLines += '(no test summary available)'
} else {
    $testExecLines += ("- Selected TestLevel: {0}" -f $testSummary.selectedLevel)
    $testExecLines += ("- SkipE2E: {0}" -f $testSummary.skipE2E)
    $testExecLines += ("- DryRun: {0}" -f $testSummary.dryRun)
    $testExecLines += ("- Commands selected: {0}" -f (@($testSummary.results).Count))
    $testExecLines += ("- Any failed: {0}" -f $testSummary.anyFailed)
    $testExecLines += ("- All passed: {0}" -f $testSummary.allPassed)
    if ($testSummary.PSObject.Properties.Name -contains 'note' -and -not [string]::IsNullOrWhiteSpace([string]$testSummary.note)) {
        $testExecLines += ("- Note: {0}" -f $testSummary.note)
    }
    if (@($testSummary.results).Count -gt 0) {
        $testExecLines += ''
        $testExecLines += '| ID | Level | Exit | Passed | Skipped | Reason |'
        $testExecLines += '| --- | --- | --- | --- | --- | --- |'
        foreach ($r in $testSummary.results) {
            $skipReason = if ($null -ne $r.skipReason) { [string]$r.skipReason } else { '' }
            $exit = if ($null -ne $r.exitCode) { [string]$r.exitCode } else { '' }
            $testExecLines += ("| {0} | {1} | {2} | {3} | {4} | {5} |" -f $r.id, $r.level, $exit, $r.passed, $r.skipped, $skipReason)
        }
    }
}

# Parameters block
$paramLines = @()
$paramLines += ("- Goal: {0}" -f $goalText)
$paramLines += ("- TaskId: {0}" -f $taskText)
$paramLines += ("- TestLevel: {0}" -f $TestLevel)
$paramLines += ("- SkipE2E: {0}" -f [bool]$SkipE2E)
$paramLines += ("- DryRun: {0}" -f [bool]$DryRun)
$paramLines += ("- Reviewer: {0}" -f $Reviewer)
$paramLines += ("- RunReviewer: {0}" -f [bool]$RunReviewer)
$paramLines += ("- ClaudeReviewMode: {0}" -f $ClaudeReviewMode)

# Risks
$risks = @()
$risks += '- Phase 3 harness: Claude review is reviewer-only. Codex implementation, auto-fix loops, AutoCommit, push, and deploy remain disabled.'
$risks += '- Any uncommitted changes shown above are unverified local edits.'
if ($noTestsFound) {
    $risks += '- No test runners were detected in this repository, so no automated validation is possible from this harness.'
}
if ($null -ne $testSummary -and $testSummary.anyFailed) {
    $risks += '- One or more selected test commands failed or were rejected by the safety denylist. See test-output.txt.'
}
if ($TestLevel -eq 'e2e' -or ($TestLevel -in @('integration','all') -and -not [bool]$SkipE2E)) {
    $risks += '- E2E commands are eligible at this TestLevel. They can have side effects (browsers, network); review before re-running.'
}
if ($Reviewer -eq 'claude' -and -not $RunReviewer) {
    $risks += '- Reviewer=claude was requested but Claude CLI was NOT invoked. Run the prompt manually or rerun with -RunReviewer after verifying local Claude CLI flags.'
}
if ($Reviewer -eq 'claude' -and $RunReviewer -and -not $reviewExecuted) {
    $risks += '- Automatic Claude review could not be executed safely with the chosen review-only invocation pattern. See claude-review.md for details.'
}

# Next steps
$nextSteps = @()
$nextSteps += '1. Read this handoff, `test-output.txt` (if present), and `claude-review.md` (if present).'
$nextSteps += '2. Decide whether to commit. The harness will not commit, push, or deploy.'
$nextSteps += '3. If `noTestsFound` is true, treat the run as "manual review required" — there is no automated verification.'
$nextSteps += '4. If a Claude review verdict is missing or non-`approve`, address blocking issues before approval.'
$nextSteps += '5. Phase 3 still defers Codex implementation, auto-fix loops, AutoCommit, push, and deploy.'

# Suggested manual verification
$verifySteps = @()
$verifySteps += '- Inspect `git status --short` and the `Files Changed` section above.'
$verifySteps += '- Re-run with `-DryRun` to regenerate detection without executing anything.'
$verifySteps += '- For unit-level local validation, use `-TestLevel unit`. Avoid E2E unless you intend it.'
$verifySteps += '- To explicitly avoid E2E even at higher TestLevel, pass `-SkipE2E`.'

$lines = @()
$lines += '# AI Final Handoff'
$lines += ''
$lines += '## Goal'
$lines += ''
$lines += $goalText
$lines += ''
$lines += '## Task ID'
$lines += ''
$lines += $taskText
$lines += ''
$lines += '## Run Folder'
$lines += ''
$lines += $RunFolder
$lines += ''
$lines += '## Autopilot Phase'
$lines += ''
$lines += 'Phase 3 (Claude review prompt + optional review-only Claude invocation; Codex/auto-fix/commit/push/deploy still disabled)'
$lines += ''
$lines += '## Parameters'
$lines += ''
$lines += ($paramLines -join [Environment]::NewLine)
$lines += ''
$lines += '## Files Changed'
$lines += ''
$lines += '```'
$lines += $diffNames
$lines += '```'
$lines += ''
$lines += '## Git Status'
$lines += ''
$lines += '```'
$lines += $gitStatus
$lines += '```'
$lines += ''
$lines += '## Diff Summary'
$lines += ''
$lines += '```'
$lines += $diffStat
$lines += '```'
$lines += ''
$lines += '## Detected Tests'
$lines += ''
$lines += $detectedMd
$lines += ''
$lines += '## Test Execution Summary'
$lines += ''
$lines += ($testExecLines -join [Environment]::NewLine)
$lines += ''
$lines += '## Test Output Location'
$lines += ''
$bt = [char]96
if (Test-Path -LiteralPath $testOutputPath) {
    $lines += ('- Log:     ' + $bt + $testOutputPath + $bt)
} else {
    $lines += '- Log:     (not generated)'
}
if (Test-Path -LiteralPath $testSummaryPath) {
    $lines += ('- Summary: ' + $bt + $testSummaryPath + $bt)
} else {
    $lines += '- Summary: (not generated)'
}
$lines += ''
$lines += '## Claude Review'
$lines += ''
$lines += ('- Mode: {0}' -f $reviewerModeLabel)
if ($reviewPromptExists) {
    $lines += ('- Prompt: ' + $bt + $reviewPromptPath + $bt)
} else {
    $lines += '- Prompt: (not generated)'
}
if ($reviewOutputExists) {
    $lines += ('- Output: ' + $bt + $reviewOutputPath + $bt)
} else {
    $lines += '- Output: (not generated)'
}
if ($Reviewer -ne 'claude') {
    $lines += '- Status: Reviewer disabled. No Claude review prompt or output was generated.'
} elseif (-not $RunReviewer) {
    $lines += '- Status: Claude review prompt generated but Claude was not executed.'
} elseif ($reviewExecuted) {
    $lines += '- Status: Claude review captured.'
} else {
    $lines += '- Status: Automatic Claude review could not be executed safely. See `claude-review.md` for details.'
}
if ($null -ne $reviewVerdict) {
    $lines += ('- Verdict: ' + $reviewVerdict)
} else {
    $lines += '- Verdict: (not detected)'
}
$lines += ''
if ($reviewOutputExists -and -not [string]::IsNullOrWhiteSpace($reviewOutputText)) {
    $reviewLinesArr = ($reviewOutputText -split "`r?`n")
    $previewMax = 80
    $preview = if ($reviewLinesArr.Count -gt $previewMax) { ($reviewLinesArr[0..($previewMax - 1)] -join [Environment]::NewLine) + [Environment]::NewLine + '... (truncated; full content in claude-review.md)' } else { $reviewOutputText.TrimEnd() }
    $lines += '### Claude Review Summary'
    $lines += ''
    $lines += $preview
    $lines += ''
}
$lines += '## Result'
$lines += ''
$lines += $result
$lines += ''
$lines += '## Risks'
$lines += ''
$lines += ($risks -join [Environment]::NewLine)
$lines += ''
$lines += '## Next Steps'
$lines += ''
$lines += ($nextSteps -join [Environment]::NewLine)
$lines += ''
$lines += '## Suggested Manual Verification'
$lines += ''
$lines += ($verifySteps -join [Environment]::NewLine)
$lines += ''
$lines += '---'
$lines += ''
$lines += '**NO commit, NO push, NO deploy was performed. Human review required.**'

$outPath = Join-Path $RunFolder 'AI_FINAL_HANDOFF.md'
($lines -join [Environment]::NewLine) | Out-File -FilePath $outPath -Encoding utf8

Write-Host "[handoff] Wrote $outPath"
