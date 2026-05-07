[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunFolder,
    [string]$Goal = '',
    [string]$TaskId = ''
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
$lines += '## Risks'
$lines += ''
$lines += '- Phase 1 harness only: no Codex implementation, no Claude review, no test execution has occurred.'
$lines += '- Any uncommitted changes shown above are unverified local edits.'
$lines += '- Detected test config files indicate which runners may apply later, but they have not been validated.'
$lines += ''
$lines += '## Next Steps'
$lines += ''
$lines += '1. Human reviews the changes and the detected-tests summary.'
$lines += '2. Human decides whether to commit. The harness will not commit.'
$lines += '3. When ready, advance to Phase 2 to enable Codex implementation, then Phase 3 for Claude review, then Phase 4 for test execution.'
$lines += ''
$lines += '---'
$lines += ''
$lines += '**NO commit, NO push, NO deploy was performed in this run. Human review required.**'

$outPath = Join-Path $RunFolder 'AI_FINAL_HANDOFF.md'
($lines -join [Environment]::NewLine) | Out-File -FilePath $outPath -Encoding utf8

Write-Host "[handoff] Wrote $outPath"
