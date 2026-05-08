[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TargetRepo,
    [switch]$Apply,
    [switch]$OverwriteControlDocs,
    [switch]$IncludeLocalGitignoreRules
)

$ErrorActionPreference = 'Stop'

Write-Host '=== copy-template-to-service (Phase 6) ==='

# Phase 6: this script never invokes git, never installs dependencies,
# never deletes files. Without -Apply it is preview-only.

# ----- locate the template root (this script's parent) -----

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir '..')).ProviderPath
Write-Host ("[copy] Template source: {0}" -f $templateRoot)

# ----- validate target repo -----

if ([string]::IsNullOrWhiteSpace($TargetRepo)) {
    Write-Error 'TargetRepo is required.'
    exit 2
}

if (-not (Test-Path -LiteralPath $TargetRepo)) {
    Write-Error ("TargetRepo does not exist: {0}. Aborting before any action." -f $TargetRepo)
    exit 2
}

try {
    $resolvedTarget = (Resolve-Path -LiteralPath $TargetRepo).ProviderPath
} catch {
    Write-Error ("Failed to resolve TargetRepo path '{0}': {1}" -f $TargetRepo, $_.Exception.Message)
    exit 2
}

# Refuse to copy onto self.
$templateNorm = $templateRoot.TrimEnd('\','/')
$targetNorm = $resolvedTarget.TrimEnd('\','/')
if ([string]::Equals($templateNorm, $targetNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error 'TargetRepo is the same as the template source. Refusing to copy onto self.'
    exit 2
}

# Verify target is a git repo (presence of .git). We do not run git here.
$targetGit = Join-Path $resolvedTarget '.git'
if (-not (Test-Path -LiteralPath $targetGit)) {
    Write-Error ("TargetRepo is not a git repository (no .git found): {0}. Aborting." -f $resolvedTarget)
    exit 2
}

Write-Host ("[copy] Target repo:     {0}" -f $resolvedTarget)
Write-Host ("[copy] Mode:            {0}" -f $(if ($Apply) { 'APPLY (will write files)' } else { 'PREVIEW (no files written)' }))
Write-Host ("[copy] OverwriteControlDocs: {0}" -f [bool]$OverwriteControlDocs)
Write-Host ("[copy] IncludeLocalGitignoreRules: {0}" -f [bool]$IncludeLocalGitignoreRules)

# ----- load manifest -----

$manifestPath = Join-Path $templateRoot 'TEMPLATE_MANIFEST.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Error ("TEMPLATE_MANIFEST.json not found at {0}. Aborting." -f $manifestPath)
    exit 2
}

try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} catch {
    Write-Error ("Failed to parse TEMPLATE_MANIFEST.json: {0}" -f $_.Exception.Message)
    exit 2
}

if (-not $manifest.requiredFiles -or -not $manifest.toolFiles) {
    Write-Error 'TEMPLATE_MANIFEST.json is missing requiredFiles or toolFiles.'
    exit 2
}

$controlDocs = @()
if ($manifest.controlDocuments) {
    foreach ($d in $manifest.controlDocuments) {
        $controlDocs += [string]$d
    }
}

# Build the file copy list: requiredFiles + toolFiles + sentinelFiles.
# We keep paths as relative-from-template-root, with forward slashes in the manifest
# converted to the platform separator for filesystem operations.
$relativeFiles = @()
foreach ($f in $manifest.requiredFiles) { $relativeFiles += [string]$f }
foreach ($f in $manifest.toolFiles)     { $relativeFiles += [string]$f }
if ($manifest.sentinelFiles) {
    foreach ($f in $manifest.sentinelFiles) { $relativeFiles += [string]$f }
}

# Deduplicate (case-insensitive) while preserving order.
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$dedup = @()
foreach ($r in $relativeFiles) {
    if ($seen.Add($r)) { $dedup += $r }
}
$relativeFiles = $dedup

# ----- safety: forbidden source paths -----
# These must never appear in the manifest, but double-check defensively.
function Test-ForbiddenSourcePath {
    param([string]$RelPath)
    $norm = $RelPath -replace '\\','/'
    if ($norm -eq '.git' -or $norm.StartsWith('.git/')) { return $true }
    if ($norm -eq '.claude' -or $norm.StartsWith('.claude/')) { return $true }
    # Reject ai-runs timestamp folders (anything under ai-runs/ except the exact .gitkeep sentinel).
    if ($norm.StartsWith('ai-runs/')) {
        if ($norm -ne 'ai-runs/.gitkeep') { return $true }
    }
    return $false
}

# ----- build a plan -----

$plan = @()  # list of pscustomobject { Source, Target, Relative, Action, IsControlDoc }

foreach ($rel in $relativeFiles) {
    if (Test-ForbiddenSourcePath -RelPath $rel) {
        Write-Host ("[copy] SKIP (forbidden by safety policy): {0}" -f $rel)
        continue
    }

    $relNative = $rel -replace '/','\'
    $sourcePath = Join-Path $templateRoot $relNative
    $targetPath = Join-Path $resolvedTarget $relNative

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        Write-Host ("[copy] WARN: manifest lists '{0}' but it is missing from the template source." -f $rel)
        continue
    }

    $isControlDoc = ($controlDocs -contains $rel)
    $targetExists = Test-Path -LiteralPath $targetPath

    $action = 'create'
    if ($targetExists) {
        if ($isControlDoc -and -not $OverwriteControlDocs) {
            $action = 'skip-existing-control-doc'
        } else {
            $action = 'overwrite'
        }
    }

    $plan += [pscustomobject]@{
        Source       = $sourcePath
        Target       = $targetPath
        Relative     = $rel
        Action       = $action
        IsControlDoc = $isControlDoc
    }
}

