[CmdletBinding()]
param(
    [string]$Goal = '',
    [string]$TaskId = '',
    [int]$MaxIterations = 1,
    [switch]$DryRun,
    [switch]$AutoCommit,
    [switch]$SkipE2E,
    [ValidateSet('none','unit','integration','e2e','all')]
    [string]$TestLevel = 'none',
    [ValidateSet('none','claude')]
    [string]$Reviewer = 'none',
    [switch]$RunReviewer,
    [string]$ClaudeCommand = 'claude',
    [ValidateSet('prompt-only','print')]
    [string]$ClaudeReviewMode = 'prompt-only',
    [ValidateSet('none','codex')]
    [string]$Implementer = 'none',
    [switch]$RunImplementer,
    [string]$CodexCommand = 'codex',
    [string]$CodexSandbox = 'workspace-write',
    [ValidateSet('prompt-only','exec')]
    [string]$CodexRunMode = 'prompt-only',
    # ----- Phase 5: bounded fix loop (opt-in, default OFF) -----
    [switch]$EnableFixLoop,
    [ValidateSet('tests','claude','tests-or-claude')]
    [string]$FixTrigger = 'tests-or-claude',
    [int]$MaxChangedFiles = 12,
    [int]$MaxDiffStatLines = 120,
    [switch]$CopyHandoffToClipboard
)

$ErrorActionPreference = 'Stop'

Write-Host '=== ai-autopilot (Phase 5) ==='

# Phase 5 hard cap on MaxIterations. Refused BEFORE any run folder is created
# and BEFORE any Codex/Claude process is spawned.
$MaxIterationsCap = 3
if ($MaxIterations -lt 1 -or $MaxIterations -gt $MaxIterationsCap) {
    Write-Error ("MaxIterations must be between 1 and {0}. Got: {1}. Aborting before any action." -f $MaxIterationsCap, $MaxIterations)
    exit 2
}

# Hard refusal: AutoCommit is not allowed (Phase 1 + Phase 2 + Phase 3 + Phase 4 + Phase 5).
if ($AutoCommit) {
    Write-Error 'AutoCommit is not permitted (Phase 1 + Phase 2 + Phase 3 + Phase 4 + Phase 5). Aborting before any action.'
    exit 2
}

# Verify git work tree
$inside = (& git rev-parse --is-inside-work-tree 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]($inside).Trim() -ne 'true') {
    Write-Error 'Not inside a git work tree. Aborting.'
    exit 2
}

$repoRoot = (& git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $repoRoot

# Verify required control documents
$required = @(
    'AI_PRODUCT_SPEC.md',
    'AI_ACCEPTANCE_CRITERIA.md',
    'AI_TASK_QUEUE.md',
    'AI_WORKFLOW.md',
    'AGENTS.md',
    'CLAUDE.md'
)
$missing = @()
foreach ($f in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $f))) {
        $missing += $f
    }
}
if ($missing.Count -gt 0) {
    Write-Error ("Missing required control documents: {0}. Aborting." -f ($missing -join ', '))
    exit 2
}

# Create unique timestamped run folder.
$runRoot = Join-Path $repoRoot 'ai-runs'
if (-not (Test-Path -LiteralPath $runRoot)) {
    New-Item -ItemType Directory -Path $runRoot | Out-Null
}

$baseTs = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runFolder = Join-Path $runRoot $baseTs
$collisionSuffix = 0
while (Test-Path -LiteralPath $runFolder) {
    $collisionSuffix++
    if ($collisionSuffix -gt 999) {
        Write-Error 'Could not allocate a unique ai-runs folder after 999 attempts. Aborting.'
        exit 2
    }
    $runFolder = Join-Path $runRoot ("{0}-{1:D3}" -f $baseTs, $collisionSuffix)
}
New-Item -ItemType Directory -Path $runFolder | Out-Null
$ts = Split-Path $runFolder -Leaf

Write-Host "[autopilot] Repo root:  $repoRoot"
Write-Host "[autopilot] Run folder: $runFolder"
Write-Host ("[autopilot] Loop config: MaxIterations={0} EnableFixLoop={1} FixTrigger={2} MaxChangedFiles={3} MaxDiffStatLines={4}" -f $MaxIterations, [bool]$EnableFixLoop, $FixTrigger, $MaxChangedFiles, $MaxDiffStatLines)

if ($DryRun) {
    Write-Host '[autopilot] DryRun is ON. Suppressed: Codex execution, Claude execution, tests, install, commit, push, deploy, destructive ops.'
    Write-Host '[autopilot] DryRun still writes safe local report files.'
}

# Save run parameters
$paramLines = @(
    "Goal:             $Goal",
    "TaskId:           $TaskId",
    "Timestamp:        $ts",
    "MaxIterations:    $MaxIterations",
    "DryRun:           $([bool]$DryRun)",
    "AutoCommit:       $AutoCommit",
    "SkipE2E:          $([bool]$SkipE2E)",
    "TestLevel:        $TestLevel",
    "Reviewer:         $Reviewer",
    "RunReviewer:      $([bool]$RunReviewer)",
    "ClaudeCommand:    $ClaudeCommand",
    "ClaudeReviewMode: $ClaudeReviewMode",
    "Implementer:      $Implementer",
    "RunImplementer:   $([bool]$RunImplementer)",
    "CodexCommand:     $CodexCommand",
    "CodexSandbox:     $CodexSandbox",
    "CodexRunMode:     $CodexRunMode",
    "EnableFixLoop:    $([bool]$EnableFixLoop)",
    "FixTrigger:       $FixTrigger",
    "MaxChangedFiles:  $MaxChangedFiles",
    "MaxDiffStatLines: $MaxDiffStatLines",
    "RepoRoot:         $repoRoot",
    "RunFolder:        $runFolder"
)
($paramLines -join [Environment]::NewLine) | Out-File -FilePath (Join-Path $runFolder 'goal.txt') -Encoding utf8

# Tool paths
$collectScript     = Join-Path $repoRoot 'tools/collect-context.ps1'
$detectScript      = Join-Path $repoRoot 'tools/detect-tests.ps1'
$reviewPromptTool  = Join-Path $repoRoot 'tools/write-claude-review-prompt.ps1'
$codexPromptTool   = Join-Path $repoRoot 'tools/write-codex-implementation-prompt.ps1'
$codexFixTool      = Join-Path $repoRoot 'tools/write-codex-fix-prompt.ps1'
$handoffScript     = Join-Path $repoRoot 'tools/write-final-handoff.ps1'

foreach ($t in @($collectScript, $detectScript, $handoffScript)) {
    if (-not (Test-Path -LiteralPath $t)) {
        Write-Error "Missing tool: $t"
        exit 2
    }
}

# Step: collect git context (initial)
function Invoke-CollectContext {
    param([string]$Folder)
    $failed = $false
    try {
        & $collectScript -RunFolder $Folder
    } catch {
        $failed = $true
        Write-Host "[autopilot] WARNING: collect-context.ps1 threw: $($_.Exception.Message)"
    }
    $expected = @('git-status.txt','git-diff-stat.txt','git-diff-names.txt')
    $miss = @()
    foreach ($cf in $expected) {
        if (-not (Test-Path -LiteralPath (Join-Path $Folder $cf))) {
            $miss += $cf
        }
    }
    if ($miss.Count -gt 0) {
        $failed = $true
        Write-Host ("[autopilot] WARNING: context collection did not produce: {0}" -f ($miss -join ', '))
    }
    return -not $failed
}

[void](Invoke-CollectContext -Folder $runFolder)

# Step: detect tests
try {
    & $detectScript -RunFolder $runFolder
} catch {
    Write-Host "[autopilot] detect-tests.ps1 raised a non-fatal error: $($_.Exception.Message). Continuing."
}

# ---------------- shared state used by helper functions ----------------

$testSummaryPath = Join-Path $runFolder 'test-summary.json'
$testOutputPath  = Join-Path $runFolder 'test-output.txt'
$codexPromptPath = Join-Path $runFolder 'codex-implementation-prompt.md'
$codexFixPromptPath = Join-Path $runFolder 'codex-fix-prompt.md'
$codexOutputPath = Join-Path $runFolder 'codex-output.md'
$reviewPromptPath = Join-Path $runFolder 'claude-review-prompt.md'
$reviewOutputPath = Join-Path $runFolder 'claude-review.md'

