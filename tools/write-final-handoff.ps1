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
    [string]$ClaudeReviewMode = 'prompt-only',
    [ValidateSet('none','codex')]
    [string]$Implementer = 'none',
    [switch]$RunImplementer,
    [string]$CodexCommand = 'codex',
    [string]$CodexSandbox = 'workspace-write',
    [ValidateSet('prompt-only','exec')]
    [string]$CodexRunMode = 'prompt-only',
    # ----- Phase 5 loop summary inputs -----
    [switch]$EnableFixLoop,
    [ValidateSet('tests','claude','tests-or-claude')]
    [string]$FixTrigger = 'tests-or-claude',
    [int]$MaxIterations = 1,
    [int]$CompletedIterations = 1,
    [ValidateSet('continue','stop','halt')]
    [string]$TerminalAction = 'stop',
    [string]$TerminalReason = '',
    [int]$MaxChangedFiles = 0,
    [int]$MaxDiffStatLines = 0,
    [string]$TemplateVersion = '0.6.0'
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

# Codex artifacts (Phase 4)
$codexPromptPath = Join-Path $RunFolder 'codex-implementation-prompt.md'
$codexOutputPath = Join-Path $RunFolder 'codex-output.md'
$codexPromptExists = Test-Path -LiteralPath $codexPromptPath
$codexOutputExists = Test-Path -LiteralPath $codexOutputPath
$codexOutputText = ''
if ($codexOutputExists) {
    try { $codexOutputText = Get-Content -LiteralPath $codexOutputPath -Raw -ErrorAction SilentlyContinue } catch { $codexOutputText = '' }
    if ($null -eq $codexOutputText) { $codexOutputText = '' }
}

# Determine Codex status:
#   not-requested                  - Implementer != codex
#   prompt-generated-not-executed  - prompt exists, placeholder body, or DryRun suppressed run
#   executed                       - Codex exec ran and exit code was 0
#   failed-or-unsupported          - Codex exec ran/attempted and exit was non-zero / CLI missing
$codexStatus  = 'not-requested'
$codexExitCode = $null

if ($Implementer -eq 'codex') {
    if (-not $codexOutputExists) {
        # Prompt may exist but no output file means we never reached the placeholder/exec branch.
        $codexStatus = 'prompt-generated-not-executed'
    } elseif ($codexOutputText -match 'Codex implementation was requested but not executed' -or
              $codexOutputText -match 'DryRun is ON, so the harness refused to invoke Codex') {
        $codexStatus = 'prompt-generated-not-executed'
    } elseif ($codexOutputText -match 'Automatic Codex implementation could not be executed safely' -or
              $codexOutputText -match 'Automatic Codex implementation failed') {
        $codexStatus = 'failed-or-unsupported'
    } elseif ($codexOutputText -match '(?im)^Codex execution captured' -or
              $codexOutputText -match '(?im)^##\s*Codex execution output') {
        $codexStatus = 'executed'
    } elseif ($codexOutputText -match '(?im)^#\s*Codex Implementation \(auto-executed\)') {
        # Auto-executed but no recognized success/failure marker - treat as failed-safely.
        $codexStatus = 'failed-or-unsupported'
    } else {
        $codexStatus = 'prompt-generated-not-executed'
    }

    if ($codexOutputText -match '(?im)^Exit code:\s*(-?\d+)') {
        try { $codexExitCode = [int]$matches[1] } catch { $codexExitCode = $null }
    }
}

$codexExecuted = ($codexStatus -eq 'executed')
$codexFailed   = ($codexStatus -eq 'failed-or-unsupported')

# Implementer mode label for the handoff.
$implementerModeLabel = ''
if ($Implementer -eq 'none') {
    $implementerModeLabel = 'disabled (Implementer=none)'
} elseif ($RunImplementer -and $DryRun) {
    $implementerModeLabel = "prompt-only (DryRun suppressed -RunImplementer; sandbox=$CodexSandbox)"
} elseif ($RunImplementer) {
    $implementerModeLabel = "auto-execute (codex exec --sandbox $CodexSandbox)"
} else {
    $implementerModeLabel = "prompt-only (mode=$CodexRunMode; sandbox=$CodexSandbox)"
}