# ----- print the plan -----

Write-Host ''
Write-Host '[copy] --- File plan ---'
$createCount = 0
$overwriteCount = 0
$skipCount = 0
foreach ($entry in $plan) {
    Write-Host ("  [{0}] {1}" -f $entry.Action, $entry.Relative)
    switch ($entry.Action) {
        'create'                      { $createCount++ }
        'overwrite'                   { $overwriteCount++ }
        'skip-existing-control-doc'   { $skipCount++ }
    }
}
Write-Host ''
Write-Host ("[copy] Plan totals: create={0} overwrite={1} skip-existing-control-doc={2}" -f $createCount, $overwriteCount, $skipCount)

if ($skipCount -gt 0 -and -not $OverwriteControlDocs) {
    Write-Host '[copy] NOTE: existing control documents are preserved. Pass -OverwriteControlDocs to replace them (only if you really mean to).'
}

# ----- gitignore rules preview/apply -----

$gitignoreLines = @()
if ($manifest.gitignoreRulesToAppend) {
    foreach ($l in $manifest.gitignoreRulesToAppend) {
        $gitignoreLines += [string]$l
    }
}
$targetGitignore = Join-Path $resolvedTarget '.gitignore'
$gitignoreAction = 'none'
$gitignoreAlreadyHasRules = $false
if ($IncludeLocalGitignoreRules) {
    if ($gitignoreLines.Count -eq 0) {
        Write-Host '[copy] NOTE: -IncludeLocalGitignoreRules was set but the manifest has no gitignoreRulesToAppend.'
        $gitignoreAction = 'no-rules-in-manifest'
    } else {
        if (Test-Path -LiteralPath $targetGitignore) {
            $existingGitignore = Get-Content -LiteralPath $targetGitignore -Raw
            if ($existingGitignore -match 'ai-runs/\*' -and $existingGitignore -match '\.claude/') {
                $gitignoreAlreadyHasRules = $true
                $gitignoreAction = 'gitignore-already-has-rules'
                Write-Host '[copy] .gitignore already contains ai-runs/* and .claude/ rules. Will not append duplicates.'
            } else {
                $gitignoreAction = 'append-to-existing-gitignore'
                Write-Host '[copy] Plan: append local-only rules to existing .gitignore.'
            }
        } else {
            $gitignoreAction = 'create-new-gitignore'
            Write-Host '[copy] Plan: create new .gitignore with local-only rules.'
        }
    }
}