# Denylist patterns. Reject command text containing any of these.
$denyPatterns = @(
    'npm\s+install',
    'pnpm\s+install',
    'yarn\s+install',
    'pip\s+install',
    'poetry\s+install',
    'uv\s+add',
    'rm\s+-rf',
    'Remove-Item\s+-Recurse',
    'git\s+reset\s+--hard',
    'git\s+clean',
    'git\s+push',
    'git\s+commit',
    'deploy'
)

function Test-CommandAllowed {
    param([string]$CommandText)
    if ([string]::IsNullOrWhiteSpace($CommandText)) { return $false }
    foreach ($pat in $denyPatterns) {
        if ($CommandText -match $pat) { return $false }
    }
    return $true
}

function Resolve-WorkingDirectoryInsideRepo {
    param([string]$Relative, [string]$RepoRoot)
    if ([string]::IsNullOrWhiteSpace($Relative)) { $Relative = '.' }
    try {
        $candidate = if ([System.IO.Path]::IsPathRooted($Relative)) { $Relative } else { Join-Path $RepoRoot $Relative }
        if (-not (Test-Path -LiteralPath $candidate)) { return $null }
        $resolvedFull = (Resolve-Path -LiteralPath $candidate).ProviderPath
        $rootFull = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
        $resolvedNorm = $resolvedFull.TrimEnd('\','/')
        $rootNorm = $rootFull.TrimEnd('\','/')
        if ($resolvedNorm -eq $rootNorm) { return $resolvedFull }
        if ($resolvedNorm.StartsWith($rootNorm + [System.IO.Path]::DirectorySeparatorChar) -or
            $resolvedNorm.StartsWith($rootNorm + '/')) {
            return $resolvedFull
        }
        return $null
    } catch {
        return $null
    }
}

function Select-TestCommands {
    param($AllCommands, [string]$Level, [bool]$SkipE2EFlag)
    $selected = @()
    foreach ($c in $AllCommands) {
        $cLevel = [string]$c.level
        $isSafe = [bool]$c.safeByDefault
        $include = $false
        switch ($Level) {
            'none'        { $include = $false }
            'unit'        {
                if ($isSafe -and ($cLevel -in @('unit','typecheck','lint'))) { $include = $true }
            }
            'integration' {
                if ($isSafe -and ($cLevel -in @('unit','typecheck','lint','integration'))) { $include = $true }
                if ($cLevel -eq 'e2e' -and (-not $SkipE2EFlag)) { $include = $true }
            }
            'e2e'         {
                if ($cLevel -eq 'e2e' -and (-not $SkipE2EFlag)) { $include = $true }
            }
            'all'         {
                if ($isSafe) { $include = $true }
                if ($cLevel -eq 'e2e' -and (-not $SkipE2EFlag)) { $include = $true }
                if ($cLevel -eq 'e2e' -and $SkipE2EFlag) { $include = $false }
            }
        }
        if ($include) { $selected += $c }
    }
    return ,$selected
}

# ---------------- per-iteration helpers ----------------

function Invoke-CodexIteration {
    param(
        [int]$IterIndex,
        [int]$IterMax,
        [string]$PromptKind,        # 'implementation' | 'fix' | 'none'
        [string]$PrevTestSummary = '',
        [string]$PrevReviewOutput = ''
    )
    # Returns hashtable: status, exitCode, executed, failed, promptPath, outputPath
    $result = @{
        status      = 'not-requested'
        exitCode    = $null
        executed    = $false
        failed      = $false
        promptKind  = $PromptKind
        promptPath  = ''
        outputPath  = ''
    }

    if ($Implementer -ne 'codex' -or $PromptKind -eq 'none') {
        # No Codex artifacts at all this iteration.
        return $result
    }

    # 1. Generate prompt.
    $promptPath = ''
    if ($PromptKind -eq 'implementation') {
        $promptPath = $codexPromptPath
        if (-not (Test-Path -LiteralPath $codexPromptTool)) {
            Write-Host "[autopilot] WARNING: missing tool: $codexPromptTool. Skipping Codex implementation prompt generation."
        } else {
            try {
                & $codexPromptTool -RunFolder $runFolder -Goal $Goal -TaskId $TaskId -TestLevel $TestLevel -SkipE2E:$SkipE2E -DryRun:$DryRun
            } catch {
                Write-Host "[autopilot] WARNING: write-codex-implementation-prompt.ps1 threw: $($_.Exception.Message)"
            }
        }
    } elseif ($PromptKind -eq 'fix') {
        $promptPath = $codexFixPromptPath
        if (-not (Test-Path -LiteralPath $codexFixTool)) {
            Write-Host "[autopilot] WARNING: missing tool: $codexFixTool. Skipping Codex fix prompt generation."
        } else {
            try {
                & $codexFixTool -RunFolder $runFolder -IterationIndex $IterIndex -MaxIterations $IterMax `
                    -Goal $Goal -TaskId $TaskId -TestLevel $TestLevel -SkipE2E:$SkipE2E -DryRun:$DryRun `
                    -PreviousTestSummary $PrevTestSummary -PreviousClaudeReview $PrevReviewOutput
            } catch {
                Write-Host "[autopilot] WARNING: write-codex-fix-prompt.ps1 threw: $($_.Exception.Message)"
            }
        }
    }
    $result.promptPath = $promptPath

    # 2. Decide whether to invoke Codex.
    if (-not $RunImplementer) {
        $placeholder = @(
            ('# Codex Implementation (not executed) — iteration {0}/{1}, prompt={2}' -f $IterIndex, $IterMax, $PromptKind),
            '',
            'Codex implementation was requested but not executed. Use the prompt file manually or rerun with -RunImplementer after verifying local Codex CLI flags.',
            '',
            "Implementer:  $Implementer",
            "CodexCommand: $CodexCommand",
            "CodexSandbox: $CodexSandbox",
            "CodexRunMode: $CodexRunMode",
            'No Codex CLI process was spawned by this run.'
        ) -join [Environment]::NewLine
        $placeholder | Out-File -FilePath $codexOutputPath -Encoding utf8
        $result.status     = 'prompt-generated-not-executed'
        $result.outputPath = $codexOutputPath
        Write-Host ("[autopilot] iter {0}: Implementer=codex (prompt-only). Codex CLI was NOT invoked." -f $IterIndex)
        return $result
    }

    if ($DryRun) {
        $placeholder = @(
            ('# Codex Implementation (not executed - DryRun) — iteration {0}/{1}' -f $IterIndex, $IterMax),
            '',
            '-DryRun is ON, so the harness refused to invoke Codex CLI even though -RunImplementer was specified.',
            'Use the prompt file manually or rerun without -DryRun.',
            '',
            "Implementer:  $Implementer",
            "CodexCommand: $CodexCommand",
            "CodexSandbox: $CodexSandbox",
            "CodexRunMode: $CodexRunMode",
            'No Codex CLI process was spawned by this run.'
        ) -join [Environment]::NewLine
        $placeholder | Out-File -FilePath $codexOutputPath -Encoding utf8
        $result.status     = 'prompt-generated-not-executed'
        $result.outputPath = $codexOutputPath
        Write-Host ("[autopilot] iter {0}: -DryRun suppressed -RunImplementer. Codex CLI was NOT invoked." -f $IterIndex)
        return $result
    }

    Write-Host ("[autopilot] iter {0}: Implementer=codex with -RunImplementer. Attempting one-shot codex exec (--sandbox {1})." -f $IterIndex, $CodexSandbox)

    $codexLines = @()
    $codexLines += ('# Codex Implementation (auto-executed) — iteration {0}/{1}, prompt={2}' -f $IterIndex, $IterMax, $PromptKind)
    $codexLines += ''
    $codexLines += ('Invocation pattern: ' + $CodexCommand + ' exec --sandbox ' + $CodexSandbox + ' <prompt>')
    $codexLines += ''
    $codexLines += "Implementer:  $Implementer"
    $codexLines += "CodexCommand: $CodexCommand"
    $codexLines += "CodexSandbox: $CodexSandbox"
    $codexLines += "CodexRunMode: $CodexRunMode"
    $codexLines += ''

    $cliFound = $null
    try { $cliFound = Get-Command -Name $CodexCommand -ErrorAction Stop } catch { $cliFound = $null }

    $bt2    = [char]96
    $fence2 = '' + $bt2 + $bt2 + $bt2

    if ($null -eq $cliFound) {
        $codexLines += '## Automatic Codex implementation could not be executed safely'
        $codexLines += ''
        $codexLines += ("ERROR: Codex CLI not found on PATH (looked for `'" + $CodexCommand + "`'). No alternative permissive modes were attempted.")
        $codexLines += ''
        $codexLines += 'Use the Codex prompt for manual implementation.'
        ($codexLines -join [Environment]::NewLine) | Out-File -FilePath $codexOutputPath -Encoding utf8
        $result.status     = 'failed-or-unsupported'
        $result.outputPath = $codexOutputPath
        $result.failed     = $true
        Write-Host ("[autopilot] iter {0}: Codex CLI not found. Wrote unsupported-notice." -f $IterIndex)
        return $result
    }

    if (-not (Test-Path -LiteralPath $promptPath)) {
        $codexLines += '## Automatic Codex implementation could not be executed safely'
        $codexLines += ''
        $codexLines += 'ERROR: the Codex prompt file was not generated, so no prompt is available to send to Codex.'
        $codexLines += ''
        $codexLines += 'Inspect earlier console warnings.'
        ($codexLines -join [Environment]::NewLine) | Out-File -FilePath $codexOutputPath -Encoding utf8
        $result.status     = 'failed-or-unsupported'
        $result.outputPath = $codexOutputPath
        $result.failed     = $true
        Write-Host ("[autopilot] iter {0}: No Codex prompt available. Wrote unsupported-notice." -f $IterIndex)
        return $result
    }

    $promptText = Get-Content -LiteralPath $promptPath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($promptText)) { $promptText = '(empty Codex prompt)' }

    $tempErrFile = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-exec-err-" + [System.Guid]::NewGuid().ToString() + ".txt")
    $stdoutText = $null
    $exit       = -1
    $threw      = $null
    $invocation = '(unknown)'

    try {
        $invocation = "$CodexCommand exec --sandbox $CodexSandbox <prompt-as-arg>"
        # SAFE invocation only. Never escalate to permissive sandboxes / bypass flags.
        $stdoutText = & $CodexCommand exec --sandbox $CodexSandbox $promptText 2>$tempErrFile
        $exit = $LASTEXITCODE
    } catch {
        $threw = $_.Exception.Message
    }

    $stderrText = ''
    if (Test-Path -LiteralPath $tempErrFile) {
        try { $stderrText = Get-Content -LiteralPath $tempErrFile -Raw -ErrorAction SilentlyContinue } catch { $stderrText = '' }
        Remove-Item -LiteralPath $tempErrFile -Force -ErrorAction SilentlyContinue
    }

    $stdoutCombined = if ($null -eq $stdoutText) { '' } elseif ($stdoutText -is [string]) { $stdoutText } else { ($stdoutText | Out-String) }
    $stdoutCombined = ($stdoutCombined).TrimEnd()
    $stderrText     = if ($null -eq $stderrText) { '' } else { ([string]$stderrText).TrimEnd() }

    $codexLines += ('Invocation: ' + $invocation)
    $codexLines += ('Exit code: ' + $exit)
    if ($null -ne $threw) {
        $codexLines += ('Invocation threw: ' + $threw)
    }
    $codexLines += ''

    $result.exitCode = $exit

    if ($null -ne $threw -or $exit -ne 0) {
        $codexLines += '## Automatic Codex implementation failed'
        $codexLines += ''
        $codexLines += 'The local Codex CLI did not complete successfully with the safe `codex exec --sandbox workspace-write` invocation. No alternative permissive modes were attempted.'
        $codexLines += ''
        $codexLines += 'Use the Codex prompt for manual implementation.'
        if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
            $codexLines += ''
            $codexLines += '### CLI stderr'
            $codexLines += ''
            $codexLines += $fence2
            $codexLines += $stderrText
            $codexLines += $fence2
        }
        if (-not [string]::IsNullOrWhiteSpace($stdoutCombined)) {
            $codexLines += ''
            $codexLines += '### CLI stdout'
            $codexLines += ''
            $codexLines += $fence2
            $codexLines += $stdoutCombined
            $codexLines += $fence2
        }
        ($codexLines -join [Environment]::NewLine) | Out-File -FilePath $codexOutputPath -Encoding utf8
        $result.status     = 'failed-or-unsupported'
        $result.outputPath = $codexOutputPath
        $result.failed     = $true
        Write-Host ("[autopilot] iter {0}: Codex implementation failed (exit={1})." -f $IterIndex, $exit)
    } else {
        $codexLines += '## Codex execution output'
        $codexLines += ''
        if (-not [string]::IsNullOrWhiteSpace($stdoutCombined)) {
            $codexLines += $fence2
            $codexLines += $stdoutCombined
            $codexLines += $fence2
        } else {
            $codexLines += '(Codex returned no stdout content.)'
        }
        if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
            $codexLines += ''
            $codexLines += '## CLI stderr (informational)'
            $codexLines += ''
            $codexLines += $fence2
            $codexLines += $stderrText
            $codexLines += $fence2
        }
        ($codexLines -join [Environment]::NewLine) | Out-File -FilePath $codexOutputPath -Encoding utf8
        $result.status     = 'executed'
        $result.outputPath = $codexOutputPath
        $result.executed   = $true
        Write-Host ("[autopilot] iter {0}: Codex execution captured." -f $IterIndex)
    }

    # Refresh git context after any execution attempt so the handoff and the
    # next iteration's safety checks reflect post-Codex state.
    [void](Invoke-CollectContext -Folder $runFolder)

    return $result
}

