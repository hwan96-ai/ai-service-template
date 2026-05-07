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
    throw "write-claude-review-prompt: run folder does not exist: $RunFolder"
}

function Read-Artifact {
    param([string]$Path, [int]$MaxLines = 0)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { return $null }
    if ($MaxLines -gt 0) {
        $lines = $content -split "`r?`n"
        if ($lines.Count -gt $MaxLines) {
            $lines = $lines[0..($MaxLines - 1)]
            $content = ($lines -join [Environment]::NewLine) + [Environment]::NewLine + '... (truncated)'
        }
    }
    return $content.TrimEnd()
}

function Block-OrPlaceholder {
    param([string]$Content, [string]$Placeholder = '(not generated)')
    if ([string]::IsNullOrWhiteSpace($Content)) { return $Placeholder }
    return $Content
}

$goalText = if ([string]::IsNullOrWhiteSpace($Goal))   { '(not provided)' } else { $Goal }
$taskText = if ([string]::IsNullOrWhiteSpace($TaskId)) { '(not provided)' } else { $TaskId }

# Read run-folder summary artifacts only. Do NOT read raw file diffs, source files,
# or anything matching secret-like paths. The harness has already filtered git
# context for secret-like names; we only consume those filtered summaries here.
$gitStatus    = Read-Artifact -Path (Join-Path $RunFolder 'git-status.txt')
$diffStat     = Read-Artifact -Path (Join-Path $RunFolder 'git-diff-stat.txt')
$diffNames    = Read-Artifact -Path (Join-Path $RunFolder 'git-diff-names.txt')
$detectedMd   = Read-Artifact -Path (Join-Path $RunFolder 'detected-tests.md')
$testSummary  = Read-Artifact -Path (Join-Path $RunFolder 'test-summary.json')
$testOutTail  = Read-Artifact -Path (Join-Path $RunFolder 'test-output.txt') -MaxLines 80
$handoffMd    = Read-Artifact -Path (Join-Path $RunFolder 'AI_FINAL_HANDOFF.md')

$bt    = [char]96
$fence = '' + $bt + $bt + $bt

$lines = @()
$lines += '# Claude Code Review Prompt (Phase 3)'
$lines += ''
$lines += '## Reviewer-Only Directive'
$lines += ''
$lines += '**Do not edit files. Do not run commands. Review only.**'
$lines += ''
$lines += 'You are acting as an independent code reviewer for a local PowerShell harness run. Read the artifacts below and produce a structured markdown review using the response template at the end of this prompt. Do not modify the repository. Do not invoke shell tools, git commands, or file edits during this review.'
$lines += ''
$lines += '## Run Parameters'
$lines += ''
$lines += ('- Goal: ' + $goalText)
$lines += ('- TaskId: ' + $taskText)
$lines += ('- TestLevel: ' + $TestLevel)
$lines += ('- SkipE2E: ' + [bool]$SkipE2E)
$lines += ('- DryRun: ' + [bool]$DryRun)
$lines += ('- RunFolder: ' + $RunFolder)
$lines += ''
$lines += '## What To Review'
$lines += ''
$lines += '1. Does the work match the relevant entries in `AI_ACCEPTANCE_CRITERIA.md`?'
$lines += '2. Are all changed files within the **allowed scope** for the current phase (see `AGENTS.md` / `CLAUDE.md`)?'
$lines += '3. Were tests detected? Were tests executed? At what TestLevel?'
$lines += '4. Did any selected test commands fail or get rejected by the safety denylist?'
$lines += '5. Is the git diff size reasonable for the stated goal, or does it look too large / unfocused?'
$lines += '6. Do any secret-like paths appear in the file list (`.env`, `*.pem`, `*.key`, `*secret*`)?'
$lines += '7. Are any safety rules violated (auto-commit, push, deploy, dependency install, destructive ops, files outside the allowed list)?'
$lines += '8. Is the result ready for human approval, or are blocking issues outstanding?'
$lines += ''
$lines += '## Git Status'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $gitStatus)
$lines += $fence
$lines += ''
$lines += '## Diff Stat'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $diffStat)
$lines += $fence
$lines += ''
$lines += '## Files Changed'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $diffNames)
$lines += $fence
$lines += ''
$lines += '## Detected Tests (summary)'
$lines += ''
$lines += (Block-OrPlaceholder $detectedMd)
$lines += ''
$lines += '## Test Summary (JSON)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $testSummary)
$lines += $fence
$lines += ''
$lines += '## Test Output (head)'
$lines += ''
$lines += $fence
$lines += (Block-OrPlaceholder $testOutTail '(no test output captured)')
$lines += $fence
$lines += ''
if (-not [string]::IsNullOrWhiteSpace($handoffMd)) {
    $lines += '## Final Handoff (if available)'
    $lines += ''
    $lines += $handoffMd
    $lines += ''
}
$lines += '## Out-of-Scope Material'
$lines += ''
$lines += '- This prompt does NOT include raw file diffs, source contents, or secret material.'
$lines += '- This prompt does NOT include any environment variable values or credential paths.'
$lines += '- If you need to inspect specific lines, note them in your review; do not attempt to read or edit files during this review.'
$lines += ''
$lines += '## Required Response Template'
$lines += ''
$lines += 'Respond ONLY with the following structured markdown. Use ATX-style headings exactly as written. The Verdict line must be one of: `approve`, `request_changes`, or `block`.'
$lines += ''
$lines += $fence + 'markdown'
$lines += '# Claude Review'
$lines += ''
$lines += '## Verdict'
$lines += ''
$lines += 'approve | request_changes | block'
$lines += ''
$lines += '## Summary'
$lines += ''
$lines += '<2-5 sentences describing what changed and how the run looks overall.>'
$lines += ''
$lines += '## Blocking Issues'
$lines += ''
$lines += '- <issue 1>'
$lines += '- <issue 2>'
$lines += ''
$lines += '## Non-blocking Issues'
$lines += ''
$lines += '- <issue 1>'
$lines += ''
$lines += '## Test Assessment'
$lines += ''
$lines += '<Were tests detected? Were they run? Did they pass? Are gaps acceptable?>'
$lines += ''
$lines += '## Safety Assessment'
$lines += ''
$lines += '<Allowed-files scope, secret paths, denylist hits, AutoCommit refusal, etc.>'
$lines += ''
$lines += '## Suggested Fix Prompt For Codex'
$lines += ''
$lines += '<Optional. If verdict is request_changes or block, give a concrete prompt the human can later hand to Codex CLI. Do not execute it.>'
$lines += ''
$lines += '## Approval Readiness'
$lines += ''
$lines += '<ready / not ready, with one-line rationale.>'
$lines += ''
$lines += '## Suggested Commit Message'
$lines += ''
$lines += '<Conventional-commits style. Empty if verdict != approve.>'
$lines += $fence

$outPath = Join-Path $RunFolder 'claude-review-prompt.md'
($lines -join [Environment]::NewLine) | Out-File -FilePath $outPath -Encoding utf8

Write-Host "[review-prompt] Wrote $outPath"