# Result logic (Phase 5 loop-aware + Phase 4 Codex-aware + Phase 3 verdict-aware).
# Priority order (top to bottom):
#   1. Phase 5 halts (loop refused to continue for safety reasons)
#   2. tests-failed
#   3. Codex executed via -RunImplementer but failed/unsupported
#   4. Claude verdict block / request_changes
#   5. Codex executed + tests passed + Claude approve
#   6. Codex executed + tests passed (no Claude verdict)
#   7. Codex executed + no automated verification available
#   8. Codex executed (other)
#   9. Codex prompt generated but not executed
#  10. Claude verdict approve (without Codex execution)
#  11. Phase 2 fallbacks (DryRun / TestLevel=none / noCommandsSelected / testsPassed / generic)
$result = ''
$testsFailed = ($null -ne $testSummary -and $testSummary.anyFailed)
$testsPassed = ($null -ne $testSummary -and $testSummary.allPassed)
$noAutomatedVerification = (
    ($TestLevel -eq 'none') -or
    ($null -ne $testSummary -and $testSummary.dryRun) -or
    ($null -ne $testSummary -and $testSummary.noCommandsSelected) -or
    $noTestsFound
)

# Phase 5 halt reasons that override the standard result line.
$phase5HaltReasons = @(
    'secret-like-paths-in-diff',
    'repeated-failure-fingerprint'
)
$phase5HaltExceededPrefix = @('max-changed-files-exceeded', 'max-diff-stat-exceeded')

$loopHalted = ($TerminalAction -eq 'halt')
$haltMatchesPhase5 = $false
if ($loopHalted -and -not [string]::IsNullOrWhiteSpace($TerminalReason)) {
    if ($phase5HaltReasons -contains $TerminalReason) { $haltMatchesPhase5 = $true }
    foreach ($prefix in $phase5HaltExceededPrefix) {
        if ($TerminalReason.StartsWith($prefix)) { $haltMatchesPhase5 = $true }
    }
}

if ($haltMatchesPhase5) {
    $result = ("fix loop halted by Phase 5 safety check ({0}) — manual review required" -f $TerminalReason)
} elseif ($testsFailed) {
    $result = 'tests failed, manual review required'
} elseif ($codexFailed) {
    $result = 'Codex implementation failed or was not executed safely — manual review required'
} elseif ($reviewExecuted -and $reviewVerdict -eq 'block') {
    $result = 'Claude review verdict: block — manual review required'
} elseif ($reviewExecuted -and $reviewVerdict -eq 'request_changes') {
    $result = 'Claude review verdict: request changes — manual review required'
} elseif ($codexExecuted -and $reviewExecuted -and $reviewVerdict -eq 'approve' -and $testsPassed) {
    if ($EnableFixLoop -and $CompletedIterations -gt 1) {
        $result = ("Codex <-> Claude fix loop converged after {0} iterations: tests passed, Claude review approved — manual approval still required" -f $CompletedIterations)
    } else {
        $result = 'Codex ran, tests passed, Claude review approved — manual approval still required'
    }
} elseif ($codexExecuted -and $testsPassed) {
    $result = 'Codex ran and tests passed — manual approval still required'
} elseif ($codexExecuted -and $noAutomatedVerification) {
    $result = 'Codex ran but no automated verification available — manual review required'
} elseif ($codexExecuted) {
    $result = 'Codex ran — manual review required'
} elseif ($Implementer -eq 'codex') {
    $result = 'manual review required (Codex prompt generated but not executed)'
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
$paramLines += ("- TemplateVersion: {0}" -f $TemplateVersion)
$paramLines += ("- Goal: {0}" -f $goalText)
$paramLines += ("- TaskId: {0}" -f $taskText)
$paramLines += ("- TestLevel: {0}" -f $TestLevel)
$paramLines += ("- SkipE2E: {0}" -f [bool]$SkipE2E)
$paramLines += ("- DryRun: {0}" -f [bool]$DryRun)
$paramLines += ("- Reviewer: {0}" -f $Reviewer)
$paramLines += ("- RunReviewer: {0}" -f [bool]$RunReviewer)
$paramLines += ("- ClaudeReviewMode: {0}" -f $ClaudeReviewMode)
$paramLines += ("- Implementer: {0}" -f $Implementer)
$paramLines += ("- RunImplementer: {0}" -f [bool]$RunImplementer)
$paramLines += ("- CodexCommand: {0}" -f $CodexCommand)
$paramLines += ("- CodexSandbox: {0}" -f $CodexSandbox)
$paramLines += ("- CodexRunMode: {0}" -f $CodexRunMode)
$paramLines += ("- EnableFixLoop: {0}" -f [bool]$EnableFixLoop)
$paramLines += ("- FixTrigger: {0}" -f $FixTrigger)
$paramLines += ("- MaxIterations: {0}" -f $MaxIterations)
$paramLines += ("- CompletedIterations: {0}" -f $CompletedIterations)
$paramLines += ("- TerminalAction: {0}" -f $TerminalAction)
$paramLines += ("- TerminalReason: {0}" -f $TerminalReason)
$paramLines += ("- MaxChangedFiles: {0}" -f $MaxChangedFiles)
$paramLines += ("- MaxDiffStatLines: {0}" -f $MaxDiffStatLines)

# Loop summary (read by reference; written by ai-autopilot.ps1)
$loopSummaryPath = Join-Path $RunFolder 'loop-summary.json'
$loopSummary = $null
if (Test-Path -LiteralPath $loopSummaryPath) {
    try {
        $loopSummary = (Get-Content -LiteralPath $loopSummaryPath -Raw) | ConvertFrom-Json
    } catch {
        $loopSummary = $null
    }
}

$loopLines = @()
if ($null -eq $loopSummary) {
    $loopLines += '(no loop summary available)'
} else {
    $loopLines += ("- EnableFixLoop: {0}" -f $loopSummary.enableFixLoop)
    $loopLines += ("- FixTrigger: {0}" -f $loopSummary.fixTrigger)
    $loopLines += ("- MaxIterations: {0}" -f $loopSummary.maxIterations)
    $loopLines += ("- CompletedIterations: {0}" -f $loopSummary.completedIterations)
    $loopLines += ("- TerminalAction: {0}" -f $loopSummary.terminalAction)
    $loopLines += ("- TerminalReason: {0}" -f $loopSummary.terminalReason)
    $loopLines += ("- MaxChangedFiles: {0}" -f $loopSummary.maxChangedFiles)
    $loopLines += ("- MaxDiffStatLines: {0}" -f $loopSummary.maxDiffStatLines)
    if ($null -ne $loopSummary.iterations -and (@($loopSummary.iterations).Count -gt 0)) {
        $loopLines += ''
        $loopLines += '| Iter | Codex | Tests Failed | Tests Passed | Review Verdict | Action | Reason |'
        $loopLines += '| --- | --- | --- | --- | --- | --- | --- |'
        foreach ($it in $loopSummary.iterations) {
            $verdictDisplay = if ([string]::IsNullOrWhiteSpace([string]$it.reviewVerdict)) { '(none)' } else { [string]$it.reviewVerdict }
            $loopLines += ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f $it.iteration, $it.codexStatus, $it.testsAnyFailed, $it.testsAllPassed, $verdictDisplay, $it.action, $it.reason)
        }
    }
}

