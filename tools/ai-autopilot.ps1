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

Write-Host '=== ai-autopilot (Phase 1) ==='

# Hard refusal: AutoCommit is not allowed in Phase 1
if ($AutoCommit) {
    Write-Error 'AutoCommit is not permitted in Phase 1. Aborting before any action.'
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

# Create timestamped run folder
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot = Join-Path $repoRoot 'ai-runs'
if (-not (Test-Path -LiteralPath $runRoot)) {
    New-Item -ItemType Directory -Path $runRoot | Out-Null
}
$runFolder = Join-Path $runRoot $ts
New-Item -ItemType Directory -Path $runFolder | Out-Null

Write-Host "[autopilot] Repo root:  $repoRoot"
Write-Host "[autopilot] Run folder: $runFolder"

if ($DryRun) {
    Write-Host '[autopilot] DryRun is ON. Suppressed: Codex, Claude, tests, install, commit, push, deploy, destructive ops.'
    Write-Host '[autopilot] DryRun still writes safe local report files (goal.txt, git-*.txt, detected-tests.*, AI_FINAL_HANDOFF.md).'
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
& $collectScript -RunFolder $runFolder

# Step: detect tests
$detectScript = Join-Path $repoRoot 'tools/detect-tests.ps1'
if (-not (Test-Path -LiteralPath $detectScript)) {
    Write-Error "Missing tool: $detectScript"
    exit 2
}
& $detectScript -RunFolder $runFolder

# Phase 1 deferred notices
if ($Implementer -eq 'codex') {
    Write-Host '[autopilot] Implementer=codex requested. Phase 1 deferred: Codex CLI is NOT invoked in this phase.'
}
if ($Reviewer -eq 'claude') {
    Write-Host '[autopilot] Reviewer=claude requested. Phase 1 deferred: Claude Code CLI is NOT invoked in this phase.'
}
if ($TestLevel -ne 'none') {
    Write-Host "[autopilot] TestLevel=$TestLevel requested. Phase 1 deferred: no tests are executed in this phase."
}
if ($SkipE2E) {
    Write-Host '[autopilot] SkipE2E flag noted (Phase 1 does not run any tests regardless).'
}
if ($MaxIterations -gt 1) {
    Write-Host "[autopilot] MaxIterations=$MaxIterations noted. Phase 1 performs a single pass; iteration loops are deferred."
}

# Step: write final handoff
$handoffScript = Join-Path $repoRoot 'tools/write-final-handoff.ps1'
if (-not (Test-Path -LiteralPath $handoffScript)) {
    Write-Error "Missing tool: $handoffScript"
    exit 2
}
& $handoffScript -RunFolder $runFolder -Goal $Goal -TaskId $TaskId

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
Write-Host '  No dependencies installed. No tests executed.'
Write-Host '  Human review required before any further action.'
Write-Host '=================================================='
