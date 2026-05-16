<#
.SYNOPSIS
  Entrypoint mapper. Outputs the correct rules file path for a given agent.

.DESCRIPTION
  Usage:
    pwsh -File bin/agent-bootstrap.ps1 claude
    pwsh -File bin/agent-bootstrap.ps1 codex
    pwsh -File bin/agent-bootstrap.ps1 cursor
    pwsh -File bin/agent-bootstrap.ps1 gemini
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Agent
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

$map = @{
  'claude'      = 'CLAUDE.md'
  'claude-code' = 'CLAUDE.md'
  'codex'       = 'AGENTS.md'
  'codex-cli'   = 'AGENTS.md'
  'cursor'      = 'AGENTS.md'
  'gemini'      = $null
  'gemini-cli'  = $null
}

$key = $Agent.ToLowerInvariant()

if (-not $map.ContainsKey($key)) {
  Write-Host "Unknown agent: $Agent" -ForegroundColor Red
  Write-Host 'Supported: claude, codex, cursor, gemini' -ForegroundColor DarkGray
  exit 2
}

$entry = $map[$key]

if ($null -eq $entry) {
  Write-Host "Agent '$Agent' has no native entrypoint convention in this template." -ForegroundColor Yellow
  Write-Host 'Recommendation: point it at AGENTS.md (agents.md spec is the closest open standard).'
  Write-Host ''
  Write-Host "Entrypoint: $repoRoot/AGENTS.md"
  Write-Host 'Rules:'
  Get-ChildItem (Join-Path $repoRoot '.claude/rules') -Filter '*.md' | ForEach-Object {
    Write-Host "  - $($_.FullName)"
  }
  exit 0
}

$entryPath = Join-Path $repoRoot $entry
if (-not (Test-Path $entryPath)) {
  Write-Host "Entrypoint file not found: $entryPath" -ForegroundColor Red
  exit 1
}

Write-Host "Entrypoint: $entryPath"
Write-Host 'Linked rules (READ ALL before any action):'
Get-ChildItem (Join-Path $repoRoot '.claude/rules') -Filter '*.md' | ForEach-Object {
  Write-Host "  - $($_.FullName)"
}