# Risks
$risks = @()
if ($EnableFixLoop) {
    $risks += ('- Phase 5 fix loop was ENABLED. Codex <-> Claude bounded loop ran for {0}/{1} iterations (terminal action: {2}, reason: {3}). The loop never bypassed sandbox / approval safety.' -f $CompletedIterations, $MaxIterations, $TerminalAction, $TerminalReason)
} else {
    $risks += '- Phase 5 fix loop was DISABLED (default). Single-iteration behavior preserved; no Codex <-> Claude follow-ups; no automatic retries.'
}
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
if ($Implementer -eq 'codex' -and -not $RunImplementer) {
    $risks += '- Implementer=codex was requested but Codex CLI was NOT invoked. Use codex-implementation-prompt.md manually or rerun with -RunImplementer after verifying local Codex CLI flags.'
}
if ($Implementer -eq 'codex' -and $RunImplementer -and $DryRun) {
    $risks += '- -RunImplementer was suppressed by -DryRun. Codex CLI was NOT invoked. Drop -DryRun to attempt the one-shot Codex run.'
}
if ($Implementer -eq 'codex' -and $codexFailed) {
    $risks += '- Automatic Codex implementation failed or was unsupported with the safe codex exec --sandbox workspace-write pattern. See codex-output.md. No permissive fallback was attempted.'
}
if ($Implementer -eq 'codex' -and $codexExecuted) {
    $risks += '- Codex CLI made edits in the working tree. Review the post-Codex git status / diff above before committing anything.'
}
if ($Reviewer -eq 'claude' -and -not $RunReviewer) {
    $risks += '- Reviewer=claude was requested but Claude CLI was NOT invoked. Run the prompt manually or rerun with -RunReviewer after verifying local Claude CLI flags.'
}
if ($Reviewer -eq 'claude' -and $RunReviewer -and -not $reviewExecuted) {
    $risks += '- Automatic Claude review could not be executed safely with the chosen review-only invocation pattern. See claude-review.md for details.'
}
if ($haltMatchesPhase5) {
    $risks += ('- Phase 5 fix loop halted by safety check: {0}. The harness refused to run any further Codex iterations.' -f $TerminalReason)
}