function Invoke-TestIteration {
    param([int]$IterIndex)
    # Returns hashtable: selectedLevel, skipE2E, dryRun, selectedCount, anyFailed,
    # allPassed, noCommandsSelected, note, results, failureFingerprint.

    $execResults     = @()
    $selectedCount   = 0
    $anyFailed       = $false
    $noCommandsSelected = $true
    $execNote        = ''

    if ($DryRun) {
        $execNote = 'DryRun is ON: no test commands were executed even if TestLevel was set.'
        Set-Content -LiteralPath $testOutputPath -Value $execNote -Encoding utf8
        $summary = [ordered]@{
            selectedLevel        = $TestLevel
            skipE2E              = [bool]$SkipE2E
            dryRun               = $true
            noCommandsSelected   = $true
            anyFailed            = $false
            allPassed            = $false
            results              = @()
            note                 = $execNote
        }
        ($summary | ConvertTo-Json -Depth 6) | Out-File -FilePath $testSummaryPath -Encoding utf8

    } elseif ($TestLevel -eq 'none') {
        $execNote = 'TestLevel=none: detection only. No test commands executed.'
        Set-Content -LiteralPath $testOutputPath -Value $execNote -Encoding utf8
        $summary = [ordered]@{
            selectedLevel        = $TestLevel
            skipE2E              = [bool]$SkipE2E
            dryRun               = $false
            noCommandsSelected   = $true
            anyFailed            = $false
            allPassed            = $false
            results              = @()
            note                 = $execNote
        }
        ($summary | ConvertTo-Json -Depth 6) | Out-File -FilePath $testSummaryPath -Encoding utf8

    } else {
        $detectedJsonPath = Join-Path $runFolder 'detected-tests.json'
        $detected = $null
        if (Test-Path -LiteralPath $detectedJsonPath) {
            try {
                $detected = (Get-Content -LiteralPath $detectedJsonPath -Raw) | ConvertFrom-Json
            } catch {
                Write-Host ("[autopilot] iter {0}: Could not parse detected-tests.json: {1}" -f $IterIndex, $_.Exception.Message)
            }
        }

        $allCommands = @()
        if ($null -ne $detected -and $detected.PSObject.Properties.Name -contains 'testCommands' -and $null -ne $detected.testCommands) {
            foreach ($c in $detected.testCommands) {
                if ($null -ne $c) { $allCommands += $c }
            }
        }

        $selectedRaw = @(Select-TestCommands -AllCommands $allCommands -Level $TestLevel -SkipE2EFlag ([bool]$SkipE2E))
        $selected = @()
        foreach ($s in $selectedRaw) { if ($null -ne $s) { $selected += $s } }
        $selectedCount = $selected.Count

        if ($selectedCount -eq 0) {
            $reasonText = if ($null -ne $detected -and ($detected.PSObject.Properties.Name -contains 'noTestsFound') -and $detected.noTestsFound) {
                'detected-tests.json reports noTestsFound=true.'
            } else {
                'No detected commands matched the requested TestLevel under the current SkipE2E setting.'
            }
            $execNote = "TestLevel=${TestLevel}: no commands selected for execution. $reasonText"
            Set-Content -LiteralPath $testOutputPath -Value $execNote -Encoding utf8
            $summary = [ordered]@{
                selectedLevel        = $TestLevel
                skipE2E              = [bool]$SkipE2E
                dryRun               = $false
                noCommandsSelected   = $true
                anyFailed            = $false
                allPassed            = $false
                results              = @()
                note                 = $execNote
            }
            ($summary | ConvertTo-Json -Depth 6) | Out-File -FilePath $testSummaryPath -Encoding utf8

        } else {
            $noCommandsSelected = $false
            $header = "Phase 5 iteration {0}: test execution log`r`nTestLevel: $TestLevel`r`nSkipE2E: $([bool]$SkipE2E)`r`nSelected commands: $selectedCount`r`n" -f $IterIndex
            Set-Content -LiteralPath $testOutputPath -Value $header -Encoding utf8

            foreach ($cmd in $selected) {
                $cmdId    = [string]$cmd.id
                $cmdText  = [string]$cmd.command
                $cmdWdRel = [string]$cmd.workingDirectory
                $cmdLevel = [string]$cmd.level

                $banner = "`r`n----- [$cmdId] level=$cmdLevel cwd=$cmdWdRel -----`r`n$ $cmdText`r`n"
                Add-Content -LiteralPath $testOutputPath -Value $banner -Encoding utf8

                if (-not (Test-CommandAllowed -CommandText $cmdText)) {
                    $msg = "[skip] Command rejected by denylist (install/destructive/git/deploy pattern)."
                    Add-Content -LiteralPath $testOutputPath -Value $msg -Encoding utf8
                    $execResults += [ordered]@{
                        id               = $cmdId
                        command          = $cmdText
                        workingDirectory = $cmdWdRel
                        level            = $cmdLevel
                        skipped          = $true
                        skipReason       = 'denylist'
                        startTime        = $null
                        endTime          = $null
                        exitCode         = $null
                        passed           = $false
                    }
                    $anyFailed = $true
                    continue
                }

                $resolvedWd = Resolve-WorkingDirectoryInsideRepo -Relative $cmdWdRel -RepoRoot $repoRoot
                if ($null -eq $resolvedWd) {
                    $msg = "[skip] Working directory does not resolve inside repo: $cmdWdRel"
                    Add-Content -LiteralPath $testOutputPath -Value $msg -Encoding utf8
                    $execResults += [ordered]@{
                        id               = $cmdId
                        command          = $cmdText
                        workingDirectory = $cmdWdRel
                        level            = $cmdLevel
                        skipped          = $true
                        skipReason       = 'working-directory-outside-repo'
                        startTime        = $null
                        endTime          = $null
                        exitCode         = $null
                        passed           = $false
                    }
                    $anyFailed = $true
                    continue
                }

                $startTime = (Get-Date).ToString('o')
                $exitCode  = $null
                $passed    = $false
                try {
                    Push-Location -LiteralPath $resolvedWd
                    $output = & cmd.exe /c "$cmdText 2>&1"
                    $exitCode = $LASTEXITCODE
                    if ($null -ne $output) {
                        foreach ($line in @($output)) {
                            Add-Content -LiteralPath $testOutputPath -Value ([string]$line) -Encoding utf8
                        }
                    }
                    $passed = ($exitCode -eq 0)
                } catch {
                    $errLine = "[error] Execution threw: $($_.Exception.Message)"
                    Add-Content -LiteralPath $testOutputPath -Value $errLine -Encoding utf8
                    $exitCode = -1
                    $passed = $false
                } finally {
                    Pop-Location
                }
                $endTime = (Get-Date).ToString('o')

                if (-not $passed) { $anyFailed = $true }

                $execResults += [ordered]@{
                    id               = $cmdId
                    command          = $cmdText
                    workingDirectory = $cmdWdRel
                    level            = $cmdLevel
                    skipped           = $false
                    skipReason       = $null
                    startTime        = $startTime
                    endTime          = $endTime
                    exitCode         = $exitCode
                    passed           = $passed
                }

                $tail = "[done] exitCode=$exitCode passed=$passed"
                Add-Content -LiteralPath $testOutputPath -Value $tail -Encoding utf8
            }

            $allPassed = ($selectedCount -gt 0 -and -not $anyFailed)
            $summary = [ordered]@{
                selectedLevel        = $TestLevel
                skipE2E              = [bool]$SkipE2E
                dryRun               = $false
                noCommandsSelected   = $false
                anyFailed            = $anyFailed
                allPassed            = $allPassed
                results              = $execResults
                note                 = ("Executed {0} command(s). anyFailed={1}" -f $selectedCount, $anyFailed)
            }
            ($summary | ConvertTo-Json -Depth 6) | Out-File -FilePath $testSummaryPath -Encoding utf8
        }
    }

    # Build a stable failure fingerprint for repeated-failure detection.
    $failedIds = @()
    foreach ($r in $execResults) {
        if ($null -ne $r -and -not [bool]$r.passed) {
            $failedIds += [string]$r.id
        }
    }
    $failedIds = $failedIds | Sort-Object -Unique
    $fingerprint = ''
    if ($failedIds.Count -gt 0) {
        $fingerprint = 'failedTests:' + ($failedIds -join ',')
    } elseif ($noCommandsSelected) {
        $fingerprint = 'no-commands-selected'
    } else {
        $fingerprint = 'all-tests-passed'
    }

    return @{
        selectedLevel       = $TestLevel
        skipE2E             = [bool]$SkipE2E
        dryRun              = [bool]$DryRun
        selectedCount       = $selectedCount
        anyFailed           = $anyFailed
        allPassed           = ($selectedCount -gt 0 -and -not $anyFailed)
        noCommandsSelected  = $noCommandsSelected
        note                = $execNote
        results             = $execResults
        failureFingerprint  = $fingerprint
    }
}

