[CmdletBinding()]
param(
    [string]$TargetRepo = '.',
    [switch]$RunSmoke
)

$ErrorActionPreference = 'Stop'

Write-Host '=== validate-template-install (Phase 6) ==='

# Phase 6: this script never modifies the target repo, never runs git add/commit/push,
# never installs dependencies, never invokes Codex, never invokes Claude.

# ----- resolve target -----

if ([string]::IsNullOrWhiteSpace($TargetRepo)) { $TargetRepo = '.' }
if (-not (Test-Path -LiteralPath $TargetRepo)) {
    Write-Error ("TargetRepo does not exist: {0}. Aborting." -f $TargetRepo)
    exit 1
}
$resolvedTarget = (Resolve-Path -LiteralPath $TargetRepo).ProviderPath
Write-Host ("[validate] Target repo: {0}" -f $resolvedTarget)
Write-Host ("[validate] RunSmoke:    {0}" -f [bool]$RunSmoke)

# ----- result tracking -----

$results = New-Object System.Collections.ArrayList
function Add-Result {
    param([string]$Name, [string]$Status, [string]$Detail = '')
    [void]$results.Add([pscustomobject]@{ Name = $Name; Status = $Status; Detail = $Detail })
}

# ----- locate manifest. We look in the target repo. -----

$targetManifestPath = Join-Path $resolvedTarget 'TEMPLATE_MANIFEST.json'
$manifest = $null
if (Test-Path -LiteralPath $targetManifestPath) {
    try {
        $manifest = Get-Content -LiteralPath $targetManifestPath -Raw | ConvertFrom-Json
        Add-Result -Name 'TEMPLATE_MANIFEST.json present and parses' -Status 'pass'
    } catch {
        Add-Result -Name 'TEMPLATE_MANIFEST.json parses' -Status 'fail' -Detail ("JSON parse error: {0}" -f $_.Exception.Message)
    }
} else {
    Add-Result -Name 'TEMPLATE_MANIFEST.json present' -Status 'fail' -Detail 'TEMPLATE_MANIFEST.json missing in target repo. Did the copy step run?'
}

# Fallback file lists if manifest is not parseable.
$fallbackRequired = @(
    'AI_PRODUCT_SPEC.md',
    'AI_ACCEPTANCE_CRITERIA.md',
    'AI_TASK_QUEUE.md',
    'AI_WORKFLOW.md',
    'AGENTS.md',
    'CLAUDE.md',
    'README.md',
    'TEMPLATE_USAGE.md',
    'TEMPLATE_CHANGELOG.md',
    'SERVICE_ONBOARDING_CHECKLIST.md',
    'TEMPLATE_MANIFEST.json'
)
$fallbackTools = @(
    'tools/ai-autopilot.ps1',
    'tools/collect-context.ps1',
    'tools/detect-tests.ps1',
    'tools/write-claude-review-prompt.ps1',
    'tools/write-codex-implementation-prompt.ps1',
    'tools/write-codex-fix-prompt.ps1',
    'tools/write-final-handoff.ps1',
    'tools/copy-template-to-service.ps1',
    'tools/validate-template-install.ps1'
)
$fallbackSentinel = @('ai-runs/.gitkeep')

$requiredFiles = if ($manifest -and $manifest.requiredFiles) { @($manifest.requiredFiles | ForEach-Object { [string]$_ }) } else { $fallbackRequired }
$toolFiles     = if ($manifest -and $manifest.toolFiles)     { @($manifest.toolFiles     | ForEach-Object { [string]$_ }) } else { $fallbackTools }
$sentinelFiles = if ($manifest -and $manifest.sentinelFiles) { @($manifest.sentinelFiles | ForEach-Object { [string]$_ }) } else { $fallbackSentinel }

# ----- check required files -----

$anyRequiredMissing = $false
foreach ($rel in $requiredFiles) {
    $relNative = $rel -replace '/','\'
    $p = Join-Path $resolvedTarget $relNative
    if (Test-Path -LiteralPath $p) {
        Add-Result -Name ("required file: {0}" -f $rel) -Status 'pass'
    } else {
        Add-Result -Name ("required file: {0}" -f $rel) -Status 'fail' -Detail 'missing'
        $anyRequiredMissing = $true
    }
}

# ----- check tool files -----

foreach ($rel in $toolFiles) {
    $relNative = $rel -replace '/','\'
    $p = Join-Path $resolvedTarget $relNative
    if (Test-Path -LiteralPath $p) {
        Add-Result -Name ("tool file: {0}" -f $rel) -Status 'pass'
    } else {
        Add-Result -Name ("tool file: {0}" -f $rel) -Status 'fail' -Detail 'missing'
        $anyRequiredMissing = $true
    }
}

# ----- check sentinel files (ai-runs/.gitkeep) -----