# Next steps
$nextSteps = @()
$nextSteps += '1. Read this handoff, `loop-summary.json`, the latest `iteration-XX-*.md`/`iteration-XX-decision.json`, `test-output.txt` (if present), `codex-output.md` (if present), and `claude-review.md` (if present).'
$nextSteps += '2. Decide whether to commit. The harness will not commit, push, or deploy.'
$nextSteps += '3. If `noTestsFound` is true, treat the run as "manual review required" — there is no automated verification.'
$nextSteps += '4. If Codex was prompt-only, hand `codex-implementation-prompt.md` (and `codex-fix-prompt.md` for later iterations) to a local Codex CLI session yourself, or rerun with `-RunImplementer` after verifying `codex exec --help` and `codex status`.'
$nextSteps += '5. If a Claude review verdict is missing or non-`approve`, address blocking issues before approval.'
$nextSteps += '6. The fix loop is opt-in via `-EnableFixLoop` and capped at `-MaxIterations 3`. AutoCommit, push, deploy, and dependency installation remain forbidden in every iteration.'

# Suggested manual verification
$verifySteps = @()
$verifySteps += '- Inspect `git status --short` and the `Files Changed` section above.'
$verifySteps += '- Re-run with `-DryRun` to regenerate detection without executing anything.'
$verifySteps += '- For unit-level local validation, use `-TestLevel unit`. Avoid E2E unless you intend it.'
$verifySteps += '- To explicitly avoid E2E even at higher TestLevel, pass `-SkipE2E`.'
$verifySteps += '- To preview a multi-iteration loop without executing Codex/Claude, combine `-EnableFixLoop -MaxIterations 2 -DryRun`.'

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
$lines += ('Phase 6 (template packaging and reuse layer; TemplateVersion {0}). Phases 1-5 behaviour preserved: bounded Codex <-> Claude fix loop opt-in via -EnableFixLoop, capped at -MaxIterations 3; Claude review remains reviewer-only; auto-commit / push / deploy / dependency installation still disabled.' -f $TemplateVersion)
$lines += ''
$lines += '## Parameters'
$lines += ''
$lines += ($paramLines -join [Environment]::NewLine)
$lines += ''
$lines += '## Loop Summary'
$lines += ''
$lines += ($loopLines -join [Environment]::NewLine)
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
$lines += '## Codex Implementer'
$lines += ''
$lines += ('- Mode: {0}' -f $implementerModeLabel)
if ($codexPromptExists) {
    $lines += ('- Prompt: ' + $bt + $codexPromptPath + $bt)
} else {
    $lines += '- Prompt: (not generated)'
}
if ($codexOutputExists) {
    $lines += ('- Output: ' + $bt + $codexOutputPath + $bt)
} else {
    $lines += '- Output: (not generated)'
}
switch ($codexStatus) {
    'not-requested'                 { $lines += '- Status: not requested (Implementer=none).' }
    'prompt-generated-not-executed' { $lines += '- Status: Codex implementation prompt generated but Codex CLI was not executed.' }
    'executed'                      { $lines += '- Status: Codex CLI was executed once in workspace-write sandbox.' }
    'failed-or-unsupported'         { $lines += '- Status: Automatic Codex implementation failed or was unsupported. See `codex-output.md`.' }
    default                         { $lines += ('- Status: ' + $codexStatus) }
}
if ($null -ne $codexExitCode) {
    $lines += ('- Exit code: ' + $codexExitCode)
} elseif ($codexStatus -eq 'executed' -or $codexStatus -eq 'failed-or-unsupported') {
    $lines += '- Exit code: (not captured)'
}
if ($codexOutputExists -and -not [string]::IsNullOrWhiteSpace($codexOutputText) -and ($codexStatus -eq 'executed' -or $codexStatus -eq 'failed-or-unsupported')) {
    $codexLinesArr = ($codexOutputText -split "`r?`n")
    $codexPreviewMax = 60
    $codexPreview = if ($codexLinesArr.Count -gt $codexPreviewMax) { ($codexLinesArr[0..($codexPreviewMax - 1)] -join [Environment]::NewLine) + [Environment]::NewLine + '... (truncated; full content in codex-output.md)' } else { $codexOutputText.TrimEnd() }
    $lines += ''
    $lines += '### Codex Execution Summary'
    $lines += ''
    $lines += $codexPreview
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