function Invoke-ReviewIteration {
    param([int]$IterIndex)
    # Returns hashtable: executed, verdict, promptPath, outputPath, mode

    $result = @{
        executed    = $false
        verdict     = ''
        promptPath  = ''
        outputPath  = ''
        mode        = ''
    }

    if ($Reviewer -ne 'claude') {
        $result.mode = 'disabled (Reviewer=none)'
        return $result
    }

    if (-not (Test-Path -LiteralPath $reviewPromptTool)) {
        Write-Host "[autopilot] WARNING: missing tool: $reviewPromptTool. Skipping Claude review prompt generation."
    } else {
        try {
            & $reviewPromptTool -RunFolder $runFolder -Goal $Goal -TaskId $TaskId -TestLevel $TestLevel -SkipE2E:$SkipE2E -DryRun:$DryRun
        } catch {
            Write-Host "[autopilot] WARNING: write-claude-review-prompt.ps1 threw: $($_.Exception.Message)"
        }
    }
    $result.promptPath = $reviewPromptPath

    if (-not $RunReviewer) {
        $placeholder = @(
            ('# Claude Review (not executed) — iteration {0}' -f $IterIndex),
            '',
            'Claude review was requested but not executed. Use claude-review-prompt.md manually or rerun with -RunReviewer after verifying local Claude CLI headless flags.',
            '',
            "Mode: $ClaudeReviewMode",
            'No Claude CLI process was spawned by this run.'
        ) -join [Environment]::NewLine
        $placeholder | Out-File -FilePath $reviewOutputPath -Encoding utf8
        $result.mode       = "prompt-only (mode=$ClaudeReviewMode)"
        $result.outputPath = $reviewOutputPath
        Write-Host ("[autopilot] iter {0}: Reviewer=claude (prompt-only). Claude CLI was NOT invoked." -f $IterIndex)
        return $result
    }

    if ($DryRun) {
        $placeholder = @(
            ('# Claude Review (not executed - DryRun) — iteration {0}' -f $IterIndex),
            '',
            '-DryRun is ON, so the harness refused to invoke Claude CLI even though -RunReviewer was specified.',
            '',
            "Mode: $ClaudeReviewMode",
            'No Claude CLI process was spawned by this run.'
        ) -join [Environment]::NewLine
        $placeholder | Out-File -FilePath $reviewOutputPath -Encoding utf8
        $result.mode       = "prompt-only (DryRun suppressed -RunReviewer; mode=$ClaudeReviewMode)"
        $result.outputPath = $reviewOutputPath
        Write-Host ("[autopilot] iter {0}: -DryRun suppressed -RunReviewer. Claude CLI was NOT invoked." -f $IterIndex)
        return $result
    }

    Write-Host ("[autopilot] iter {0}: Reviewer=claude with -RunReviewer. Attempting review-only Claude invocation." -f $IterIndex)
    $reviewLines = @()
    $reviewLines += ('# Claude Review (auto-executed) — iteration {0}' -f $IterIndex)
    $reviewLines += ''
    $reviewLines += ('Invocation pattern: ' + $ClaudeCommand + ' -p <prompt> --output-format text --tools ""')
    $reviewLines += ''
    $cliFound = $null
    try { $cliFound = Get-Command -Name $ClaudeCommand -ErrorAction Stop } catch { $cliFound = $null }

    if ($null -eq $cliFound) {
        $reviewLines += '## Automatic Claude review could not be executed safely'
        $reviewLines += ''
        $reviewLines += ("ERROR: Claude CLI not found on PATH (looked for `'" + $ClaudeCommand + "`'). No alternative permissive modes were attempted.")
        $reviewLines += ''
        $reviewLines += 'Use claude-review-prompt.md for manual review.'
        ($reviewLines -join [Environment]::NewLine) | Out-File -FilePath $reviewOutputPath -Encoding utf8
        $result.mode       = "auto-execute (mode=$ClaudeReviewMode, CLI not found)"
        $result.outputPath = $reviewOutputPath
        Write-Host ("[autopilot] iter {0}: Claude CLI not found." -f $IterIndex)
        return $result
    }

    if (-not (Test-Path -LiteralPath $reviewPromptPath)) {
        $reviewLines += '## Automatic Claude review could not be executed safely'
        $reviewLines += ''
        $reviewLines += 'ERROR: claude-review-prompt.md was not generated, so no prompt is available to send to Claude.'
        ($reviewLines -join [Environment]::NewLine) | Out-File -FilePath $reviewOutputPath -Encoding utf8
        $result.mode       = "auto-execute (mode=$ClaudeReviewMode, no prompt)"
        $result.outputPath = $reviewOutputPath
        Write-Host ("[autopilot] iter {0}: No review prompt available." -f $IterIndex)
        return $result
    }

    $promptText = Get-Content -LiteralPath $reviewPromptPath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($promptText)) { $promptText = '(empty review prompt)' }

    $tempErrFile = Join-Path ([System.IO.Path]::GetTempPath()) ("claude-review-err-" + [System.Guid]::NewGuid().ToString() + ".txt")
    $stdoutText = $null
    $exit       = -1
    $threw      = $null
    try {
        $stdoutText = $promptText | & $ClaudeCommand -p --output-format text --tools "" 2>$tempErrFile
        $exit = $LASTEXITCODE
    } catch {
        $threw = $_.Exception.Message
    }
    $stderrText = ''
    if (Test-Path -LiteralPath $tempErrFile) {
        try { $stderrText = Get-Content -LiteralPath $tempErrFile -Raw -ErrorAction SilentlyContinue } catch { $stderrText = '' }
        Remove-Item -LiteralPath $tempErrFile -Force -ErrorAction SilentlyContinue
    }

    $stdoutCombined = if ($null -eq $stdoutText) { '' } elseif ($stdoutText -is [string]) { $stdoutText } else { ($stdoutText | Out-String) }
    $stdoutCombined = ($stdoutCombined).TrimEnd()
    $stderrText     = if ($null -eq $stderrText) { '' } else { ([string]$stderrText).TrimEnd() }

    $reviewLines += ("Exit code: " + $exit)
    if ($null -ne $threw) {
        $reviewLines += ("Invocation threw: " + $threw)
    }
    $reviewLines += ''

    $bt2    = [char]96
    $fence2 = '' + $bt2 + $bt2 + $bt2

    if ($null -ne $threw -or $exit -ne 0 -or [string]::IsNullOrWhiteSpace($stdoutCombined)) {
        $reviewLines += '## Automatic Claude review could not be executed safely'
        $reviewLines += ''
        $reviewLines += 'The local Claude CLI did not return a usable review with the safest review-only invocation pattern. No alternative permissive modes were attempted.'
        $reviewLines += ''
        $reviewLines += 'Use claude-review-prompt.md for manual review.'
        if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
            $reviewLines += ''
            $reviewLines += '### CLI stderr'
            $reviewLines += ''
            $reviewLines += $fence2
            $reviewLines += $stderrText
            $reviewLines += $fence2
        }
        if (-not [string]::IsNullOrWhiteSpace($stdoutCombined)) {
            $reviewLines += ''
            $reviewLines += '### CLI stdout'
            $reviewLines += ''
            $reviewLines += $fence2
            $reviewLines += $stdoutCombined
            $reviewLines += $fence2
        }
        ($reviewLines -join [Environment]::NewLine) | Out-File -FilePath $reviewOutputPath -Encoding utf8
        $result.mode       = "auto-execute (mode=$ClaudeReviewMode)"
        $result.outputPath = $reviewOutputPath
        Write-Host ("[autopilot] iter {0}: Claude review unsupported or failed." -f $IterIndex)
        return $result
    }

    $reviewLines += '## Claude review output'
    $reviewLines += ''
    $reviewLines += $stdoutCombined
    if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
        $reviewLines += ''
        $reviewLines += '## CLI stderr (informational)'
        $reviewLines += ''
        $reviewLines += $fence2
        $reviewLines += $stderrText
        $reviewLines += $fence2
    }
    ($reviewLines -join [Environment]::NewLine) | Out-File -FilePath $reviewOutputPath -Encoding utf8
    $result.mode       = "auto-execute (mode=$ClaudeReviewMode)"
    $result.outputPath = $reviewOutputPath

    # Parse verdict from the captured Claude review.
    $captured = $stdoutCombined
    if ($captured -match '(?ms)^##\s*Verdict\s*$\s*\n+\s*(approve|request_changes|block)\b') {
        $result.verdict  = $matches[1].ToLowerInvariant()
        $result.executed = $true
    } elseif ($captured -match '(?im)^Verdict\s*:\s*(approve|request_changes|block)\b') {
        $result.verdict  = $matches[1].ToLowerInvariant()
        $result.executed = $true
    }
    Write-Host ("[autopilot] iter {0}: Claude review captured (verdict={1})." -f $IterIndex, $(if ([string]::IsNullOrWhiteSpace($result.verdict)) { '(none)' } else { $result.verdict }))
    return $result
}