foreach ($rel in $sentinelFiles) {
    $relNative = $rel -replace '/','\'
    $p = Join-Path $resolvedTarget $relNative
    if (Test-Path -LiteralPath $p) {
        Add-Result -Name ("sentinel: {0}" -f $rel) -Status 'pass'
    } else {
        Add-Result -Name ("sentinel: {0}" -f $rel) -Status 'fail' -Detail 'missing'
        $anyRequiredMissing = $true
    }
}

# ----- check .gitignore rules (warn-only) -----

$gitignorePath = Join-Path $resolvedTarget '.gitignore'
if (Test-Path -LiteralPath $gitignorePath) {
    $gi = Get-Content -LiteralPath $gitignorePath -Raw
    $hasAiRuns = $gi -match 'ai-runs/\*'
    $hasClaude = $gi -match '\.claude/'
    if ($hasAiRuns -and $hasClaude) {
        Add-Result -Name '.gitignore contains ai-runs/* and .claude/ rules' -Status 'pass'
    } else {
        $miss = @()
        if (-not $hasAiRuns) { $miss += 'ai-runs/*' }
        if (-not $hasClaude) { $miss += '.claude/' }
        Add-Result -Name '.gitignore local rules' -Status 'warn' -Detail ("missing rule(s): {0}. Re-run copy script with -IncludeLocalGitignoreRules -Apply, or add by hand." -f ($miss -join ', '))
    }
} else {
    Add-Result -Name '.gitignore present' -Status 'warn' -Detail 'no .gitignore in target. Re-run copy script with -IncludeLocalGitignoreRules -Apply, or add ai-runs/* and .claude/ rules.'
}

# ----- git repo state -----

$targetGitDir = Join-Path $resolvedTarget '.git'
if (Test-Path -LiteralPath $targetGitDir) {
    Add-Result -Name 'target is a git repository (.git present)' -Status 'pass'
} else {
    Add-Result -Name 'target is a git repository (.git present)' -Status 'fail' -Detail 'no .git directory found. ai-autopilot.ps1 will refuse to run.'
    $anyRequiredMissing = $true
}

# ----- PowerShell parser tokenisation of key scripts -----

function Test-ScriptParses {
    param([string]$RelPath)
    $relNative = $RelPath -replace '/','\'
    $p = Join-Path $resolvedTarget $relNative
    if (-not (Test-Path -LiteralPath $p)) {
        return @{ Status = 'fail'; Detail = 'script missing' }
    }
    try {
        $raw = Get-Content -LiteralPath $p -Raw
        [void][System.Management.Automation.PSParser]::Tokenize($raw, [ref]$null)
        return @{ Status = 'pass'; Detail = '' }
    } catch {
        return @{ Status = 'fail'; Detail = ("parse error: {0}" -f $_.Exception.Message) }
    }
}

$scriptsToParse = @(
    'tools/ai-autopilot.ps1',
    'tools/copy-template-to-service.ps1',
    'tools/validate-template-install.ps1',
    'tools/write-final-handoff.ps1',
    'tools/collect-context.ps1',
    'tools/detect-tests.ps1'
)
foreach ($s in $scriptsToParse) {
    $r = Test-ScriptParses -RelPath $s
    if ($r.Status -eq 'pass') {
        Add-Result -Name ("script parses: {0}" -f $s) -Status 'pass'
    } else {
        Add-Result -Name ("script parses: {0}" -f $s) -Status $r.Status -Detail $r.Detail
        if ($r.Status -eq 'fail') { $anyRequiredMissing = $true }
    }
}

# ----- optional smoke run -----

