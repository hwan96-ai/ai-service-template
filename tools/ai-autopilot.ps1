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
    [ValidateSet('none','codex')]
    [string]$Implementer = 'none',
    [switch]$CopyHandoffToClipboard
)

$ErrorActionPreference = 'Stop'

Write-Host '=== ai-autopilot (Phase 2) ==='

# Hard refusal: AutoCommit is not allowed (Phase 1 + Phase 2)
if ($AutoCommit) {
    Write-Error 'AutoCommit is not permitted (Phase 1 + Phase 2). Aborting before any action.'
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
# Use yyyyMMdd-HHmmss-fff and append -NNN if a folder already exists at that path.
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

if ($DryRun) {
    Write-Host '[autopilot] DryRun is ON. Suppressed: Codex, Claude, tests, install, commit, push, deploy, destructive ops.'
    Write-Host '[autopilot] DryRun still writes safe local report files (goal.txt, git-*.txt, detected-tests.*, test-*, AI_FINAL_HANDOFF.md).'
}

# Save run parameters
$paramLines = @(
    "Goal:           $Goal",
    "TaskId:         $TaskId",
    "Timestamp:      $ts",
    "MaxIterations:  $MaxIterations",
    "DryRun:         $([bool]$DryRun)",
    "AutoCommit:     $AutoCommit",
    "SkipE2E:        $([bool]$SkipE2E)",
    "TestLevel:      $TestLevel",
    "Reviewer:       $Reviewer",
    "Implementer:    $Implementer",
    "RepoRoot:       $repoRoot",
    "RunFolder:      $runFolder"
)
($paramLines -join [Environment]::NewLine) | Out-File -FilePath (Join-Path $runFolder 'goal.txt') -Encoding utf8

# Step: collect git context
$collectScript = Join-Path $repoRoot 'tools/collect-context.ps1'
if (-not (Test-Path -LiteralPath $collectScript)) {
    Write-Error "Missing tool: $collectScript"
    exit 2
}
$collectFailed = $false
try {
    & $collectScript -RunFolder $runFolder
} catch {
    # Defensive: keep the rest of the harness running so the handoff is still produced,
    # but surface the failure clearly on the console so it cannot be silently ignored.
    $collectFailed = $true
    Write-Host "[autopilot] WARNING: collect-context.ps1 threw: $($_.Exception.Message)"
}
# Verify that the three core context artifacts were written. If any are missing we
# loudly report it so the human reviewer cannot mistake a partial run for a clean one.
$expectedContext = @('git-status.txt','git-diff-stat.txt','git-diff-names.txt')
$missingContext = @()
foreach ($cf in $expectedContext) {
    if (-not (Test-Path -LiteralPath (Join-Path $runFolder $cf))) {
        $missingContext += $cf
    }
}
if ($missingContext.Count -gt 0) {
    $collectFailed = $true
    Write-Host ("[autopilot] WARNING: context collection did not produce: {0}" -f ($missingContext -join ', '))
}
if ($collectFailed) {
    Write-Host '[autopilot] WARNING: context collection failed or was incomplete. The handoff will still be written, but review git-*.txt artifacts manually.'
}

# Step: detect tests
$detectScript = Join-Path $repoRoot 'tools/detect-tests.ps1'
if (-not (Test-Path -LiteralPath $detectScript)) {
    Write-Error "Missing tool: $detectScript"
    exit 2
}
try {
    & $detectScript -RunFolder $runFolder
} catch {
    Write-Host "[autopilot] detect-tests.ps1 raised a non-fatal error: $($_.Exception.Message). Continuing."
}

# Phase 2 deferred notices for AI integrations
if ($Implementer -eq 'codex') {
    Write-Host '[autopilot] Implementer=codex requested. Phase 2 deferred: Codex CLI is NOT invoked.'
}
if ($Reviewer -eq 'claude') {
    Write-Host '[autopilot] Reviewer=claude requested. Phase 2 deferred: Claude Code CLI is NOT invoked.'
}
if ($MaxIterations -gt 1) {
    Write-Host "[autopilot] MaxIterations=$MaxIterations noted. Phase 2 still performs a single pass; iteration loops are deferred."
}

# -------- Phase 2: optional safe test execution --------
$testSummaryPath = Join-Path $runFolder 'test-summary.json'
$testOutputPath  = Join-Path $runFolder 'test-output.txt'

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

# Build a default empty summary that we will overwrite as needed.
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
    # Load detection JSON
    $detectedJsonPath = Join-Path $runFolder 'detected-tests.json'
    $detected = $null
    if (Test-Path -LiteralPath $detectedJsonPath) {
        try {
            $detected = (Get-Content -LiteralPath $detectedJsonPath -Raw) | ConvertFrom-Json
        } catch {
            Write-Host ("[autopilot] Could not parse detected-tests.json: {0}" -f $_.Exception.Message)
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
        # Initialize output file
        $header = "Phase 2 test execution log`r`nTestLevel: $TestLevel`r`nSkipE2E: $([bool]$SkipE2E)`r`nSelected commands: $selectedCount`r`n"
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
                # Use cmd.exe /c to run the literal detected command line; capture stdout+stderr
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

# Step: write final handoff
$handoffScript = Join-Path $repoRoot 'tools/write-final-handoff.ps1'
if (-not (Test-Path -LiteralPath $handoffScript)) {
    Write-Error "Missing tool: $handoffScript"
    exit 2
}
& $handoffScript -RunFolder $runFolder -Goal $Goal -TaskId $TaskId -TestLevel $TestLevel -SkipE2E:$SkipE2E -DryRun:$DryRun

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
Write-Host '  No dependencies installed. No Codex/Claude invoked.'
Write-Host '  Human review required before any further action.'
Write-Host '=================================================='

# After writing the handoff, surface a non-zero exit code if tests were selected and any failed.
if (-not $DryRun -and $TestLevel -ne 'none' -and -not $noCommandsSelected -and $anyFailed) {
    exit 1
}
exit 0
