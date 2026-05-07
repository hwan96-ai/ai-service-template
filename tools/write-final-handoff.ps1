[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder,
    [string]$Goal = '',
    [string]$TaskId = '',
    [string]$TestLevel = 'none',
    [switch]$SkipE2E,
    [switch]$DryRun
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

# Result logic
$result = ''
if ($null -ne $testSummary -and $testSummary.dryRun) {
    $result = 'manual review required (DryRun: tests not executed)'
} elseif ($TestLevel -eq 'none') {
    $result = 'manual review required (TestLevel=none: tests not executed)'
} elseif ($null -ne $testSummary -and $testSummary.noCommandsSelected) {
    if ($noTestsFound) {
        $result = 'manual review required — no automated verification available (no tests detected in this repository)'
    } else {
        $result = 'manual review required — no commands matched the requested TestLevel/SkipE2E selection'
    }
} elseif ($null -ne $testSummary -and $testSummary.anyFailed) {
    $result = 'tests failed, manual review required'
} elseif ($null -ne $testSummary -and $testSummary.allPassed) {
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

# Risks
$risks = @()
$risks += '- Phase 2 harness only: no Codex implementation, no Claude review, no auto-fix loop has run.'
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

# Next steps
$nextSteps = @()
$nextSteps += '1. Read this handoff and `test-output.txt` (if present).'
$nextSteps += '2. Decide whether to commit. The harness will not commit, push, or deploy.'
$nextSteps += '3. If `noTestsFound` is true, treat the run as "manual review required" — there is no automated verification.'
$nextSteps += '4. Phase 2 still defers Codex implementation, Claude Code review, auto-fix loops, and AutoCommit.'

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
$lines += 'Phase 2 (test detection + optional safe execution; Codex/Claude/commit/push/deploy still disabled)'
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