$smokeFailed = $false
if ($RunSmoke) {
    Write-Host ''
    Write-Host '[validate] Running -RunSmoke: ai-autopilot.ps1 -DryRun -Goal "template install smoke test"'
    Write-Host '[validate] (no Codex, no Claude, no tests, no commit, no push, no install)'

    $autopilot = Join-Path $resolvedTarget 'tools\ai-autopilot.ps1'
    if (-not (Test-Path -LiteralPath $autopilot)) {
        Add-Result -Name 'smoke run' -Status 'fail' -Detail 'tools/ai-autopilot.ps1 missing in target.'
        $smokeFailed = $true
    } else {
        # Snapshot existing run folders so we can identify the new one created
        # by the smoke run (rather than picking up an older folder if the
        # autopilot fails before producing artifacts).
        $runRoot = Join-Path $resolvedTarget 'ai-runs'
        $preExistingRuns = @()
        if (Test-Path -LiteralPath $runRoot) {
            $preExistingRuns = @(
                Get-ChildItem -LiteralPath $runRoot -Directory -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Name
            )
        }
        $smokeStart = Get-Date

        # Invoke the smoke run in-process via the call operator so that arguments
        # containing spaces (e.g. -Goal "template install smoke test") are passed
        # verbatim. Start-Process -ArgumentList does not quote per-element values
        # and would mis-bind positional parameters (observed: 'smoke' bound to -MaxIterations).
        $prevLocation = Get-Location
        $prevLastExit = $global:LASTEXITCODE
        $global:LASTEXITCODE = 0
        $exit = $null
        try {
            Set-Location -LiteralPath $resolvedTarget
            try {
                & $autopilot -DryRun -Goal 'template install smoke test' | Out-Null
                $exit = $global:LASTEXITCODE
            } catch {
                Add-Result -Name 'smoke run: ai-autopilot.ps1 -DryRun' -Status 'fail' -Detail ("threw: {0}" -f $_.Exception.Message)
                $smokeFailed = $true
                $exit = $null
            }
            if ($null -ne $exit) {
                if ($exit -eq 0) {
                    Add-Result -Name 'smoke run: ai-autopilot.ps1 -DryRun' -Status 'pass' -Detail 'exit 0'
                } else {
                    Add-Result -Name 'smoke run: ai-autopilot.ps1 -DryRun' -Status 'fail' -Detail ("exit code {0}" -f $exit)
                    $smokeFailed = $true
                }
            }
        } finally {
            Set-Location -LiteralPath $prevLocation
            $global:LASTEXITCODE = $prevLastExit
        }

        # ----- smoke artifact verification -----
        # Even if the autopilot exited 0, require that it produced a fresh
        # ai-runs/<timestamp>/ folder containing the documented Phase 1+2+3
        # artifacts. This catches regressions where collect-context.ps1 silently
        # fails to write its outputs (the bug this validator hardening targets).
        $smokeRunFolder = $null
        if (Test-Path -LiteralPath $runRoot) {
            $candidates = @(
                Get-ChildItem -LiteralPath $runRoot -Directory -ErrorAction SilentlyContinue |
                    Where-Object {
                        $preExistingRuns -notcontains $_.Name -and $_.LastWriteTime -ge $smokeStart
                    } |
                    Sort-Object -Property LastWriteTime -Descending
            )
            if ($candidates.Count -gt 0) {
                $smokeRunFolder = $candidates[0].FullName
            }
        }

        if ($null -eq $smokeRunFolder) {
            Add-Result -Name 'smoke run: created ai-runs/<timestamp>/' -Status 'fail' -Detail 'no new ai-runs subfolder was produced by the smoke run.'
            $smokeFailed = $true
        } else {
            $relSmoke = $smokeRunFolder.Substring($resolvedTarget.Length).TrimStart('\','/')
            Add-Result -Name 'smoke run: created ai-runs/<timestamp>/' -Status 'pass' -Detail $relSmoke

            $expectedArtifacts = @(
                'git-status.txt',
                'git-diff-stat.txt',
                'git-diff-names.txt',
                'detected-tests.md',
                'detected-tests.json',
                'AI_FINAL_HANDOFF.md'
            )
            foreach ($artifact in $expectedArtifacts) {
                $artifactPath = Join-Path $smokeRunFolder $artifact
                if (Test-Path -LiteralPath $artifactPath) {
                    # Empty content is acceptable (e.g. no changes in the target repo);
                    # missing files are not. Per the bug report: collect-context.ps1
                    # threw before writing git-diff-stat.txt and git-diff-names.txt.
                    Add-Result -Name ("smoke artifact: {0}" -f $artifact) -Status 'pass'
                } else {
                    Add-Result -Name ("smoke artifact: {0}" -f $artifact) -Status 'fail' -Detail 'missing in latest ai-runs/<timestamp>/'
                    $smokeFailed = $true
                }
            }
        }
    }
} else {
    Add-Result -Name 'smoke run' -Status 'skipped' -Detail '-RunSmoke not requested'
}

# ----- print summary -----

Write-Host ''
Write-Host '[validate] --- Summary ---'
$passCount = 0
$warnCount = 0
$failCount = 0
$skipCount = 0
foreach ($r in $results) {
    $tag = switch ($r.Status) {
        'pass'    { 'PASS' }
        'warn'    { 'WARN' }
        'fail'    { 'FAIL' }
        'skipped' { 'SKIP' }
        default   { $r.Status.ToUpperInvariant() }
    }
    $line = ("  [{0}] {1}" -f $tag, $r.Name)
    if (-not [string]::IsNullOrWhiteSpace($r.Detail)) {
        $line = $line + ("  -- {0}" -f $r.Detail)
    }
    Write-Host $line
    switch ($r.Status) {
        'pass'    { $passCount++ }
        'warn'    { $warnCount++ }
        'fail'    { $failCount++ }
        'skipped' { $skipCount++ }
    }
}
Write-Host ''
Write-Host ("[validate] Totals: pass={0} warn={1} fail={2} skip={3}" -f $passCount, $warnCount, $failCount, $skipCount)
Write-Host '[validate] No git add, no git commit, no git push, no deploy, no dependency install was performed.'

if ($anyRequiredMissing -or $smokeFailed) {
    Write-Host '[validate] Result: FAIL (required files missing or smoke test failed).'
    exit 1
} else {
    Write-Host '[validate] Result: OK.'
    exit 0
}