# ---------------- diff observation helpers ----------------

function Measure-DiffArtifacts {
    param([string]$Folder)
    # Returns @{ changedFiles, diffStatLines, hasSecretLikePaths }
    $namesPath = Join-Path $Folder 'git-diff-names.txt'
    $statPath  = Join-Path $Folder 'git-diff-stat.txt'
    $changed = 0
    $hasSecret = $false
    if (Test-Path -LiteralPath $namesPath) {
        $lines = Get-Content -LiteralPath $namesPath -ErrorAction SilentlyContinue
        if ($null -ne $lines) {
            foreach ($l in $lines) {
                $t = ([string]$l).Trim()
                if ([string]::IsNullOrWhiteSpace($t)) { continue }
                $changed++
                if ($t -match '\[redacted secret-like path\]') { $hasSecret = $true }
                # Defense in depth: also flag explicit secret-shaped names that
                # somehow slipped past collect-context's filter.
                elseif ($t -match '(^|/)\.env(\.|$)' -or $t -match '\.pem$' -or $t -match '\.key$' -or $t -match 'secret' -or $t -match 'credentials') {
                    $hasSecret = $true
                }
            }
        }
    }

    $diffLines = 0
    if (Test-Path -LiteralPath $statPath) {
        $statText = Get-Content -LiteralPath $statPath -Raw -ErrorAction SilentlyContinue
        if (-not [string]::IsNullOrWhiteSpace($statText)) {
            $insertion = 0
            $deletion  = 0
            if ($statText -match '(\d+)\s+insertions?\(\+\)') { $insertion = [int]$matches[1] }
            if ($statText -match '(\d+)\s+deletions?\(-\)')   { $deletion  = [int]$matches[1] }
            if ($insertion -eq 0 -and $deletion -eq 0) {
                # Fallback: count non-empty stat rows (one per changed file plus summary).
                $rows = ($statText -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                $diffLines = [int]([math]::Max(0, $rows.Count - 1))
            } else {
                $diffLines = $insertion + $deletion
            }
        }
    }

    return @{
        changedFiles        = $changed
        diffStatLines       = $diffLines
        hasSecretLikePaths  = $hasSecret
    }
}

# ---------------- iteration snapshotter ----------------

function Snapshot-IterationArtifacts {
    param([int]$IterIndex, [string]$CodexPromptKind)
    $pad = "{0:00}" -f $IterIndex
    $copies = @{}
    if ($CodexPromptKind -eq 'implementation') {
        $copies[$codexPromptPath] = (Join-Path $runFolder ("iteration-{0}-codex-implementation-prompt.md" -f $pad))
    } elseif ($CodexPromptKind -eq 'fix') {
        $copies[$codexFixPromptPath] = (Join-Path $runFolder ("iteration-{0}-codex-fix-prompt.md" -f $pad))
    }
    $copies[$codexOutputPath]  = (Join-Path $runFolder ("iteration-{0}-codex-output.md" -f $pad))
    $copies[$testSummaryPath]  = (Join-Path $runFolder ("iteration-{0}-test-summary.json" -f $pad))
    $copies[$testOutputPath]   = (Join-Path $runFolder ("iteration-{0}-test-output.txt" -f $pad))
    $copies[$reviewPromptPath] = (Join-Path $runFolder ("iteration-{0}-claude-review-prompt.md" -f $pad))
    $copies[$reviewOutputPath] = (Join-Path $runFolder ("iteration-{0}-claude-review.md" -f $pad))

    foreach ($src in $copies.Keys) {
        if (Test-Path -LiteralPath $src) {
            try {
                Copy-Item -LiteralPath $src -Destination $copies[$src] -Force
            } catch {
                Write-Host ("[autopilot] iter {0}: WARNING: failed to snapshot {1}: {2}" -f $IterIndex, $src, $_.Exception.Message)
            }
        }
    }
}

function Write-IterationSummary {
    # Inlined from the (now-removed) tools/write-iteration-summary.ps1 helper
    # so the Phase 5 allowed-files list only contains tools/write-codex-fix-prompt.ps1
    # as a NEW Phase 5 tool. Emits iteration-XX-summary.md and iteration-XX-decision.json
    # under the run folder.
    param(
        [int]$IterIndex,
        [string]$CodexStatus = 'not-requested',
        $CodexExitCode = $null,
        [string]$CodexPromptKind = 'none',
        [string]$CodexPromptPath = '',
        [string]$CodexOutputPath = '',
        [string]$TestSelectedLevel = 'none',
        [bool]$TestSkipE2EFlag = $false,
        [bool]$TestDryRunFlag = $false,
        [bool]$TestNoCommandsSelected = $true,
        [bool]$TestAnyFailed = $false,
        [bool]$TestAllPassed = $false,
        [int]$TestSelectedCount = 0,
        [string]$TestNote = '',
        [string]$TestSummaryPathLocal = '',
        [string]$TestOutputPathLocal = '',
        [string]$FailureFingerprint = '',
        [string]$ReviewerMode = 'none',
        [bool]$ReviewExecuted = $false,
        [string]$ReviewVerdict = '',
        [string]$ReviewPromptPathLocal = '',
        [string]$ReviewOutputPathLocal = '',
        [ValidateSet('continue','stop','halt')]
        [string]$DecisionAction,
        [string]$DecisionReason,
        [bool]$StopUnsafeDiff = $false,
        [bool]$StopSecretLikePathsLocal = $false,
        [bool]$StopChangedFilesExceededLocal = $false,
        [bool]$StopDiffStatExceededLocal = $false,
        [bool]$StopRepeatedFailureLocal = $false,
        [bool]$StopCodexFailedLocal = $false,
        [bool]$EnableFixLoopFlag = $false,
        [string]$FixTriggerLocal = 'tests-or-claude',
        [int]$MaxChangedFilesLocal = 0,
        [int]$MaxDiffStatLinesLocal = 0,
        [int]$ChangedFilesObserved = 0,
        [int]$DiffStatLinesObserved = 0
    )

    $pad = "{0:00}" -f $IterIndex
    $summaryMd  = Join-Path $runFolder ("iteration-{0}-summary.md" -f $pad)
    $decisionJs = Join-Path $runFolder ("iteration-{0}-decision.json" -f $pad)

    $displayPath = {
        param($P)
        if ([string]::IsNullOrWhiteSpace($P)) { return '(not generated)' }
        if (-not (Test-Path -LiteralPath $P)) { return '(not generated)' }
        return $P
    }

    $displayVerdict = {
        param($V)
        if ([string]::IsNullOrWhiteSpace($V)) { return '(not detected)' }
        return $V
    }

    $nextIter = $null
    if ($DecisionAction -eq 'continue') { $nextIter = $IterIndex + 1 }

    $decision = [ordered]@{
        iteration              = $IterIndex
        maxIterations          = $MaxIterations
        enableFixLoop          = $EnableFixLoopFlag
        fixTrigger             = $FixTriggerLocal
        codex = [ordered]@{
            promptKind  = $CodexPromptKind
            status      = $CodexStatus
            exitCode    = $CodexExitCode
            promptPath  = $CodexPromptPath
            outputPath  = $CodexOutputPath
        }
        tests = [ordered]@{
            selectedLevel       = $TestSelectedLevel
            skipE2E             = $TestSkipE2EFlag
            dryRun              = $TestDryRunFlag
            selectedCount       = $TestSelectedCount
            noCommandsSelected  = $TestNoCommandsSelected
            anyFailed           = $TestAnyFailed
            allPassed           = $TestAllPassed
            note                = $TestNote
            summaryPath         = $TestSummaryPathLocal
            outputPath          = $TestOutputPathLocal
            failureFingerprint  = $FailureFingerprint
        }
        review = [ordered]@{
            mode        = $ReviewerMode
            executed    = $ReviewExecuted
            verdict     = $ReviewVerdict
            promptPath  = $ReviewPromptPathLocal
            outputPath  = $ReviewOutputPathLocal
        }
        diffLimits = [ordered]@{
            maxChangedFiles       = $MaxChangedFilesLocal
            maxDiffStatLines      = $MaxDiffStatLinesLocal
            changedFilesObserved  = $ChangedFilesObserved
            diffStatLinesObserved = $DiffStatLinesObserved
        }
        stopSignals = [ordered]@{
            codexFailed              = $StopCodexFailedLocal
            unsafeDiff               = $StopUnsafeDiff
            secretLikePathsInDiff    = $StopSecretLikePathsLocal
            changedFilesExceeded     = $StopChangedFilesExceededLocal
            diffStatLinesExceeded    = $StopDiffStatExceededLocal
            repeatedFailure          = $StopRepeatedFailureLocal
        }
        decision = [ordered]@{
            action        = $DecisionAction
            reason        = $DecisionReason
            nextIteration = $nextIter
        }
    }
    ($decision | ConvertTo-Json -Depth 8) | Out-File -FilePath $decisionJs -Encoding utf8

    $lines = @()
    $lines += ("# Iteration {0} of {1}" -f $IterIndex, $MaxIterations)
    $lines += ''
    $lines += '## Loop Configuration'
    $lines += ''
    $lines += ('- EnableFixLoop: {0}' -f $EnableFixLoopFlag)
    $lines += ('- FixTrigger: {0}' -f $FixTriggerLocal)
    $lines += ('- MaxIterations: {0}' -f $MaxIterations)
    $lines += ('- MaxChangedFiles: {0}' -f $MaxChangedFilesLocal)
    $lines += ('- MaxDiffStatLines: {0}' -f $MaxDiffStatLinesLocal)
    $lines += ''
    $lines += '## Codex'
    $lines += ''
    $lines += ('- Prompt kind: {0}' -f $CodexPromptKind)
    $lines += ('- Status: {0}' -f $CodexStatus)
    if ($null -ne $CodexExitCode) {
        $lines += ('- Exit code: {0}' -f $CodexExitCode)
    } else {
        $lines += '- Exit code: (not captured)'
    }
    $lines += ('- Prompt: {0}' -f (& $displayPath $CodexPromptPath))
    $lines += ('- Output: {0}' -f (& $displayPath $CodexOutputPath))
    $lines += ''
    $lines += '## Tests'
    $lines += ''
    $lines += ('- Selected TestLevel: {0}' -f $TestSelectedLevel)
    $lines += ('- SkipE2E: {0}' -f $TestSkipE2EFlag)
    $lines += ('- DryRun: {0}' -f $TestDryRunFlag)
    $lines += ('- Commands selected: {0}' -f $TestSelectedCount)
    $lines += ('- No commands selected: {0}' -f $TestNoCommandsSelected)
    $lines += ('- Any failed: {0}' -f $TestAnyFailed)
    $lines += ('- All passed: {0}' -f $TestAllPassed)
    if (-not [string]::IsNullOrWhiteSpace($TestNote)) {
        $lines += ('- Note: {0}' -f $TestNote)
    }
    $lines += ('- Summary: {0}' -f (& $displayPath $TestSummaryPathLocal))
    $lines += ('- Log: {0}' -f (& $displayPath $TestOutputPathLocal))
    if (-not [string]::IsNullOrWhiteSpace($FailureFingerprint)) {
        $lines += ('- Failure fingerprint: {0}' -f $FailureFingerprint)
    }
    $lines += ''
    $lines += '## Claude Review'
    $lines += ''
    $lines += ('- Mode: {0}' -f $ReviewerMode)
    $lines += ('- Executed: {0}' -f $ReviewExecuted)
    $lines += ('- Verdict: {0}' -f (& $displayVerdict $ReviewVerdict))
    $lines += ('- Prompt: {0}' -f (& $displayPath $ReviewPromptPathLocal))
    $lines += ('- Output: {0}' -f (& $displayPath $ReviewOutputPathLocal))
    $lines += ''
    $lines += '## Diff Observations'
    $lines += ''
    $lines += ('- Changed files observed: {0} (limit: {1})' -f $ChangedFilesObserved, $MaxChangedFilesLocal)
    $lines += ('- Diff stat insertions+deletions observed: {0} (limit: {1})' -f $DiffStatLinesObserved, $MaxDiffStatLinesLocal)
    $lines += ''
    $lines += '## Stop Signals'
    $lines += ''
    $lines += ('- Codex failed: {0}' -f $StopCodexFailedLocal)
    $lines += ('- Unsafe diff: {0}' -f $StopUnsafeDiff)
    $lines += ('- Secret-like paths in diff: {0}' -f $StopSecretLikePathsLocal)
    $lines += ('- Changed-file count exceeded: {0}' -f $StopChangedFilesExceededLocal)
    $lines += ('- Diff-stat lines exceeded: {0}' -f $StopDiffStatExceededLocal)
    $lines += ('- Repeated failure fingerprint: {0}' -f $StopRepeatedFailureLocal)
    $lines += ''
    $lines += '## Decision'
    $lines += ''
    $lines += ('- Action: {0}' -f $DecisionAction)
    $lines += ('- Reason: {0}' -f $DecisionReason)
    if ($null -ne $nextIter) {
        $lines += ('- Next iteration: {0}' -f $nextIter)
    } else {
        $lines += '- Next iteration: (none)'
    }
    $lines += ''
    $lines += '---'
    $lines += ''
    $lines += '**No commit, push, or deploy was performed by this iteration. Human review is still required.**'

    ($lines -join [Environment]::NewLine) | Out-File -FilePath $summaryMd -Encoding utf8

    Write-Host ("[autopilot] iter {0}: wrote iteration-{1}-summary.md and iteration-{1}-decision.json" -f $IterIndex, $pad)
}

# ---------------- main loop ----------------

$iterationDecisions = @()
$lastFingerprint    = ''
$loopStopReason     = ''
$terminalAction     = 'stop'
$terminalIteration  = 0

$noAutomatedVerification = $false   # last iteration's snapshot

for ($iter = 1; $iter -le $MaxIterations; $iter++) {
    Write-Host ''
    Write-Host ("=== iteration {0}/{1} ===" -f $iter, $MaxIterations)

    # Decide which Codex prompt to use this iteration.
    $promptKind = 'none'
    if ($Implementer -eq 'codex') {
        if ($iter -eq 1) {
            $promptKind = 'implementation'
        } else {
            $promptKind = 'fix'
        }
    }

    $prevTestSummaryPath = ''
    $prevReviewOutputPath = ''
    if ($iter -ge 2) {
        $prevPad = "{0:00}" -f ($iter - 1)
        $cand = Join-Path $runFolder ("iteration-{0}-test-summary.json" -f $prevPad)
        if (Test-Path -LiteralPath $cand) { $prevTestSummaryPath = $cand }
        $cand = Join-Path $runFolder ("iteration-{0}-claude-review.md" -f $prevPad)
        if (Test-Path -LiteralPath $cand) { $prevReviewOutputPath = $cand }
    }

    $codexResult = Invoke-CodexIteration -IterIndex $iter -IterMax $MaxIterations `
        -PromptKind $promptKind `
        -PrevTestSummary $prevTestSummaryPath `
        -PrevReviewOutput $prevReviewOutputPath

    $testResult = Invoke-TestIteration -IterIndex $iter

    $reviewResult = Invoke-ReviewIteration -IterIndex $iter

    # Observe diff state AFTER all of this iteration's work.
    $diffObs = Measure-DiffArtifacts -Folder $runFolder

    $stopCodexFailed         = [bool]$codexResult.failed
    # Secret-like-path detection is always a halt (security-sensitive), regardless of loop state.
    $stopSecretLikePaths     = [bool]$diffObs.hasSecretLikePaths
    # Diff-size halts and repeated-failure halts are loop-budget concerns; they only
    # influence the terminal action when the loop is actually enabled. Without
    # -EnableFixLoop the harness behaves like Phase 4 (single iteration), so these
    # signals are recorded for inspection but do not promote the iteration to "halt".
    $changedFilesObserved    = [int]$diffObs.changedFiles
    $diffStatLinesObserved   = [int]$diffObs.diffStatLines
    $stopChangedFilesExceed  = ($EnableFixLoop -and $MaxChangedFiles -gt 0 -and $changedFilesObserved -gt $MaxChangedFiles)
    $stopDiffStatExceed      = ($EnableFixLoop -and $MaxDiffStatLines -gt 0 -and $diffStatLinesObserved -gt $MaxDiffStatLines)
    $stopUnsafeDiff          = ($stopSecretLikePaths -or $stopChangedFilesExceed -or $stopDiffStatExceed)

    # Repeated failure fingerprint (compares against the previous iteration only).
    $fingerprint = $testResult.failureFingerprint
    if ($reviewResult.executed -and -not [string]::IsNullOrWhiteSpace($reviewResult.verdict)) {
        $fingerprint = $fingerprint + '|review:' + $reviewResult.verdict
    } elseif ($Reviewer -eq 'claude' -and -not $reviewResult.executed) {
        $fingerprint = $fingerprint + '|review:none-executed'
    }
    $stopRepeatedFailure = $false
    if ($EnableFixLoop -and $iter -ge 2 -and -not [string]::IsNullOrWhiteSpace($lastFingerprint) -and ($fingerprint -eq $lastFingerprint)) {
        $stopRepeatedFailure = $true
    }

    $noAutomatedVerification = (
        ($TestLevel -eq 'none') -or
        $testResult.dryRun -or
        $testResult.noCommandsSelected
    )

    # Decision logic.
    $action = 'stop'
    $reason = ''

    if ($stopCodexFailed) {
        $action = 'halt'; $reason = 'codex-failed-or-unsupported'
    } elseif ($stopSecretLikePaths) {
        $action = 'halt'; $reason = 'secret-like-paths-in-diff'
    } elseif ($stopChangedFilesExceed) {
        $action = 'halt'; $reason = ("max-changed-files-exceeded ({0} > {1})" -f $diffObs.changedFiles, $MaxChangedFiles)
    } elseif ($stopDiffStatExceed) {
        $action = 'halt'; $reason = ("max-diff-stat-exceeded ({0} > {1})" -f $diffObs.diffStatLines, $MaxDiffStatLines)
    } elseif ($stopRepeatedFailure) {
        $action = 'halt'; $reason = 'repeated-failure-fingerprint'
    } elseif ($reviewResult.executed -and $reviewResult.verdict -eq 'block') {
        $action = 'halt'; $reason = 'claude-verdict-block'
    } elseif ($reviewResult.executed -and $reviewResult.verdict -eq 'approve') {
        $action = 'stop'; $reason = 'claude-verdict-approve'
    } elseif (-not $EnableFixLoop) {
        $action = 'stop'; $reason = 'fix-loop-disabled'
    } elseif ($iter -ge $MaxIterations) {
        $action = 'stop'; $reason = 'iteration-budget-exhausted'
    } elseif (-not $codexResult.executed) {
        # Cannot fix what Codex never wrote.
        $action = 'stop'; $reason = 'no-codex-execution-cannot-fix'
    } else {
        $canFixForTests  = (($FixTrigger -eq 'tests'  -or $FixTrigger -eq 'tests-or-claude') -and $testResult.anyFailed)
        $canFixForReview = (($FixTrigger -eq 'claude' -or $FixTrigger -eq 'tests-or-claude') -and $reviewResult.executed -and $reviewResult.verdict -eq 'request_changes')
        if ($canFixForTests -or $canFixForReview) {
            $action = 'continue'; $reason = 'fixable-failure-detected'
        } elseif (-not $reviewResult.executed -and $Reviewer -eq 'claude') {
            $action = 'stop'; $reason = 'claude-review-not-executed-no-fixable-failure'
        } elseif (-not $reviewResult.executed -and $Reviewer -ne 'claude') {
            $action = 'stop'; $reason = 'no-claude-verdict-and-no-fixable-failure'
        } elseif ($reviewResult.verdict -eq 'request_changes' -and -not $canFixForReview) {
            $action = 'stop'; $reason = 'request-changes-but-trigger-disallows'
        } elseif ($testResult.anyFailed -and -not $canFixForTests) {
            $action = 'stop'; $reason = 'tests-failed-but-trigger-disallows'
        } else {
            $action = 'stop'; $reason = 'no-fix-needed'
        }
    }

    # Emit per-iteration artifacts.
    Snapshot-IterationArtifacts -IterIndex $iter -CodexPromptKind $promptKind

    try {
        Write-IterationSummary `
            -IterIndex $iter `
            -CodexStatus $codexResult.status `
            -CodexExitCode $codexResult.exitCode `
            -CodexPromptKind $promptKind `
            -CodexPromptPath $codexResult.promptPath `
            -CodexOutputPath $codexResult.outputPath `
            -TestSelectedLevel $TestLevel `
            -TestSkipE2EFlag ([bool]$SkipE2E) `
            -TestDryRunFlag ([bool]$DryRun) `
            -TestNoCommandsSelected ([bool]$testResult.noCommandsSelected) `
            -TestAnyFailed ([bool]$testResult.anyFailed) `
            -TestAllPassed ([bool]$testResult.allPassed) `
            -TestSelectedCount ([int]$testResult.selectedCount) `
            -TestNote ($testResult.note) `
            -TestSummaryPathLocal $testSummaryPath `
            -TestOutputPathLocal $testOutputPath `
            -FailureFingerprint $fingerprint `
            -ReviewerMode ($reviewResult.mode) `
            -ReviewExecuted ([bool]$reviewResult.executed) `
            -ReviewVerdict ($reviewResult.verdict) `
            -ReviewPromptPathLocal ($reviewResult.promptPath) `
            -ReviewOutputPathLocal ($reviewResult.outputPath) `
            -DecisionAction $action `
            -DecisionReason $reason `
            -StopUnsafeDiff $stopUnsafeDiff `
            -StopSecretLikePathsLocal $stopSecretLikePaths `
            -StopChangedFilesExceededLocal $stopChangedFilesExceed `
            -StopDiffStatExceededLocal $stopDiffStatExceed `
            -StopRepeatedFailureLocal $stopRepeatedFailure `
            -StopCodexFailedLocal $stopCodexFailed `
            -EnableFixLoopFlag ([bool]$EnableFixLoop) `
            -FixTriggerLocal $FixTrigger `
            -MaxChangedFilesLocal $MaxChangedFiles `
            -MaxDiffStatLinesLocal $MaxDiffStatLines `
            -ChangedFilesObserved ([int]$diffObs.changedFiles) `
            -DiffStatLinesObserved ([int]$diffObs.diffStatLines)
    } catch {
        Write-Host "[autopilot] iter ${iter}: WARNING: Write-IterationSummary threw: $($_.Exception.Message)"
    }

    $iterationDecisions += [ordered]@{
        iteration       = $iter
        codexStatus     = $codexResult.status
        codexExecuted   = $codexResult.executed
        codexFailed     = $codexResult.failed
        testsAnyFailed  = $testResult.anyFailed
        testsAllPassed  = $testResult.allPassed
        reviewExecuted  = $reviewResult.executed
        reviewVerdict   = $reviewResult.verdict
        action          = $action
        reason          = $reason
        fingerprint     = $fingerprint
        changedFiles    = $diffObs.changedFiles
        diffStatLines   = $diffObs.diffStatLines
    }

    $lastFingerprint   = $fingerprint
    $loopStopReason    = $reason
    $terminalAction    = $action
    $terminalIteration = $iter

    Write-Host ("[autopilot] iter {0}: action={1} reason={2}" -f $iter, $action, $reason)

    if ($action -ne 'continue') { break }
}

$completedIterations = $terminalIteration

# Write a small summary of the whole loop for the handoff.
$loopSummaryJson = [ordered]@{
    enableFixLoop        = [bool]$EnableFixLoop
    fixTrigger           = $FixTrigger
    maxIterations        = $MaxIterations
    completedIterations  = $completedIterations
    terminalAction       = $terminalAction
    terminalReason       = $loopStopReason
    iterations           = $iterationDecisions
    maxChangedFiles      = $MaxChangedFiles
    maxDiffStatLines     = $MaxDiffStatLines
}
$loopSummaryPath = Join-Path $runFolder 'loop-summary.json'
($loopSummaryJson | ConvertTo-Json -Depth 8) | Out-File -FilePath $loopSummaryPath -Encoding utf8

# Step: write final handoff
& $handoffScript `
    -RunFolder $runFolder `
    -Goal $Goal `
    -TaskId $TaskId `
    -TestLevel $TestLevel `
    -SkipE2E:$SkipE2E `
    -DryRun:$DryRun `
    -Reviewer $Reviewer `
    -RunReviewer:$RunReviewer `
    -ClaudeReviewMode $ClaudeReviewMode `
    -Implementer $Implementer `
    -RunImplementer:$RunImplementer `
    -CodexCommand $CodexCommand `
    -CodexSandbox $CodexSandbox `
    -CodexRunMode $CodexRunMode `
    -EnableFixLoop:$EnableFixLoop `
    -FixTrigger $FixTrigger `
    -MaxIterations $MaxIterations `
    -CompletedIterations $completedIterations `
    -TerminalAction $terminalAction `
    -TerminalReason $loopStopReason `
    -MaxChangedFiles $MaxChangedFiles `
    -MaxDiffStatLines $MaxDiffStatLines

# Optional: copy handoff to clipboard
if ($CopyHandoffToClipboard) {
    $handoffPath = Join-Path $runFolder 'AI_FINAL_HANDOFF.md'
    if (Test-Path -LiteralPath $handoffPath) {
        try {
            Get-Content -LiteralPath $handoffPath -Raw | Set-Clipboard
            Write-Host '[autopilot] Handoff copied to clipboard.'
        } catch {
            Write-Host "[autopilot] Could not copy handoff to clipboard: $($_.Exception.Message)"
        }
    }
}

Write-Host ''
Write-Host '=================================================='
Write-Host '  NO commit, NO push, NO deploy was performed.'
Write-Host '  No dependencies installed.'
Write-Host ('  Iterations completed: {0}/{1} (terminal action: {2}, reason: {3})' -f $completedIterations, $MaxIterations, $terminalAction, $loopStopReason)
if ($EnableFixLoop) {
    Write-Host '  Fix loop was ENABLED. Loop bounded by MaxIterations and Phase 5 stop conditions.'
} else {
    Write-Host '  Fix loop was DISABLED (default). Single-iteration behavior preserved.'
}
Write-Host '  Human review required before any further action.'
Write-Host '=================================================='

# Exit code logic:
#   - exit 1 if the LAST iteration's tests failed AND there is no further action.
#   - exit 0 otherwise.
$lastIter = $null
if ($iterationDecisions.Count -gt 0) {
    $lastIter = $iterationDecisions[$iterationDecisions.Count - 1]
}
if (-not $DryRun -and $TestLevel -ne 'none' -and $null -ne $lastIter -and $lastIter.testsAnyFailed) {
    exit 1
}
exit 0
