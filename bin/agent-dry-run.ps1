<#
.SYNOPSIS
  30-second dry-run that proves an AI coding agent loaded all four rule files.

.DESCRIPTION
  Prints the four rule files and a self-check prompt. Does NOT invoke any AI.
  No network, no git, no install. Pure local read.

  Usage:
    pwsh -File bin/agent-dry-run.ps1
    pwsh -File bin/agent-dry-run.ps1 -Agent codex
#>

[CmdletBinding()]
param(
  [ValidateSet('claude', 'codex', 'cursor', 'gemini', 'any')]
  [string]$Agent = 'any'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$rulesDir = Join-Path $repoRoot '.claude/rules'

$rules = @(
  'start-here.md',
  'operating-mode.md',
  'editing-rules.md',
  'escape-hatch.md'
)

Write-Host ''
Write-Host '=== AI Service Template — Agent Dry-Run ===' -ForegroundColor Cyan
Write-Host "Agent target: $Agent" -ForegroundColor DarkGray
Write-Host "Rules directory: $rulesDir"
Write-Host ''

$missing = @()
foreach ($r in $rules) {
  $path = Join-Path $rulesDir $r
  if (Test-Path $path) {
    Write-Host "[OK] $r" -ForegroundColor Green
  } else {
    Write-Host "[MISSING] $r" -ForegroundColor Red
    $missing += $r
  }
}

if ($missing.Count -gt 0) {
  Write-Host ''
  Write-Host 'FAIL: rule files missing. Did `.claude/rules/` get copied during install?' -ForegroundColor Red
  exit 1
}

$entrypoint = switch ($Agent) {
  'claude' { 'CLAUDE.md' }
  'codex'  { 'AGENTS.md' }
  'cursor' { 'AGENTS.md' }
  'gemini' { 'AGENTS.md (no native Gemini entrypoint; AGENTS.md is the spec default)' }
  default  { 'CLAUDE.md (Claude Code) or AGENTS.md (Codex/Cursor)' }
}

Write-Host ''
Write-Host '=== Self-check prompt for your agent ===' -ForegroundColor Cyan
Write-Host 'Paste the following into your agent and confirm the reply quotes each rule:'
Write-Host ''
Write-Host @"
Read $entrypoint and every linked file under .claude/rules/.
Then answer in four lines, one per rule, quoting one verbatim sentence
from each file to prove you read it:

1. start-here:
2. operating-mode:
3. editing-rules:
4. escape-hatch:

If you cannot quote a file, say "MISSING" for that line.
"@ -ForegroundColor Yellow

Write-Host ''
Write-Host 'PASS criteria: agent returns four quoted sentences, no MISSING lines.' -ForegroundColor Green
Write-Host 'If the agent returns generic text or refuses, the agent did NOT load the rules.' -ForegroundColor DarkYellow
Write-Host ''