# ----- preview-only: stop here -----

if (-not $Apply) {
    Write-Host ''
    Write-Host '[copy] PREVIEW MODE — no files were written.'
    Write-Host '[copy] Re-run with -Apply once the plan above looks correct.'
    Write-Host '[copy] DONE.'
    exit 0
}

# ----- apply -----

Write-Host ''
Write-Host '[copy] APPLY MODE — writing files...'

# Ensure tools/ exists at target.
$targetTools = Join-Path $resolvedTarget 'tools'
if (-not (Test-Path -LiteralPath $targetTools)) {
    Write-Host '[copy] Creating tools/ directory at target.'
    New-Item -ItemType Directory -Path $targetTools | Out-Null
}

# Ensure ai-runs/ + .gitkeep exists at target.
$targetAiRuns = Join-Path $resolvedTarget 'ai-runs'
if (-not (Test-Path -LiteralPath $targetAiRuns)) {
    Write-Host '[copy] Creating ai-runs/ directory at target.'
    New-Item -ItemType Directory -Path $targetAiRuns | Out-Null
}
$targetAiKeep = Join-Path $targetAiRuns '.gitkeep'
if (-not (Test-Path -LiteralPath $targetAiKeep)) {
    Write-Host '[copy] Creating ai-runs/.gitkeep sentinel.'
    New-Item -ItemType File -Path $targetAiKeep | Out-Null
}

# Walk the plan and copy.
$writeCount = 0
$skipApplyCount = 0
foreach ($entry in $plan) {
    if ($entry.Action -eq 'skip-existing-control-doc') {
        Write-Host ("[copy] preserved (control doc, no overwrite): {0}" -f $entry.Relative)
        $skipApplyCount++
        continue
    }

    # Ensure parent directory exists.
    $parentDir = Split-Path -Parent $entry.Target
    if (-not [string]::IsNullOrWhiteSpace($parentDir) -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir | Out-Null
    }

    Copy-Item -LiteralPath $entry.Source -Destination $entry.Target -Force
    Write-Host ("[copy] wrote: {0}" -f $entry.Relative)
    $writeCount++
}

# Apply gitignore rules if requested.
if ($IncludeLocalGitignoreRules -and $gitignoreLines.Count -gt 0 -and -not $gitignoreAlreadyHasRules) {
    if (Test-Path -LiteralPath $targetGitignore) {
        # Append a leading blank line if the existing file does not end with newline-blank-line.
        $existing = Get-Content -LiteralPath $targetGitignore -Raw
        if (-not $existing.EndsWith("`n")) {
            Add-Content -LiteralPath $targetGitignore -Value ''
        }
        Add-Content -LiteralPath $targetGitignore -Value ''
        foreach ($line in $gitignoreLines) {
            Add-Content -LiteralPath $targetGitignore -Value $line
        }
        Write-Host '[copy] Appended local-only ignore rules to existing .gitignore.'
    } else {
        ($gitignoreLines -join [Environment]::NewLine) | Out-File -FilePath $targetGitignore -Encoding utf8
        Write-Host '[copy] Created .gitignore with local-only ignore rules.'
    }
}

Write-Host ''
Write-Host ("[copy] APPLY summary: wrote={0} preserved-existing-control-docs={1}" -f $writeCount, $skipApplyCount)
Write-Host '[copy] No git add, no git commit, no git push, no deploy, no dependency install was performed.'
Write-Host '[copy] Next: run tools/validate-template-install.ps1 -TargetRepo <target> -RunSmoke from inside the target repo.'
Write-Host '[copy] DONE.'
exit 0
